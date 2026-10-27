import json
import os
import boto3

sns = boto3.client("sns")

TEMP_THRESHOLD = float(os.environ.get("THRESHOLD_TEMPERATURE", "45"))
HUMIDITY_THRESHOLD = float(os.environ.get("THRESHOLD_HUMIDITY", "15"))
AIR_QUALITY_THRESHOLD = float(os.environ.get("THRESHOLD_AIR_QUALITY", "500"))
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    print(f"fire_alert received event: {json.dumps(event)}")

    device_id = event.get("device_id", "unknown")
    timestamp = event.get("timestamp", "")
    temperature = event.get("temperature")
    humidity = event.get("humidity")
    air_quality = event.get("air_quality")
    location = event.get("location", {})

    triggered = []

    if temperature is not None and temperature > TEMP_THRESHOLD:
        triggered.append(
            f"temperature={temperature}°C (threshold={TEMP_THRESHOLD}°C)"
        )
    if humidity is not None and humidity < HUMIDITY_THRESHOLD:
        triggered.append(
            f"humidity={humidity}% (threshold<{HUMIDITY_THRESHOLD}%)"
        )
    if air_quality is not None and air_quality > AIR_QUALITY_THRESHOLD:
        triggered.append(
            f"air_quality={air_quality} ppm (threshold={AIR_QUALITY_THRESHOLD} ppm)"
        )

    if not triggered:
        print("No thresholds exceeded — skipping alert.")
        return {"statusCode": 200}

    message = {
        "alert": "FIRE RISK DETECTED",
        "device_id": device_id,
        "timestamp": timestamp,
        "location": location,
        "triggered_conditions": triggered,
        "thresholds": {
            "temperature_max_celsius": TEMP_THRESHOLD,
            "humidity_min_percent": HUMIDITY_THRESHOLD,
            "air_quality_max_ppm": AIR_QUALITY_THRESHOLD,
        },
        "raw_values": {
            "temperature": temperature,
            "humidity": humidity,
            "air_quality": air_quality,
        },
    }

    subject = f"[FIRE ALERT] Device {device_id} — {len(triggered)} condition(s) exceeded"

    print(f"Publishing alert to SNS: {subject}")

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=json.dumps(message, indent=2, ensure_ascii=False),
    )

    print(f"Alert published successfully for device {device_id}.")
    return {"statusCode": 200}
