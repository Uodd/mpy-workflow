"""Example asyncio main loop for ESP32 MicroPython.

Runs a few independent tasks concurrently. Press Ctrl-C in the REPL
(make repl) to stop it and get the >>> prompt.
"""

import asyncio
import time
from machine import Pin

LED_PIN = 2  # on-board LED on most ESP32 DevKit boards


async def blink(led, period_ms=500):
    """Toggle the LED forever."""
    while True:
        led.value(not led.value())
        await asyncio.sleep_ms(period_ms)


async def heartbeat(interval_s=5):
    """Print a status line periodically."""
    start = time.ticks_ms()
    while True:
        uptime = time.ticks_diff(time.ticks_ms(), start) // 1000
        print("heartbeat: uptime {}s".format(uptime))
        await asyncio.sleep(interval_s)


async def worker(name, delay_s):
    """Placeholder for your own work (read sensors, network, etc.)."""
    count = 0
    while True:
        count += 1
        print("{}: tick {}".format(name, count))
        await asyncio.sleep(delay_s)


async def main():
    led = Pin(LED_PIN, Pin.OUT)
    tasks = [
        asyncio.create_task(blink(led)),
        asyncio.create_task(heartbeat()),
        asyncio.create_task(worker("worker", 2)),
    ]
    try:
        await asyncio.gather(*tasks)
    finally:
        led.off()


try:
    asyncio.run(main())
except KeyboardInterrupt:
    print("Stopped by user (Ctrl-C)")
finally:
    # Reset asyncio state so it can be run again cleanly from the REPL
    asyncio.new_event_loop()
