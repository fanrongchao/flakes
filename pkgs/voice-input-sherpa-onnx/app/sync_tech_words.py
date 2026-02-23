#!/usr/bin/env python3
import argparse
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request


SEED_WORDS = {
    "OpenAI",
    "ChatGPT",
    "GPT",
    "Codex",
    "Claude",
    "Claude Code",
    "agent",
    "API",
    "LLM",
    "ASR",
    "TTS",
}


ALIASES = {
    "c++": "cpp",
    "c#": "csharp",
    "f#": "fsharp",
    ".net": "dotnet",
    "node.js": "nodejs",
    "next.js": "nextjs",
    "nuxt.js": "nuxtjs",
    "vue.js": "vuejs",
}


def fetch_stackoverflow_tags(pages, pagesize):
    tags = set()
    base = "https://api.stackexchange.com/2.3/tags"
    for page in range(1, pages + 1):
        query = urllib.parse.urlencode(
            {
                "page": page,
                "pagesize": pagesize,
                "order": "desc",
                "sort": "popular",
                "site": "stackoverflow",
            }
        )
        url = f"{base}?{query}"
        with urllib.request.urlopen(url, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        for item in data.get("items", []):
            name = (item.get("name") or "").strip()
            if name:
                tags.add(name)
    return tags


def normalize_token(token):
    t = token.strip().lower()
    if not t:
        return None
    t = ALIASES.get(t, t)
    t = t.replace("-", " ").replace("_", " ")
    t = re.sub(r"[^a-z0-9. ]+", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    if not t:
        return None
    # Keep single token entries only for ASR fuzzy matching.
    if " " in t:
        return None
    if len(t) < 2 or len(t) > 40:
        return None
    if t.isdigit():
        return None
    return t


def read_existing(path):
    words = set()
    if not os.path.exists(path):
        return words
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            w = line.strip()
            if not w or w.startswith("#"):
                continue
            words.add(w)
    return words


def canonicalize(word):
    upper_map = {"api", "llm", "asr", "tts", "gpu", "cpu", "ram", "gpt"}
    if word.lower() in upper_map:
        return word.upper()
    title_map = {"openai": "OpenAI", "chatgpt": "ChatGPT", "nixos": "NixOS"}
    if word.lower() in title_map:
        return title_map[word.lower()]
    return word


def write_words(path, words):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("# Auto-generated technical lexicon for voice input.\n")
        f.write("# Regenerate with: voice-input-tech-lexicon-sync\n")
        for w in sorted(words, key=lambda x: x.lower()):
            f.write(f"{w}\n")


def main():
    p = argparse.ArgumentParser(description="Sync technical lexicon words from public sources.")
    p.add_argument(
        "--out",
        default=os.path.expanduser("~/.local/share/voice-input-sherpa-onnx/lexicons/tech_en.user.words"),
        help="Output words file",
    )
    p.add_argument("--pages", type=int, default=8, help="StackOverflow tag pages")
    p.add_argument("--pagesize", type=int, default=100, help="Tags per page")
    args = p.parse_args()

    existing = read_existing(args.out)
    normalized = set()
    for w in existing | SEED_WORDS:
        n = normalize_token(w)
        if n:
            normalized.add(canonicalize(n))

    try:
        tags = fetch_stackoverflow_tags(args.pages, args.pagesize)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
        print(f"warning: failed to fetch tags: {e}")
        tags = set()

    for tag in tags:
        n = normalize_token(tag)
        if n:
            normalized.add(canonicalize(n))

    write_words(args.out, normalized)
    print(f"wrote {len(normalized)} words to {args.out}")


if __name__ == "__main__":
    main()
