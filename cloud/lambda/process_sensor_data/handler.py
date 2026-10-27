import json
import os
import urllib.parse
import urllib.request
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal
from datetime import datetime, timedelta, timezone

DYNAMODB_TABLE             = os.environ.get("DYNAMODB_TABLE", "forest-fire-readings")
S3_BUCKET_RAW              = os.environ.get("S3_BUCKET_RAW", "")
LAMBDA_INFERENCE_FUNCTION  = os.environ.get("LAMBDA_INFERENCE_FUNCTION", "")
NTFY_TOPIC                 = os.environ.get("NTFY_TOPIC", "")

dynamodb          = boto3.resource("dynamodb")
s3                = boto3.client("s3")
lambda_client     = boto3.client("lambda")

REQUIRED_FIELDS = {"device_id", "timestamp", "temperature", "humidity"}

# Daily model on a rolling 24 h window
WINDOW_HOURS = 24
MIN_VALID_READINGS = 36   # of 48 expected (30 min cadence); fewer → "insufficient_data"
SENTINEL = -1

# ---------------------------------------------------------------------------
# days_without_rain — real weather lookup (Open-Meteo, free, no API key)
#
# The nodes carry no rain sensor, so this model input (31.5% of the v1
# model's feature importance) comes from Open-Meteo for the node's position.
# ---------------------------------------------------------------------------
def _load_locations(raw: str) -> dict:
    """Node positions from the DEVICE_LOCATIONS env var (Terraform var.device_locations):
    '{"node-01": [lat, lon], ..., "default": [lat, lon]}'; "default" covers nodes not listed."""
    try:
        return {node: (float(pos[0]), float(pos[1])) for node, pos in json.loads(raw or "{}").items()}
    except (ValueError, TypeError, IndexError, AttributeError) as exc:
        print(f"WARNING: invalid DEVICE_LOCATIONS ({exc}); days_without_rain lookup disabled")
        return {}


DEVICE_LOCATIONS = _load_locations(os.environ.get("DEVICE_LOCATIONS", ""))

WEATHER_API_URL   = "https://api.open-meteo.com/v1/forecast"
RAIN_THRESHOLD_MM = 1.0   # matches training feature definition (dias_sem_chuva)
LOOKBACK_DAYS     = 92    # Open-Meteo forecast API's max past_days - avoids undercounting
                          # long dry spells (can go 30+ days)


def _fetch_days_without_rain(device_id: str) -> int:
    if device_id in DEVICE_LOCATIONS:
        lat, lon = DEVICE_LOCATIONS[device_id]
    elif "default" in DEVICE_LOCATIONS:
        lat, lon = DEVICE_LOCATIONS["default"]
        print(f"WARNING: no position for {device_id} in DEVICE_LOCATIONS, using the default one")
    else:
        raise ValueError(f"no position for {device_id} in DEVICE_LOCATIONS")
    params = {
        "latitude":      lat,
        "longitude":     lon,
        "daily":         "precipitation_sum",
        "past_days":     LOOKBACK_DAYS,
        "forecast_days": 0,
        "timezone":      "America/Sao_Paulo",
    }
    url = f"{WEATHER_API_URL}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=5) as resp:
        data = json.loads(resp.read())

    dates  = data["daily"]["time"]
    precip = data["daily"]["precipitation_sum"]
    today  = _local_date(datetime.now(timezone.utc)).isoformat()

    # Count consecutive dry days ending on the most recent COMPLETE day -
    # skip "today" since its precipitation_sum is still partial/in-progress.
    count = 0
    for date, mm in reversed(list(zip(dates, precip))):
        if date >= today:
            continue
        if mm is None or mm > RAIN_THRESHOLD_MM:
            break
        count += 1
    return count


def _local_date(dt: datetime):
    """Brasília local date (UTC-3, no daylight saving since 2019)."""
    return (dt - timedelta(hours=3)).date()


def _valid(reading: dict) -> bool:
    t, h = reading.get("temperature"), reading.get("humidity")
    if t is None or h is None:
        return False
    t, h = float(t), float(h)
    return t != SENTINEL and h != SENTINEL and 0 <= h <= 100


def _window(device_id: str, ts: str) -> list:
    """Readings already stored for this node in the WINDOW_HOURS before ts (the current packet excluded)."""
    end = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    start = (end - timedelta(hours=WINDOW_HOURS)).strftime("%Y-%m-%dT%H:%M:%SZ")
    kwargs = {
        "KeyConditionExpression": Key("device_id").eq(device_id) & Key("timestamp").between(start, ts),
        "ProjectionExpression": "#ts, temperature, humidity, days_without_rain, days_without_rain_source",
        "ExpressionAttributeNames": {"#ts": "timestamp"},
    }
    items, table = [], dynamodb.Table(DYNAMODB_TABLE)
    while True:
        page = table.query(**kwargs)
        items += page["Items"]
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    return [i for i in items if i["timestamp"] != ts and i["timestamp"] > start]


def _days_without_rain(event: dict, history: list, local_day) -> tuple:
    """(value, source); falls back to the node's last Open-Meteo value of the same local day, never to 0."""
    if "days_without_rain" in event:
        return int(event["days_without_rain"]), "event"
    try:
        value = _fetch_days_without_rain(event["device_id"])
        print(f"[weather] days_without_rain={value} device_id={event['device_id']}")
        return value, "open-meteo"
    except Exception as exc:
        print(f"WARNING: weather API call failed ({exc})")
    for item in sorted(history, key=lambda i: i["timestamp"], reverse=True):
        item_day = _local_date(datetime.fromisoformat(item["timestamp"].replace("Z", "+00:00")))
        if item.get("days_without_rain_source") == "open-meteo" and item_day == local_day:
            return int(item["days_without_rain"]), "previous"
    return None, None


