#!/usr/bin/env python3
"""Exercise all 24 language buttons, reloads and actual free-pass claims in WASM.

The XP fixture is confined to an isolated browser; production has no test hooks.
"""
import io
import os
import shutil

from PIL import Image
from playwright.sync_api import sync_playwright
from browser_economy import OUT, open_game, profile, replace_fixture, saved

CODES = ["et", "en", "es", "pt_BR", "fr", "de", "it", "nl", "pl", "ro", "fi", "sv", "tr", "ru", "uk", "el", "id", "vi", "th", "ar", "hi", "zh_CN", "ja", "ko"]
SCREENSHOTS = {"ar": "15-arabic-home.png", "hi": "16-hindi-home.png", "th": "17-thai-home.png", "zh_CN": "18-chinese-home.png", "ja": "19-japanese-home.png", "ko": "20-korean-home.png"}


def title_ink(png):
    picture = Image.open(io.BytesIO(png)).convert("RGB").crop((64, 72, 694, 152))
    return {index for index, color in enumerate(picture.get_flattened_data()) if color[0] > 215 and color[1] > 210 and color[2] > 170}


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
        page.touchscreen.tap(432, 58)
        saved(page, "sound=false")
        for index, code in enumerate(CODES):
            page.touchscreen.tap(380, 58)
            page.wait_for_timeout(220)
            if index == 0:
                page.locator("canvas").screenshot(path=str(OUT / "14-language-picker.png"))
            page.touchscreen.tap((80 + (index % 3) * 312 + 148) / 2, (560 + (index // 3) * 146 + 58) / 2)
            page.wait_for_timeout(250)
            saved(page, f'language="{code}"')
            if code in SCREENSHOTS:
                before = page.locator("canvas").screenshot(path=str(OUT / SCREENSHOTS[code]))
                assert len(title_ink(before)) > 500, f"{code}: a visibly rendered title is required"
                if code in ["ar", "ja"]:
                    page.close()
                    page = open_game(context, errors)
                    after = page.locator("canvas").screenshot()
                    first, second = title_ink(before), title_ink(after)
                    assert len(first & second) / max(len(first), len(second)) > 0.95, f"{code}: actual rendered language did not survive engine reload"
            print(f"PASS  touch selects and persists language {code}", flush=True)
        print("PASS  Arabic and Japanese text rendering survives complete engine reloads", flush=True)

        # Supply earned XP only in this marked, isolated test profile.
        content = profile(page)
        assert "xp=0" in content and "wallet=0" in content, content
        page = replace_fixture(context, page, content.replace("xp=0", "xp=2000"), errors)
        page.touchscreen.tap(270, 822)
        page.wait_for_timeout(200)
        page.locator("canvas").screenshot(path=str(OUT / "21-free-pass.png"))
        page.touchscreen.tap(425, 360)
        saved(page, "wallet=10")
        page.touchscreen.tap(425, 360)
        page.wait_for_timeout(350)
        assert "wallet=10" in profile(page), "The same claim must not pay twice"
        page.touchscreen.tap(385, 786)
        page.wait_for_timeout(200)
        page.touchscreen.tap(425, 708)
        saved(page, 'trail="moon_trail"', "wallet=10")
        page.locator("canvas").screenshot(path=str(OUT / "22-exclusive-pass-trail.png"))
        print("PASS  actual pass buttons pay a coin reward once and unlock the exclusive final trail", flush=True)
        page.close()
        page = open_game(context, errors)
        restored = saved(page, 'trail="moon_trail"', 'language="ko"', "xp=2000", "wallet=10")
        assert '"moon_trail"' in restored
        assert "claimed=" in restored and "[1, 10]" in restored, restored
        print("PASS  language, XP, claims, exclusive trail and wallet survive browser reload together", flush=True)
        assert not errors, "Browser errors:\n" + "\n".join(errors)
        print("PASS  no JavaScript, WebGL or Godot errors across 24 languages and season claims", flush=True)
        browser.close()


if __name__ == "__main__":
    main()
