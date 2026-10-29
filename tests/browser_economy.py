#!/usr/bin/env python3
"""Touch-test menus, cosmetic purchases, IndexedDB persistence and visible shots.

All profiles are confined to an isolated Chromium context on the local server.
A marked fixture supplies test coins; the production game has no test endpoint.
"""
import datetime
import io
import os
import re
import shutil
import sys
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

URL = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8060").rstrip("/")
OUT = Path(__file__).resolve().parents[1] / "artifacts"
PROFILE_KEY = "/userfs/godot/app_userdata/Kosmosekuller/courier.cfg"
STORAGE = """async ({key, replacement}) => {
 const db = await new Promise((resolve,reject) => {
  const r=indexedDB.open('/userfs');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);
 });
 try {
  if (!db.objectStoreNames.contains('FILE_DATA')) return '';
  const tx=db.transaction('FILE_DATA',replacement===null?'readonly':'readwrite');
  const done=new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);});
  const store=tx.objectStore('FILE_DATA');
  const record=await new Promise((resolve,reject)=>{const r=store.get(key);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  if (!record) return '';
  if (replacement!==null) {
   record.contents=new TextEncoder().encode(replacement);record.timestamp=new Date();store.put(record,key);
  }
  await done;
  return new TextDecoder().decode(record.contents);
 } finally {db.close();}
}"""


def open_game(context, errors):
    page = context.new_page()
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
    page.goto(URL)
    page.wait_for_selector("#loading", state="detached", timeout=90000)
    page.wait_for_timeout(650)
    return page


def profile(page):
    return page.evaluate(STORAGE, {"key": PROFILE_KEY, "replacement": None})


def saved(page, *fragments):
    for _ in range(20):
        content = profile(page)
        if all(fragment in content for fragment in fragments):
            return content
        page.wait_for_timeout(250)
    raise AssertionError(f"Missing saved fragments {fragments}:\n{content}")


def replace_fixture(context, page, content, errors):
    # Close the actual engine first so its in-memory filesystem cannot race the fixture.
    page.close()
    fixture = context.new_page()
    fixture.route("**/__courier_storage_fixture", lambda route: route.fulfill(
        status=200, content_type="text/html", body="<title>Isolated QA fixture</title>"))
    fixture.goto(URL + "/__courier_storage_fixture")
    result = fixture.evaluate(STORAGE, {"key": PROFILE_KEY, "replacement": content})
    assert result == content
    fixture.close()
    return open_game(context, errors)


def laser_pixels(png):
    picture = Image.open(io.BytesIO(png)).convert("RGB")
    # The untouched ship is below this band; the intro, HUD and coins are excluded.
    return sum(1 for y in range(600, 1180) for x in range(532, 549)
               if (lambda c: c[1] > 195 and c[1] > c[0] + 35 and c[2] > 170)(picture.getpixel((x, y))))


