#!/usr/bin/env python3
"""Exercise the real exported WASM game with Chromium touch/mouse/keyboard input.

Requires Python Playwright and Pillow, an installed Chromium, and serve_web.py.
Usage: python3 tests/browser_smoke.py [http://127.0.0.1:8060]
"""
import io
import os
import shutil
from pathlib import Path
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8060"
OUT = Path(__file__).resolve().parents[1] / "artifacts"
OUT.mkdir(exist_ok=True)


def ship_center(png):
    image = Image.open(io.BytesIO(png)).convert("RGB")
    pixels = image.load()
    # Restrict to the ship's travel region, excluding HUD and early coin waves.
    points = [(x, y) for y in range(950, 1640, 3) for x in range(70, 1010, 3)
              if pixels[x, y][0] > 190 and pixels[x, y][1] > 140 and pixels[x, y][2] < 145]
    assert len(points) > 50, "The yellow ship must be visible in the actual rendered game"
    return sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points)


def main():
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=os.environ.get("CHROMIUM_PATH") or shutil.which("chromium") or shutil.which("google-chrome") or playwright.chromium.executable_path,
            args=["--no-sandbox", "--disable-dev-shm-usage", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
        )
        errors = []
        context = browser.new_context(viewport={"width": 540, "height": 960}, device_scale_factor=2, has_touch=True, is_mobile=True)
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
        page.goto(URL)
        page.wait_for_selector("#loading", state="detached", timeout=90000)
        page.wait_for_timeout(600)
        canvas = page.locator("canvas")
        render_size = canvas.evaluate("node => ({width: node.width, height: node.height})")
        assert render_size["width"] >= 1080 and render_size["height"] >= 1920, render_size
        ready = canvas.screenshot(path=str(OUT / "01-start.png"))
        assert Image.open(io.BytesIO(ready)).size == (1080, 1920)
        assert Image.open(io.BytesIO(ready)).getpixel((300, 1410))[1] > 160, "Start button must be visible"
        print("PASS  web build loads and renders a 1080 × 1920 start screen")

        page.touchscreen.tap(270, 711)
        page.wait_for_timeout(400)
        before = canvas.screenshot(path=str(OUT / "02-liftoff.png"))
        x_before, y_before = ship_center(before)
        cdp = context.new_cdp_session(page)
        cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": 270, "y": 690}]})
        for i in range(1, 11):
            cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [{"x": 270 + i * 12, "y": 690 - i * 12}]})
            page.wait_for_timeout(18)
        page.wait_for_timeout(350)
        after = canvas.screenshot(path=str(OUT / "02-flight.png"))
        cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        x_after, y_after = ship_center(after)
        assert x_after > x_before + 150 and y_after < y_before - 120, (x_before, y_before, x_after, y_after)
        print("PASS  actual browser touch drag moves the ship horizontally and vertically")

        page.touchscreen.tap(484, 58)
        page.wait_for_timeout(250)
        paused = canvas.screenshot(path=str(OUT / "03-pause.png"))
        page.wait_for_timeout(400)
        assert paused == canvas.screenshot(), "Pause must freeze the actual rendered game"
        page.touchscreen.tap(270, 658)
        page.wait_for_timeout(350)
        assert paused != canvas.screenshot(), "Resume must leave the pause screen"
        print("PASS  touch pause freezes gameplay and resume returns to flight")
        page.wait_for_timeout(8000)
        canvas.screenshot(path=str(OUT / "04-delivery-approach.png"))

        # Check a tall, non-9:16 phone and a wide desktop without stretching the game.
        page.set_viewport_size({"width": 390, "height": 844})
        box = canvas.bounding_box()
        assert abs(box["width"] / box["height"] - 9 / 16) < 0.002, box
        print("PASS  taller phones retain the 9:16 playfield")
        context.close()

        desktop = browser.new_context(viewport={"width": 1400, "height": 1000})
        page = desktop.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
        page.goto(URL)
        page.wait_for_selector("#loading", state="detached", timeout=90000)
        canvas = page.locator("canvas")
        box = canvas.bounding_box()
        assert abs(box["width"] / box["height"] - 9 / 16) < 0.002, box
        page.keyboard.press("Enter")
        page.keyboard.down("ArrowLeft")
        page.wait_for_timeout(250)
        page.keyboard.up("ArrowLeft")
        page.keyboard.press("p")
        page.wait_for_timeout(200)
        keyboard_pause = canvas.screenshot()
        page.wait_for_timeout(300)
        assert keyboard_pause == canvas.screenshot()
        page.keyboard.press("p")
        page.wait_for_timeout(300)
        assert keyboard_pause != canvas.screenshot()
        print("PASS  desktop keyboard start, steering and pause/resume work")
        assert not errors, "Browser errors:\n" + "\n".join(errors)
        print("PASS  no JavaScript, WebGL or Godot runtime errors")
        browser.close()


if __name__ == "__main__":
    main()
