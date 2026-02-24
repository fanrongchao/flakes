#!/usr/bin/env python3
import argparse
import json
import os
import re
import time
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
    "FunASR",
    "CUDA",
    "PyTorch",
    "Transformers",
    "NixOS",
    "Claude Opus 4.1",
    "Claude Sonnet 4",
    "claude-opus-4-1-20250805",
    "claude-sonnet-4-20250514",
    "claude-3-7-sonnet-20250219",
    "claude-3-7-sonnet-latest",
}

ALLOW_SIMPLE_WORDS = {
    "openai",
    "chatgpt",
    "claude",
    "codex",
    "funasr",
    "pytorch",
    "tensorflow",
    "transformers",
    "kubernetes",
    "docker",
    "nixos",
    "linux",
    "python",
    "rust",
    "go",
    "typescript",
    "javascript",
    "postgresql",
    "mysql",
    "redis",
    "kafka",
    "grpc",
    "cuda",
    "gpu",
    "cpu",
    "api",
    "llm",
    "asr",
    "tts",
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


OFFICIAL_SOURCES = [
    # FunASR / ASR upstream
    "https://github.com/modelscope/FunASR",
    "https://github.com/FunAudioLLM/Fun-ASR",
    # Claude model names
    "https://docs.anthropic.com/en/docs/about-claude/models/all-models",
    # OpenAI model pages
    "https://platform.openai.com/docs/models",
    # Focused docs pages to reduce generic web noise.
    "https://pytorch.org/get-started/locally/",
    "https://kubernetes.io/docs/concepts/overview/",
    "https://nixos.org/",
]


TOKEN_PATTERNS = [
    # model ids / package ids / dashed technical ids
    re.compile(r"\b[a-z0-9]+(?:[-._/][a-z0-9]+){1,6}\b", re.IGNORECASE),
    # CamelCase / PascalCase tokens
    re.compile(r"\b[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+\b"),
    # Acronyms and mixed alnum acronyms (e.g., ASR, GPT4)
    re.compile(r"\b[A-Z]{2,}[0-9]*\b"),
    # Claude family text forms
    re.compile(r"\bclaude[- ](?:opus|sonnet|haiku)[- ]?[0-9.]*\b", re.IGNORECASE),
]


def fetch_url(url, timeout=20):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "voice-input-funasr-tech-sync/1.0",
            "Accept": "text/html,application/json;q=0.9,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = resp.read()
    enc = "utf-8"
    return data.decode(enc, errors="ignore")


def strip_html(text):
    text = re.sub(r"(?is)<script.*?>.*?</script>", " ", text)
    text = re.sub(r"(?is)<style.*?>.*?</style>", " ", text)
    text = re.sub(r"(?is)<[^>]+>", " ", text)
    text = re.sub(r"&[a-zA-Z0-9#]+;", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def extract_tokens(text):
    out = set()
    for pat in TOKEN_PATTERNS:
        for m in pat.finditer(text):
            tok = m.group(0).strip()
            if tok:
                out.add(tok)
    return out


def fetch_stackoverflow_tags(pages, pagesize, delay):
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
        if delay > 0:
            time.sleep(delay)
    return tags


def normalize_token(token):
    t = token.strip().lower()
    if not t:
        return None
    t = ALIASES.get(t, t)
    # Normalize common separators, keep single-token lexicon style.
    t = t.replace("/", "-").replace("_", "-").replace(" ", "-")
    t = re.sub(r"[^a-z0-9.-]+", "-", t)
    t = re.sub(r"-{2,}", "-", t).strip("-")
    t = re.sub(r"\s+", " ", t).strip()
    if not t:
        return None
    if len(t) < 2 or len(t) > 40:
        return None
    if t.isdigit() or not any(c.isalpha() for c in t):
        return None
    if t[0].isdigit():
        return None
    if t.startswith("http"):
        return None
    if t.startswith("www-"):
        return None
    if "github-com-" in t:
        return None
    # Drop tokens dominated by digits (versions/IP-like noise).
    digit_count = sum(1 for c in t if c.isdigit())
    if digit_count > 0 and digit_count >= max(3, len(t) // 2):
        return None
    if re.match(r"^[a-z]*\d+(?:[.-]\d+)+[a-z0-9.-]*$", t):
        return None
    if re.match(r"^\d+\.\d+\.\d+\.\d+$", t):
        return None
    # Keep at most 4 segments to avoid path-like tokens.
    if t.count("-") > 3:
        return None
    # Reject plain lowercase words unless explicitly allowed.
    if re.match(r"^[a-z]+$", t) and t not in ALLOW_SIMPLE_WORDS:
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
    upper_map = {"api", "llm", "asr", "tts", "gpu", "cpu", "ram", "gpt", "nlp"}
    if word.lower() in upper_map:
        return word.upper()
    title_map = {
        "openai": "OpenAI",
        "chatgpt": "ChatGPT",
        "nixos": "NixOS",
        "pytorch": "PyTorch",
        "funasr": "FunASR",
    }
    if word.lower() in title_map:
        return title_map[word.lower()]
    return word


def write_words(path, words):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("# Auto-generated technical lexicon for voice input.\n")
        f.write("# Regenerate with: voice-input-funasr-tech-lexicon-sync\n")
        for w in sorted(words, key=lambda x: x.lower()):
            f.write(f"{w}\n")


def main():
    p = argparse.ArgumentParser(description="Sync technical lexicon words from official/public sources.")
    p.add_argument(
        "--out",
        default=os.path.expanduser("~/.local/share/voice-input-funasr-nano/lexicons/tech_en.user.words"),
        help="Output words file",
    )
    p.add_argument("--pages", type=int, default=6, help="StackOverflow tag pages")
    p.add_argument("--pagesize", type=int, default=100, help="Tags per page")
    p.add_argument("--source", action="append", default=[], help="Additional source URL(s)")
    p.add_argument("--disable-official-sources", action="store_true", help="Disable built-in official sources")
    p.add_argument("--disable-stackoverflow", action="store_true", help="Disable StackOverflow tags source")
    p.add_argument("--ignore-existing", action="store_true", help="Do not merge existing output file content")
    p.add_argument("--request-delay", type=float, default=0.15, help="Delay between network requests (seconds)")
    p.add_argument("--max-words", type=int, default=2500, help="Maximum output words after sorting")
    args = p.parse_args()

    existing = set() if args.ignore_existing else read_existing(args.out)
    normalized = set()
    for w in existing | SEED_WORDS:
        n = normalize_token(w)
        if n:
            normalized.add(canonicalize(n))

    sources = []
    if not args.disable_official_sources:
        sources.extend(OFFICIAL_SOURCES)
    sources.extend(args.source)

    for src in sources:
        try:
            raw = fetch_url(src)
            text = strip_html(raw)
            toks = extract_tokens(text)
            for tok in toks:
                n = normalize_token(tok)
                if n:
                    normalized.add(canonicalize(n))
            print(f"source ok: {src} (+{len(toks)} raw tokens)")
        except (urllib.error.URLError, TimeoutError, ValueError) as e:
            print(f"warning: source failed: {src}: {e}")
        if args.request_delay > 0:
            time.sleep(args.request_delay)

    if not args.disable_stackoverflow:
        try:
            tags = fetch_stackoverflow_tags(args.pages, args.pagesize, args.request_delay)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"warning: failed to fetch StackOverflow tags: {e}")
            tags = set()
        for tag in tags:
            n = normalize_token(tag)
            if n:
                normalized.add(canonicalize(n))

    final_words = sorted(normalized, key=lambda x: x.lower())[: max(1, args.max_words)]
    write_words(args.out, final_words)
    print(f"wrote {len(final_words)} words to {args.out}")


if __name__ == "__main__":
    main()
