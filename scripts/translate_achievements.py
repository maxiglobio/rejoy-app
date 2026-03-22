#!/usr/bin/env python3
"""
Translate achievements.json from Russian to English and Ukrainian.
Requires: pip install deep-translator
"""

import json
import time
from pathlib import Path

try:
    from deep_translator import GoogleTranslator
except ImportError:
    print("Install: pip install deep-translator")
    exit(1)


def translate(text: str, target: str, source: str = "ru") -> str:
    """Translate text from source to target language."""
    if not text or not text.strip():
        return text
    try:
        t = GoogleTranslator(source=source, target=target)
        return t.translate(text)
    except Exception as e:
        print(f"  Warning: {e}")
        return text


def main():
    script_dir = Path(__file__).parent
    json_path = script_dir.parent / "Rejoy" / "Resources" / "achievements.json"
    if not json_path.exists():
        json_path = script_dir.parent / "achievements.json"
    if not json_path.exists():
        print(f"Not found: {json_path}")
        exit(1)

    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    achievements = data["achievements"]
    total = len(achievements)
    print(f"Translating {total} achievements...")

    for i, a in enumerate(achievements):
        ru_title = a["title"]["ru"]
        ru_desc = a["description"]["ru"]

        # Skip if en/uk already differ from ru (already translated)
        en_title = a["title"]["en"]
        uk_title = a["title"]["uk"]
        if en_title != ru_title and uk_title != ru_title:
            print(f"  [{i+1}/{total}] Skipping (already translated): {ru_title[:30]}...")
            continue

        print(f"  [{i+1}/{total}] {ru_title[:40]}...")

        a["title"]["en"] = translate(ru_title, "en")
        time.sleep(0.2)
        a["title"]["uk"] = translate(ru_title, "uk")
        time.sleep(0.2)
        a["description"]["en"] = translate(ru_desc, "en")
        time.sleep(0.2)
        a["description"]["uk"] = translate(ru_desc, "uk")
        time.sleep(0.3)

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Done. Saved to {json_path}")


if __name__ == "__main__":
    main()
