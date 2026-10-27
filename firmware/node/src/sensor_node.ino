/*
   Forest Fire IoT - Sensor Node Firmware (Brazil, 915.2 MHz)

   Target hardware: Heltec WiFi LoRa 32 V4 (ESP32-S3 + SX1262 onboard) +
   FS400-SHT31 (temperature/humidity, I2C) + 2x 18650 + solar panel.
   Settings (DEVICE_ID, radio, battery calibration, interval) live in the
   shared firmware/site_config.h; board pins live in config.h.

   The external PA (KCT8103L) is enabled by driving PA_CSD_PIN, PA_CTX_PIN
   and PA_POWER_PIN HIGH before radio.begin() - RadioLib does not do it.

   Deep sleep: setup() runs one wake/measure/transmit/display cycle, then
   calls esp_deep_sleep_start() - the chip resets and re-enters setup() on
   wake, so loop() is never reached.
*/

#include "config.h"
#include <Adafruit_SHT31.h>
#include <RadioLib.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <esp_sleep.h>

TwoWire sensorWire = TwoWire(1); // second I2C peripheral, separate from the OLED's bus
Adafruit_SHT31 sht31 = Adafruit_SHT31(&sensorWire);

SX1262 radio = new Module(LORA_PIN_NSS, LORA_PIN_DIO1, LORA_PIN_RST, LORA_PIN_BUSY);
Adafruit_SSD1306 oled(OLED_WIDTH, OLED_HEIGHT, &Wire, OLED_RST_PIN);

RTC_DATA_ATTR static uint32_t packetCount = 0; // survives deep sleep - resets only on power-cycle/reflash

float readBatteryVoltage()
{
    // Official Heltec V4 datasheet (WiFi_LoRa_32_V4.3.1_Datasheet.pdf, rev
    // 1.1.0): "ADC1_CH0 is used to read the lithium battery voltage, the
    // ADC_CTRL(37) pin needs to be pulled HIGH."
    pinMode(ADC_CTRL_PIN, OUTPUT);
    digitalWrite(ADC_CTRL_PIN, HIGH); // enable the onboard divider (per official V4 datasheet)
    delay(5);
    int raw = analogRead(VBAT_PIN);
    digitalWrite(ADC_CTRL_PIN, LOW); // disable it again to save power
    return raw * BATTERY_ADC_SCALE;
}

void enablePA()
{
    // Must run before radio.begin() - see config.h for the full
    // investigation trail. RadioLib has no concept of these pins; they
    // are separate GPIOs wired directly to the external PA (KCT8103L),
    // not to the SX1262.
    pinMode(PA_POWER_PIN, OUTPUT);
    digitalWrite(PA_POWER_PIN, HIGH);

    pinMode(PA_CSD_PIN, OUTPUT);
    digitalWrite(PA_CSD_PIN, HIGH);

    pinMode(PA_CTX_PIN, OUTPUT);
    digitalWrite(PA_CTX_PIN, HIGH);
}

String buildPayload(float temperature, float humidity, float batteryVoltage)
{
    JsonDocument doc;
    doc["device_id"] = DEVICE_ID;
    doc["timestamp"] = "1970-01-01T00:00:00Z"; // no RTC/NTP on this board - gateway timestamps on arrival
    doc["temperature"] = isnan(temperature) ? -1 : temperature;
    doc["humidity"] = isnan(humidity) ? -1 : humidity;
    doc["air_quality"] = -1; // MQ-135 not in this BOM - placeholder keeps the schema stable
    doc["battery_voltage"] = batteryVoltage;
    doc["rssi"] = 0; // filled in by the gateway on receipt, not measurable by the transmitter itself
    // No "location" field: lat/lon moved to the software layer (Streamlit's
    // hardcoded NODES list already maps device_id -> lat/lon independently
    // of this payload) to save airtime on a value that never changes.

    String out;
    serializeJson(doc, out);
    return out;
}

void showOnOLED(float temperature, float humidity, float batteryVoltage, bool txOk)
{
    oled.clearDisplay();
    oled.setTextColor(SSD1306_WHITE);

    oled.setTextSize(1);
    oled.setCursor(0, 0);
    oled.println(DEVICE_ID);

    oled.setTextSize(2);
    oled.setCursor(0, 12);
    oled.printf("%.1fC\n", temperature);
    oled.setCursor(0, 32);
    oled.printf("%.0f%%RH\n", humidity);

    oled.setTextSize(1);
    oled.setCursor(0, 52);
    oled.printf("Bat:%.2fV TX:%s #%lu", batteryVoltage, txOk ? "OK" : "FAIL", (unsigned long)packetCount);
    oled.display();
}

