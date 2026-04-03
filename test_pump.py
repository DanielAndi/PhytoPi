import RPi.GPIO as GPIO
import time

PIN = 22

GPIO.setmode(GPIO.BCM)
GPIO.setup(PIN, GPIO.OUT)
GPIO.output(PIN, GPIO.LOW)

try:
    while True:
        print("Pump ON")
        GPIO.output(PIN, GPIO.HIGH)
        time.sleep(35)

        GPIO.output(PIN, GPIO.LOW)
        print("Pump OFF - waiting 2 minutes")
        time.sleep(120)

except KeyboardInterrupt:
    GPIO.output(PIN, GPIO.LOW)
    GPIO.cleanup()
    print("Stopped")