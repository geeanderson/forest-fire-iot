# Sensor node firmware

Heltec WiFi LoRa 32 V4 + FS400-SHT31, LoRa at 915.2 MHz (Brazil). Every 30 min the node wakes up, reads
temperature, humidity and battery voltage, sends one LoRa packet to the gateway, shows the reading on the
OLED for 15 s and goes back to deep sleep.

## Configure

All settings live in `firmware/site_config.h`, the single file shared with the gateway (create it from
`firmware/site_config.h.example`; see step 2 of the main README). The node uses:

| Setting | Default | Notes |
|---|---|---|
| `DEVICE_ID` | `"node-01"` | Unique per node: `node-01`, `node-02`, … Change it before flashing each node |
| `BATTERY_ADC_SCALE` | `0.004060f` | Calibrate per board (below). Change it before flashing each node |
| `SLEEP_INTERVAL_SECONDS` | `1800` | Interval between readings |
| `LORA_FREQUENCY_MHZ` | `915.2` | Shared with the gateway |
| `LORA_TX_POWER_DBM` | `14` | Check the local limit before raising it |

The other radio settings (125 kHz bandwidth, SF12, coding rate 4/6, sync word `0xAB`, preamble 16, CRC on)
are in the same file and are also used by the gateway, so both sides always match. `src/config.h` only holds
the Heltec V4 pins and board details.

## Build and flash

```bash
cd firmware/node
pio run -t upload --upload-port /dev/cu.usbmodemXXXX
pio device monitor
```

The USB port only exists while the board is awake (15 s after each wake-up). If the upload cannot find the
port, hold **BOOT**, press **RST**, release **BOOT** and upload again.

## Calibrate the battery reading

The divider resistors vary between boards, so calibrate each node once:

1. Measure the battery voltage with a multimeter (`V_meter`).
2. Read the voltage reported by the node on the serial monitor or the dashboard (`V_reported`).
3. Set `BATTERY_ADC_SCALE = V_meter / V_reported * BATTERY_ADC_SCALE` in `firmware/site_config.h` and
   flash again.

## Payload

```json
{"device_id": "node-01", "timestamp": "1970-01-01T00:00:00Z", "temperature": 24.6, "humidity": 61.3,
 "air_quality": -1, "battery_voltage": 3.91, "rssi": 0}
```

The node has no clock, so the gateway sets `timestamp` and `rssi` on arrival. `-1` means "no value"
(failed reading, or the MQ-135 placeholder). The node's position is not sent: it is configured in the cloud
(see the main README).
