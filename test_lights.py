import RPi.GPIO as GPIO
import time

PIN = 17

GPIO.setmode(GPIO.BCM)
GPIO.setup(PIN, GPIO.OUT)

try:
    while True:
        print("ON")
        GPIO.output(PIN, GPIO.HIGH)
        time.sleep(360)

        print("OFF")
        GPIO.output(PIN, GPIO.LOW)
        time.sleep(10)

except KeyboardInterrupt:
    GPIO.output(PIN, GPIO.LOW)
    GPIO.cleanup()
    print("Stopped")