def main():
    OUT.mkdir(exist_ok=True)
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=os.environ.get("CHROMIUM_PATH") or shutil.which("chromium") or shutil.which("google-chrome") or playwright.chromium.executable_path,
            args=["--no-sandbox", "--disable-dev-shm-usage", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
        )
        context = browser.new_context(viewport={"width": 540, "height": 960}, device_scale_factor=2, has_touch=True, is_mobile=True)
        page = open_game(context, errors)
        page.touchscreen.tap(432, 58)  # A real UI action creates the initial filesystem.
        saved(page, "sound=false")
        legacy = ('[records]\nscore=2600\ndeliveries=5\n[settings]\nsound=false\n'
                  '[progress]\nunlocked_level=3\nselected_level=3\nstars={1: 3, 2: 2, 3: 1}\n')
        page = replace_fixture(context, page, legacy, errors)
        page.touchscreen.tap(432, 58)
        page.wait_for_timeout(150)
        page.touchscreen.tap(432, 58)
        migrated = saved(page, "unlocked_level=4", "selected_level=3", "wallet=0", "sound=false", "2: 2")
        page.locator("canvas").screenshot(path=str(OUT / "08-campaign-migration.png"))
        print("PASS  actual engine migrates the old three-region save to 100 levels without losing stars or sound", flush=True)

        # Test-only starting funds in this isolated context, not in the production game.
        funded = migrated.replace("wallet=0", "wallet=250")
        page = replace_fixture(context, page, funded, errors)
        page.touchscreen.tap(370, 624)
        page.wait_for_timeout(150)
        page.locator("canvas").screenshot(path=str(OUT / "09-shop.png"))
        page.touchscreen.tap(155, 411)  # Aurora / 90 coins.
        purchased = saved(page, 'ship="aurora"', "wallet=160")
        page.touchscreen.tap(155, 411)  # Already equipped; must never charge again.
        page.wait_for_timeout(350)
        assert "wallet=160" in profile(page)
        page.touchscreen.tap(155, 609)  # Violet trail / 60 coins.
        saved(page, 'trail="violet_trail"', "wallet=100")
        print("PASS  actual touch purchases charge once and independently equip a ship and trail", flush=True)

        page.touchscreen.tap(385, 807)  # Premium preview.
        page.wait_for_timeout(300)
        page.locator("canvas").screenshot(path=str(OUT / "10-premium-preview.png"))
        unchanged = profile(page)
        assert 'ship="aurora"' in unchanged and "wallet=100" in unchanged and '"nightwing"' not in unchanged
        page.touchscreen.tap(100, 150)
        today = datetime.datetime.now(datetime.timezone.utc).date()
        if datetime.date(2026, 10, 15) <= today <= datetime.date(2026, 11, 7):
            page.touchscreen.tap(155, 807)
            saved(page, 'ship="pumpkin"', "wallet=100")
            print("PASS  Halloween gift is claimed for free through the real UI", flush=True)
        page.touchscreen.tap(155, 898)  # Restore original ship.
        saved(page, 'ship="courier"', "wallet=100")
        page.touchscreen.tap(385, 898)  # Restore original trail.
        saved(page, 'trail="mint_trail"', "wallet=100")
        page.locator("canvas").screenshot(path=str(OUT / "11-shop-owned.png"))
        print("PASS  premium preview cannot purchase or equip the paid ship; original cosmetics remain selectable", flush=True)

        page.touchscreen.tap(100, 150)  # Home.
        page.touchscreen.tap(170, 624)  # Map.
        page.touchscreen.tap(385, 268)  # Select unlocked level 2.
        saved(page, "selected_level=2")
        for _ in range(9):
            page.touchscreen.tap(385, 867)
            page.wait_for_timeout(50)
        page.locator("canvas").screenshot(path=str(OUT / "12-levels-91-100.png"))
        page.touchscreen.tap(385, 578)  # Locked level 100.
        page.wait_for_timeout(200)
        assert "selected_level=2" in profile(page)
        print("PASS  map reaches its final page while locked levels cannot replace the selected unlocked level", flush=True)
        page.close()
        page = open_game(context, errors)
        restored = profile(page)
        assert all(fragment in restored for fragment in ["wallet=100", 'ship="courier"', 'trail="mint_trail"', '"aurora"', '"violet_trail"', "selected_level=2", "unlocked_level=4"])
        print("PASS  a full engine/browser reload retains wallet, purchases, equipment and campaign progress", flush=True)

        page.touchscreen.tap(270, 711)
        page.wait_for_timeout(450)
        canvas = page.locator("canvas")
        with_shots = canvas.screenshot(path=str(OUT / "13-shooting.png"))
        assert laser_pixels(with_shots) > 30, "Autofire must render visible mint laser projectiles"
        page.touchscreen.tap(445, 862)
        saved(page, "auto_fire=false")
        page.wait_for_timeout(1100)
        without_shots = canvas.screenshot()
        assert laser_pixels(without_shots) < 20, "Switching autofire off must stop visible projectiles after they leave the screen"
        print("PASS  visible projectiles fire in the actual WebAssembly game and the touch toggle stops them", flush=True)
        assert not errors, "Browser errors:\n" + "\n".join(errors)
        print("PASS  no JavaScript, WebGL or Godot errors in menus, purchases, reloads or combat", flush=True)
        browser.close()


if __name__ == "__main__":
    main()
