# Bill of materials and assembly

All radio parts must be the **915 MHz** versions (Brazil, ANATEL 902–907.5 / 915–928 MHz).

## Sensor node (one per site)

| Qty | Part | Notes |
|---|---|---|
| 1 | Heltec WiFi LoRa 32 V4 (ESP32-S3 + SX1262) | 915 MHz version. [Product page](https://heltec.org/project/wifi-lora-32-v4/) |
| 1 | FS400-SHT31 temperature/humidity probe | I2C, address `0x44` |
| 1 | LoRa antenna, 915 MHz, SMA | Plus a U.FL (IPEX 1.0) to SMA bulkhead pigtail |
| 2 | Li-ion 18650 cell, 3.7 V, 2600 mAh | Wired **in parallel** (1S2P): the board accepts 3.3–4.2 V only |
| 1 | 2x 18650 holder (parallel) with SH1.25-2P plug | To the board's battery connector |
| 1 | Small solar panel | Pilot used a 3.3 W panel (~7.2 V open circuit) |
| 1 | Step-down (buck) converter, 5 V output | Brings the panel voltage into the 4.7–6 V range of the solar input |
| 1 | SH1.25-2P plug | Buck output to the board's solar connector |
| 1 | IP67 junction box | With cable glands for the probe and the panel cable |

## Gateway (one per network)

| Qty | Part | Notes |
|---|---|---|
| 1 | LilyGO T-Beam Supreme, SX1262 | 915 MHz version. [Product page](https://www.lilygo.cc/products/t-beamsupreme-m) |
| 1 | LoRa antenna, 915 MHz, SMA | |
| 1 | 5 V USB power supply | The gateway runs continuously and needs Wi-Fi with internet |

## Tools

USB-C cable, multimeter (battery calibration and solar checks), soldering iron for the buck converter.

## Node wiring

| From | To |
|---|---|
| SHT31 VCC | 3V3 |
| SHT31 GND | GND |
| SHT31 SDA | GPIO4 |
| SHT31 SCL | GPIO3 |
| Solar panel + / − | Buck converter IN + / − |
| Buck converter OUT (5 V) + / − | SH1.25-2P solar input + / − |
| 2x 18650 in parallel + / − | SH1.25-2P battery input + / − |

- Do not use GPIO2 for the sensor: it enables the radio's power amplifier.
- Set the buck output to 5 V with a multimeter **before** connecting it to the board. The datasheet allows
  4.7–6 V on the solar input; the open-circuit voltage of a "5 V" panel can be well above that.
- Check the polarity of every SH1.25 plug: cheap cables often come with the colours swapped.
- Do not power the board from USB and from the 5 V pin at the same time (Heltec datasheet).

## Assembly

1. Mount the board, the battery holder and the buck converter inside the IP67 box.
2. Bring the antenna through the lid with the SMA bulkhead, vertical, with nothing metallic around it.
   Never transmit without an antenna connected.
3. Run the SHT31 probe out through a cable gland and fix it **under** the box, in the shade, so it never
   gets direct sun.
4. Run the panel cable through the other gland and face the panel north (southern hemisphere), tilted
   roughly at the site's latitude.
5. Flash and calibrate the node (see [firmware/node/README.md](../firmware/node/README.md)) before closing the box.
6. During the first days, check on the dashboard that the battery voltage recovers during daylight.

## Datasheets

Use the manufacturers' current datasheets: Heltec (WiFi LoRa 32 V4, solar and battery input limits in the
power supply section), LilyGO (T-Beam Supreme), Sensirion (SHT3x-DIS) and Semtech (SX1262).