def _invoke_fire_risk(features: dict) -> dict:
    response = lambda_client.invoke(
        FunctionName=LAMBDA_INFERENCE_FUNCTION,
        InvocationType="RequestResponse",
        Payload=json.dumps(features).encode(),
    )
    result = json.loads(response["Payload"].read())
    if "fire_probability" not in result:
        raise RuntimeError(f"unexpected inference response: {result}")
    out = {"fire_risk":        result["fire_risk"][0],
           "fire_probability": result["fire_probability"][0],
           "model_version":    result.get("model_version", "v1-br")}
    if "fire_risk_label" in result:
        out["fire_risk_label"] = result["fire_risk_label"][0]
    return out


def _notify_ntfy(event: dict, fire_risk_data: dict) -> None:
    """Optional push notification (ntfy.sh, NTFY_TOPIC) for every reading stored in DynamoDB.
    Runs once per packet (~30 min per node), so it needs no throttling."""
    if not NTFY_TOPIC:
        return
    device_id = event.get("device_id", "node")
    lines = [
        f"Temp: {event.get('temperature', '?')}C  Humidity: {event.get('humidity', '?')}%",
        f"Battery: {event.get('battery_voltage', '?')}V",
        f"RSSI: {event.get('rssi', '?')}dBm",
    ]
    if "fire_risk" in fire_risk_data:
        label = fire_risk_data.get("fire_risk_label", "")
        lines.append(f"Risk (24 h): {fire_risk_data['fire_risk']}/5 {label} "
                     f"({float(fire_risk_data['fire_probability']) * 100:.1f}%)")
    elif fire_risk_data.get("risk_status") == "insufficient_data":
        lines.append(f"Risk: insufficient data ({fire_risk_data.get('n_readings_24h', 0)}/48 readings in 24 h)")
    try:
        req = urllib.request.Request(
            f"https://ntfy.sh/{NTFY_TOPIC}",
            data="\n".join(lines).encode("utf-8"),
            headers={
                # Header values must be plain ASCII (http.client requires Latin-1): a non-ASCII
                # character raises UnicodeEncodeError and IoT Core retries the whole message.
                # The UTF-8 body may hold any character.
                "Title": f"{device_id} - DynamoDB",
                "Priority": "default",
                "Tags": "cloud",
            },
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception as exc:  # noqa: BLE001 - never let a notify failure break the handler
        print(f"WARNING: ntfy notify failed ({exc!r})")


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    missing = REQUIRED_FIELDS - set(event.keys())
    if missing:
        raise ValueError(f"Missing required fields: {missing}")

    ingested_at = datetime.now(timezone.utc).isoformat()
    packet_dt = datetime.fromisoformat(event["timestamp"].replace("Z", "+00:00"))
    local_day = _local_date(packet_dt)

    history = _window(event["device_id"], event["timestamp"])
    readings = [r for r in history + [event] if _valid(r)]
    days_without_rain, dwr_source = _days_without_rain(event, history, local_day)
    event = {**event, "days_without_rain": days_without_rain, "days_without_rain_source": dwr_source}

    fire_risk_data = {"n_readings_24h": len(readings)}
    if len(readings) >= MIN_VALID_READINGS:
        fire_risk_data["temp_mean_24h"] = round(sum(float(r["temperature"]) for r in readings) / len(readings), 2)
        fire_risk_data["humidity_mean_24h"] = round(sum(float(r["humidity"]) for r in readings) / len(readings), 2)

    if len(readings) < MIN_VALID_READINGS:
        fire_risk_data["risk_status"] = "insufficient_data"
    elif days_without_rain is None or not LAMBDA_INFERENCE_FUNCTION:
        fire_risk_data["risk_status"] = "unavailable"
    else:
        try:
            fire_risk_data.update(_invoke_fire_risk({
                "device_id":      event["device_id"],
                "temp_mean":      fire_risk_data["temp_mean_24h"],
                "humidity_mean":  fire_risk_data["humidity_mean_24h"],
                "dias_sem_chuva": days_without_rain,
                "month":          local_day.month,
            }))
            fire_risk_data["risk_status"] = "ok"
            # Parsed by the high-risk CloudWatch alarm (modules/lambda/alarms.tf): keep the format.
            print(f"[lambda] fire_risk={fire_risk_data['fire_risk']} "
                  f"p={fire_risk_data['fire_probability']:.4f} n={len(readings)} device_id={event['device_id']}")
        except Exception as exc:
            fire_risk_data["risk_status"] = "unavailable"
            print(f"WARNING: inference call failed ({exc}); storing without fire_risk")
    print(f"[risk] status={fire_risk_data['risk_status']} n_readings_24h={len(readings)}")

    item = json.loads(json.dumps({**event, **fire_risk_data}), parse_float=Decimal)
    item["ingested_at"] = ingested_at
    dynamodb.Table(DYNAMODB_TABLE).put_item(Item=item)
    print(f"DynamoDB write OK — device_id={event['device_id']} timestamp={event['timestamp']}")

    _notify_ntfy(event, fire_risk_data)

    if S3_BUCKET_RAW:
        ts = event["timestamp"]
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            date_path = dt.strftime("%Y/%m/%d")
        except ValueError:
            date_path = "unknown"

        s3_key = f"raw/{event['device_id']}/{date_path}/{ts}.json"
        s3.put_object(
            Bucket=S3_BUCKET_RAW,
            Key=s3_key,
            Body=json.dumps({**event, **fire_risk_data}),
            ContentType="application/json",
        )
        print(f"S3 write OK — s3://{S3_BUCKET_RAW}/{s3_key}")

    return {"statusCode": 200, "body": "ok", **fire_risk_data}
