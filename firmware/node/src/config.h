#pragma once
// Forest Fire IoT - Sensor Node config (Brazil, ANATEL)
// Target hardware: Heltec WiFi LoRa 32 V4 (ESP32-S3 + SX1262 onboard) +
// FS400-SHT31 (temperature/humidity) + 2x 18650 + solar panel.
//
// The V4.3 board has an external PA (KCT8103L) with 3 control pins that
// RadioLib does not drive: PA_CSD/PA_CTX/PA_POWER must be set HIGH before
// radio.begin(), otherwise the PA stays in Shutdown/Receive and almost no
// power reaches the antenna (measured on the bench: ~60 dB less RSSI).
// GPIO2 is the PA's CSD pin, so the SHT31 SDA line uses GPIO4.
//
// Pins follow the official Heltec V4 pinout; check them against your
// board's silkscreen.
//
// Settings you are expected to change (DEVICE_ID, battery calibration,
// sleep interval and every LoRa radio parameter) live in the shared
// firmware/site_config.h, so the nodes and the gateway always use the
// same radio settings. Only board details stay here.

#if __has_include("site_config.h")
#include "site_config.h"
#else
#error "firmware/site_config.h not found: cp firmware/site_config.h.example firmware/site_config.h and fill it in"
#endif

// The preamble must be set explicitly on both sides: RadioLib's
// SX1262::begin() defaults to preamble=8, which silently fails to sync
// with a preamble of 16 (no error, no received-packet interrupt at all,
// especially at SF12's long symbols). CRC on: at long range/weak SNR a
// disabled CRC let a corrupted payload (bad timestamp) through silently.

// Fixed onboard SPI pins (Heltec WiFi LoRa 32 V4 official pinout, same as V3)
#define LORA_PIN_NSS          8
#define LORA_PIN_RST          12
#define LORA_PIN_BUSY         13
#define LORA_PIN_DIO1         14
#define LORA_PIN_SCK          9
#define LORA_PIN_MISO         11
#define LORA_PIN_MOSI         10

// ---- External PA control (KCT8103L, our V4.3 board revision) ----
// See the top-of-file comment. All three must be driven HIGH
// before radio.begin() - without this the PA silently stays in
// Shutdown/Receive mode while radio.transmit() still reports success.
// Pin numbers from meshcore-dev/MeshCore PR #1867 ("add heltec v4.3
// board"), confirmed empirically on the bench.
#define PA_CSD_PIN             2   // P_LORA_KCT8103L_PA_CSD - PA enable (that is why SHT31 SDA uses GPIO4)
#define PA_CTX_PIN              5   // P_LORA_KCT8103L_PA_CTX - transmit-mode select
#define PA_POWER_PIN            7   // P_LORA_PA_POWER - hypothesized Vfem/LDO supply enable

// ---- Onboard OLED (0.96", SSD1306, I2C address 0x3C) ----
// Used as the local debug display.
#define OLED_SDA_PIN          17
#define OLED_SCL_PIN          18
#define OLED_RST_PIN          21
#define OLED_I2C_ADDRESS      0x3C
#define OLED_WIDTH            128
#define OLED_HEIGHT           64

// Vext controls power to the onboard OLED - LOW = power on for this board
// revision (same as V3).
#define VEXT_CTRL_PIN         36
#define VEXT_ON                LOW
#define VEXT_OFF               HIGH

// ---- FS400-SHT31 (temperature + humidity, I2C) ----
// Dedicated bus, separate from the OLED's I2C bus above (ESP32-S3 has two
// I2C peripherals - Wire and Wire1 - so both buses can run independently).
// GPIO1 was NOT used here even though it's physically free-looking: it
// doubles as VBAT_Read (battery divider input) on this board, same as V3.
// SDA on GPIO4: GPIO2 is reserved for PA_CSD_PIN above.
#define SHT31_SDA_PIN         4
#define SHT31_SCL_PIN         3
#define SHT31_I2C_ADDRESS     0x44 // 0x45 if the sensor's ADDR pin is tied to VCC instead of GND/floating

// ---- MQ-135 (air quality / smoke) ----
// NOT in this BOM - future work. Payload field
// kept as a fixed placeholder so the JSON schema stays stable for the
// gateway/cloud pipeline until the sensor is added.

// ---- Battery voltage ----
// Onboard resistive divider gated by ADC_CTRL_PIN: pull it HIGH to enable
// the divider (official Heltec V4 datasheet), then read VBAT_PIN.
#define VBAT_PIN              1
#define ADC_CTRL_PIN          37
// BATTERY_ADC_SCALE (calibrated per board) is in firmware/site_config.h.

// ---- Timing ----
// SLEEP_INTERVAL_SECONDS is in firmware/site_config.h.

// How long the board stays awake (OLED on, native USB CDC enumerated)
// before going back to deep sleep. Widened from 10s to 15s on 2026-09-19
// to give a wider window to catch the USB port for future firmware
// uploads without needing the manual BOOT+RESET bootloader trick - this
// increases average current draw (deep sleep dominates the budget
// either way), acceptable while bench-testing but revisit before final
// field deployment if battery-only runtime (no solar) matters.
#define AWAKE_DISPLAY_HOLD_MS  15000

// ---- LoRa TX retry ----
// No ACK from the gateway, so this can't guarantee delivery - it only
// covers transient radio failures (e.g. momentary noise) by retrying the
// same reading a couple times before giving up for this cycle. Only fires
// on failure, so it doesn't add airtime/duty-cycle cost on the common case
// where the first transmission succeeds.
#define MAX_TX_ATTEMPTS        2
#define TX_RETRY_DELAY_MS      200