void goToDeepSleep()
{
    Serial.printf("[%s] sleeping for %ds\n", DEVICE_ID, SLEEP_INTERVAL_SECONDS);
    Serial.flush();

    esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_INTERVAL_SECONDS * 1000000ULL);
    esp_deep_sleep_start();
}

void setup()
{
    Serial.begin(115200);
    delay(200);

    packetCount++;
    Serial.printf("[%s] wake #%lu, deep sleep every %ds\n", DEVICE_ID, (unsigned long)packetCount, SLEEP_INTERVAL_SECONDS);

    pinMode(VEXT_CTRL_PIN, OUTPUT);
    digitalWrite(VEXT_CTRL_PIN, VEXT_ON); // power the OLED for this wake cycle
    delay(50);

    Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
    if (!oled.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDRESS)) {
        Serial.println("OLED init failed");
    }

    sensorWire.begin(SHT31_SDA_PIN, SHT31_SCL_PIN);
    if (!sht31.begin(SHT31_I2C_ADDRESS)) {
        Serial.println("SHT31 init failed - check wiring/address");
    }

    enablePA();
    Serial.printf("[%s] PA control pins driven HIGH (CSD=GPIO%d, CTX=GPIO%d, PA_POWER=GPIO%d)\n",
                  DEVICE_ID, PA_CSD_PIN, PA_CTX_PIN, PA_POWER_PIN);

    // The radio's NSS/RST/BUSY/DIO1 aren't on the ESP32-S3's default SPI
    // pins for this board, so SPI must be started with the LoRa-specific
    // pins from config.h before RadioLib touches the module.
    SPI.begin(LORA_PIN_SCK, LORA_PIN_MISO, LORA_PIN_MOSI, LORA_PIN_NSS);

    int state = radio.begin(LORA_FREQUENCY_MHZ, LORA_BANDWIDTH_KHZ, LORA_SPREADING_FACTOR, LORA_CODING_RATE, LORA_SYNC_WORD, LORA_TX_POWER_DBM, LORA_PREAMBLE_LENGTH);
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("Radio init failed, code %d\n", state);
    }
    radio.setOutputPower(LORA_TX_POWER_DBM);
    radio.setCRC(LORA_CRC_ENABLED); // must match the gateway's RX CRC setting exactly

    float temperature = sht31.readTemperature();
    float humidity = sht31.readHumidity();
    float batteryVoltage = readBatteryVoltage();

    if (isnan(temperature) || isnan(humidity)) {
        Serial.println("Failed to read SHT31 - check wiring/power/address");
    }

    String payload = buildPayload(temperature, humidity, batteryVoltage);
    Serial.print("Payload: ");
    Serial.println(payload);

    int txState = RADIOLIB_ERR_UNKNOWN;
    bool txOk = false;
    for (int attempt = 1; attempt <= MAX_TX_ATTEMPTS && !txOk; attempt++) {
        txState = radio.transmit(payload);
        txOk = (txState == RADIOLIB_ERR_NONE);
        if (txOk) {
            Serial.printf("Transmission successful (attempt %d/%d)\n", attempt, MAX_TX_ATTEMPTS);
        } else {
            Serial.printf("Transmission failed (attempt %d/%d), code %d\n", attempt, MAX_TX_ATTEMPTS, txState);
            if (attempt < MAX_TX_ATTEMPTS) {
                delay(TX_RETRY_DELAY_MS);
            }
        }
    }

    showOnOLED(temperature, humidity, batteryVoltage, txOk);
    delay(AWAKE_DISPLAY_HOLD_MS); // keep the reading visible + USB enumerated long enough for a visual check / upload window before the display powers off

    oled.ssd1306_command(SSD1306_DISPLAYOFF);
    digitalWrite(VEXT_CTRL_PIN, VEXT_OFF); // cut OLED power while asleep

    goToDeepSleep();
}

void loop()
{
    // never reached: setup() always ends in deep sleep, which resets the chip
}
