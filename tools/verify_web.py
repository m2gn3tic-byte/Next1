#!/usr/bin/env python3
"""Check the actual hosted release and WASM content type, without credentials."""
import argparse
import json
import time
from urllib.parse import urljoin
from urllib.request import Request, urlopen


def verify(base_url, expected_version):
    base_url = base_url.rstrip("/") + "/"
    query = "?release-check=" + str(time.time_ns())
    with urlopen(base_url + "version.json" + query, timeout=20) as response:
        metadata = json.load(response)
    if metadata["version"] != expected_version:
        raise ValueError("Hosted version has not updated yet: " + str(metadata["version"]))
    with urlopen(base_url + query, timeout=20) as response:
        html = response.read().decode()
    prefix = "game-" + expected_version
    if "KOSMOSEKULLER" not in html or prefix + ".js" not in html:
        raise ValueError("Hosted HTML does not point to the expected release")
    for suffix in [".js", ".pck", ".wasm"]:
        request = Request(urljoin(base_url, prefix + suffix), method="HEAD")
        with urlopen(request, timeout=20) as response:
            if response.status != 200:
                raise ValueError("Hosted asset unavailable: " + suffix)
            if suffix == ".wasm" and response.headers.get_content_type() != "application/wasm":
                raise ValueError("The host is not serving WebAssembly with the correct content type")
    print("Verified playable web release:", expected_version)
    print("URL:", base_url)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--expected-version", required=True)
    parser.add_argument("--attempts", type=int, default=1)
    args = parser.parse_args()
    for attempt in range(args.attempts):
        try:
            verify(args.url, args.expected_version)
            return
        except Exception:
            if attempt + 1 == args.attempts:
                raise
            print("Waiting for the new deployment to propagate…", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    main()
