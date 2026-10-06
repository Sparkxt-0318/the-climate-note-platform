#!/usr/bin/env python3
"""Select a matching Pixabay cover for a Climate Note article.

Usage:
  set PIXABAY_API_KEY=...
  python scripts/select_pixabay_cover.py --topic Water --title "Pharmaceutical pollution"
  python scripts/select_pixabay_cover.py --query "pharmaceutical pollution river research"

Prints a coverAsset JSON object suitable for Firestore / article publish payloads.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone


API_URL = "https://pixabay.com/api/"
LICENSE_URL = "https://pixabay.com/service/license-summary/"


def clip_query(value: str, limit: int = 100) -> str:
    cleaned = re.sub(r"\s+", " ", value).strip()
    return cleaned[:limit].strip()


def build_query(args: argparse.Namespace) -> str:
    if args.query:
        return clip_query(args.query)
    parts: list[str] = []
    if args.topic:
        parts.append(args.topic.strip())
    if args.title:
        words = [w for w in re.split(r"[^A-Za-z0-9]+", args.title) if len(w) > 3][:5]
        parts.extend(words)
    if not parts:
        parts.append("climate nature")
    return clip_query(" ".join(parts))


def score_hit(hit: dict) -> int:
    value = 0
    value += min(int(hit.get("likes") or 0), 5_000)
    value += min(int(hit.get("downloads") or 0) // 10, 5_000)
    value += min(int(hit.get("views") or 0) // 100, 2_000)
    width = int(hit.get("imageWidth") or hit.get("webformatWidth") or 0)
    height = int(hit.get("imageHeight") or hit.get("webformatHeight") or 0)
    if width >= 1280:
        value += 800
    if width >= height:
        value += 600
    if height > 0 and (width / height) >= 1.3:
        value += 400
    if hit.get("type") == "photo":
        value += 300
    return value


def search(api_key: str, query: str, editors_choice: bool) -> list[dict]:
    params = {
        "key": api_key,
        "q": query,
        "image_type": "photo",
        "orientation": "horizontal",
        "safesearch": "true",
        "order": "popular",
        "per_page": "20",
        "min_width": "1200" if editors_choice else "1000",
    }
    if editors_choice:
        params["editors_choice"] = "true"
    url = API_URL + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": "ClimateNote-cover-selector/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.load(response)
    return list(payload.get("hits") or [])


def cover_asset(hit: dict, topic: str, title: str, alt_text: str | None) -> dict:
    photographer = (hit.get("user") or "").strip()
    image_url = hit.get("largeImageURL") or hit.get("webformatURL") or hit.get("previewURL")
    if not image_url:
        raise RuntimeError("Selected hit is missing an image URL")
    return {
        "url": image_url,
        "altText": alt_text
        or f"{topic or 'Climate'} story cover for {title or 'this note'}",
        "caption": f"{topic} · story cover" if topic else "Story cover",
        "attribution": (
            f"Photo by {photographer} via Pixabay" if photographer else "Photo via Pixabay"
        ),
        "license": "Pixabay Content License",
        "sourceUrl": hit.get("pageURL"),
        "generated": False,
        "provider": "pixabay",
        "providerAssetId": str(hit.get("id")),
        "photographer": photographer or None,
        "licenseUrl": LICENSE_URL,
        "retrievedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query", help="Exact Pixabay search query (visualPlan.searchQuery)")
    parser.add_argument("--topic", default="", help="Article topic")
    parser.add_argument("--title", default="", help="Article title")
    parser.add_argument("--alt-text", default=None, help="Optional alt text override")
    parser.add_argument(
        "--api-key",
        default=os.environ.get("PIXABAY_API_KEY", ""),
        help="Pixabay API key (or set PIXABAY_API_KEY)",
    )
    args = parser.parse_args()

    if not args.api_key:
        print("Missing Pixabay API key. Set PIXABAY_API_KEY or pass --api-key.", file=sys.stderr)
        return 2

    query = build_query(args)
    hits = search(args.api_key, query, editors_choice=True)
    if not hits:
        hits = search(args.api_key, query, editors_choice=False)
    if not hits:
        print(f"No Pixabay hits for query: {query}", file=sys.stderr)
        return 1

    best = max(hits, key=score_hit)
    payload = cover_asset(best, args.topic, args.title, args.alt_text)
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
