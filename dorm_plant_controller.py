import RPi.GPIO as GPIO
import smbus2
import time
import bme680

# --- Pin assignments ---
LIGHTS_PIN     = 17
PUMP_PIN       = 22
FAN_ELEC_PIN   = 12   # Electronics box fan - runs continuously
FAN_VENT_PIN   = 13   # Enclosure exhaust fan - temperature controlled

# --- I2C / ADC ---
PCF8591_ADDR = 0x48
SOIL_CHANNEL = 0x40  # Channel 0

# --- Soil moisture thresholds (INVERTED: higher = drier) ---
DRY_THRESHOLD = 130   # Above this → trigger a water pulse
WET_THRESHOLD = 95    # Below this → soil is sufficiently moist, don't water

# --- Temperature threshold for enclosure fan ---
VENT_FAN_TEMP_F = 83.0  # Turn on enclosure vent fan at or above this temp (F)

# --- Pump timing ---
PULSE_DURATION = 10.0   # seconds per pulse (~28ml at 2.86ml/s)
PULSE_COOLDOWN = 120    # seconds between pulses (water absorption time)

# --- Light cycle ---
LIGHT_ON_HOURS  = 14
LIGHT_OFF_HOURS = 10
LIGHT_ON_SECS   = LIGHT_ON_HOURS  * 3600
LIGHT_OFF_SECS  = LIGHT_OFF_HOURS * 3600

# --- Check intervals ---
SOIL_CHECK_INTERVAL = 300   # every 5 minutes
BME_CHECK_INTERVAL  = 30    # every 30 seconds


def setup_bme680():
    try:
        sensor = bme680.BME680(bme680.I2C_ADDR_SECONDARY)  # 0x77
        sensor.set_humidity_oversample(bme680.OS_2X)
        sensor.set_pressure_oversample(bme680.OS_4X)
        sensor.set_temperature_oversample(bme680.OS_8X)
        sensor.set_filter(bme680.FILTER_SIZE_3)
        sensor.set_gas_status(bme680.DISABLE_GAS_MEAS)
        print("BME680 initialized")
        return sensor
    except Exception as e:
        print(f"BME680 init error: {e}")
        return None


def read_bme680(sensor):
    try:
        if sensor.get_sensor_data():
            temp_c = sensor.data.temperature
            temp_f = (temp_c * 9 / 5) + 32
            humidity = sensor.data.humidity
            return temp_f, humidity
    except Exception as e:
        print(f"  BME680 read error: {e}")
    return None, None


def read_soil(bus):
    try:
        bus.write_byte(PCF8591_ADDR, SOIL_CHANNEL)
        bus.read_byte(PCF8591_ADDR)  # discard stale byte
        return bus.read_byte(PCF8591_ADDR)
    except Exception as e:
        print(f"  Soil read error: {e}")
        return None


def pulse_pump():
    print(f"  Pump ON ({PULSE_DURATION}s pulse)")
    GPIO.output(PUMP_PIN, GPIO.HIGH)
    time.sleep(PULSE_DURATION)
    GPIO.output(PUMP_PIN, GPIO.LOW)
    print("  Pump OFF")


def main():
    # --- GPIO setup ---
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(LIGHTS_PIN,   GPIO.OUT)
    GPIO.setup(PUMP_PIN,     GPIO.OUT)
    GPIO.setup(FAN_ELEC_PIN, GPIO.OUT)
    GPIO.setup(FAN_VENT_PIN, GPIO.OUT)

    GPIO.output(LIGHTS_PIN,   GPIO.LOW)
    GPIO.output(PUMP_PIN,     GPIO.LOW)
    GPIO.output(FAN_ELEC_PIN, GPIO.LOW)
    GPIO.output(FAN_VENT_PIN, GPIO.LOW)

    # Electronics fan runs continuously
    GPIO.output(FAN_ELEC_PIN, GPIO.HIGH)
    print("Electronics fan ON (GPIO13, continuous)")

    bus    = smbus2.SMBus(1)
    sensor = setup_bme680()

    last_soil_check = 0
    last_bme_check  = 0
    last_pump_time  = 0
    vent_fan_on     = False

    light_cycle_start = time.time()
    lights_on = True
    GPIO.output(LIGHTS_PIN, GPIO.HIGH)
    print(f"Lights ON - {LIGHT_ON_HOURS} hour light period")

    try:
        while True:
            now = time.time()

            # --- Light cycle ---
            cycle_elapsed = now - light_cycle_start
            if lights_on:
                if cycle_elapsed >= LIGHT_ON_SECS:
                    GPIO.output(LIGHTS_PIN, GPIO.LOW)
                    lights_on = False
                    light_cycle_start = now
                    print(f"Lights OFF - dark period {LIGHT_OFF_HOURS} hours")
            else:
                if cycle_elapsed >= LIGHT_OFF_SECS:
                    GPIO.output(LIGHTS_PIN, GPIO.HIGH)
                    lights_on = True
                    light_cycle_start = now
                    print(f"Lights ON - {LIGHT_ON_HOURS} hour light period")

            # --- BME680 temperature / humidity check ---
            if (now - last_bme_check) >= BME_CHECK_INTERVAL:
                last_bme_check = now
                if sensor:
                    temp_f, humidity = read_bme680(sensor)
                    if temp_f is not None:
                        print(f"Temp: {temp_f:.1f}F  Humidity: {humidity:.1f}%RH")

                        # Vent fan control
                        if temp_f >= VENT_FAN_TEMP_F and not vent_fan_on:
                            GPIO.output(FAN_VENT_PIN, GPIO.HIGH)
                            vent_fan_on = True
                            print(f"  Vent fan ON ({temp_f:.1f}F >= {VENT_FAN_TEMP_F}F)")
                        elif temp_f < VENT_FAN_TEMP_F and vent_fan_on:
                            GPIO.output(FAN_VENT_PIN, GPIO.LOW)
                            vent_fan_on = False
                            print(f"  Vent fan OFF ({temp_f:.1f}F < {VENT_FAN_TEMP_F}F)")

            # --- Soil moisture check ---
            if (now - last_soil_check) >= SOIL_CHECK_INTERVAL:
                last_soil_check = now
                soil = read_soil(bus)

                if soil is not None:
                    print(f"Soil reading: {soil}  (dry>{DRY_THRESHOLD}, wet<{WET_THRESHOLD})")

                    if soil > DRY_THRESHOLD:
                        if (now - last_pump_time) >= PULSE_COOLDOWN:
                            print(f"  Soil is dry ({soil}), watering...")
                            pulse_pump()
                            last_pump_time = now
                        else:
                            remaining = int(PULSE_COOLDOWN - (now - last_pump_time))
                            print(f"  Dry but in cooldown, {remaining}s remaining")
                    elif soil < WET_THRESHOLD:
                        print(f"  Soil is sufficiently moist ({soil}), no watering needed")
                    else:
                        print(f"  Soil is in acceptable range ({soil})")

            time.sleep(10)

    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        GPIO.output(LIGHTS_PIN,   GPIO.LOW)
        GPIO.output(PUMP_PIN,     GPIO.LOW)
        GPIO.output(FAN_ELEC_PIN, GPIO.LOW)
        GPIO.output(FAN_VENT_PIN, GPIO.LOW)
        GPIO.cleanup()
        bus.close()
        print("GPIO cleaned up")


if __name__ == "__main__":
    main()