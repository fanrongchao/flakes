#!/usr/bin/env python3
import importlib
import io
import os
import queue
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import json
import difflib
from datetime import datetime, timezone
from contextlib import redirect_stderr, redirect_stdout
from functools import lru_cache

import numpy as np
import sounddevice as sd
import soundfile as sf
import yaml
from pynput import keyboard

NOISY_RUNTIME_PATTERNS = (
    "Warning, miss key in ckpt:",
    "WARNING:root:trust_remote_code",
    "Loading remote code successfully:",
    "Please install torch_complex firstly",
)

MODEL_REPO_ID = "FunAudioLLM/Fun-ASR-Nano-2512"
MODEL_INFO_URL = f"https://huggingface.co/{MODEL_REPO_ID}"
QWEN_SUBDIR = "Qwen3-0.6B"
LOCAL_WHISPER_ASSETS = os.path.join(os.path.dirname(__file__), "whisper_assets")


class _LineFilterStream:
    def __init__(self, inner, patterns):
        self._inner = inner
        self._patterns = tuple(patterns)
        self._buf = ""

    def write(self, data):
        if not data:
            return 0
        self._buf += data
        wrote = 0
        while "\n" in self._buf:
            line, self._buf = self._buf.split("\n", 1)
            if not any(p in line for p in self._patterns):
                self._inner.write(line + "\n")
                wrote += len(line) + 1
        return wrote

    def flush(self):
        if self._buf and not any(p in self._buf for p in self._patterns):
            self._inner.write(self._buf)
        self._buf = ""
        self._inner.flush()

    def isatty(self):
        return self._inner.isatty()

    @property
    def encoding(self):
        return getattr(self._inner, "encoding", None)

    def fileno(self):
        return self._inner.fileno()


def install_runtime_log_filter():
    sys.stdout = _LineFilterStream(sys.stdout, NOISY_RUNTIME_PATTERNS)
    sys.stderr = _LineFilterStream(sys.stderr, NOISY_RUNTIME_PATTERNS)


def load_config():
    path = os.getenv(
        "VOICE_INPUT_FUNASR_NANO_CONFIG",
        os.path.expanduser("~/.config/voice-input-funasr-nano/config.yaml"),
    )
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def notify(msg, expire_ms=None, replace_id=None):
    if not shutil.which("notify-send"):
        return replace_id
    cmd = ["notify-send"]
    if replace_id is not None:
        cmd.extend(["-r", str(replace_id)])
    if expire_ms is not None:
        cmd.extend(["-t", str(int(expire_ms))])
    cmd.extend(["-p", "Voice Input FunASR", msg])
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        out = (r.stdout or "").strip()
        return int(out) if out.isdigit() else replace_id
    except Exception:
        return replace_id


def to_bool(v, default=False):
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        s = v.strip().lower()
        if s in {"1", "true", "yes", "on"}:
            return True
        if s in {"0", "false", "no", "off"}:
            return False
    return default


def fallback_to_fw_streaming(reason):
    notify(f"funasr-nano failed, fallback to fw-streaming: {reason}")
    subprocess.run(["systemctl", "--user", "start", "voice-input-fw-streaming.service"], check=False)


def norm_token(key):
    if key in (keyboard.Key.ctrl, keyboard.Key.ctrl_l, keyboard.Key.ctrl_r):
        return "ctrl"
    if key in (keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r):
        return "shift"
    if key in (keyboard.Key.alt, keyboard.Key.alt_l, keyboard.Key.alt_r):
        return "alt"
    if key in (keyboard.Key.cmd, keyboard.Key.cmd_l, keyboard.Key.cmd_r):
        return "meta"
    if key == keyboard.Key.space:
        return "space"
    if isinstance(key, keyboard.Key):
        name = (key.name or "").lower()
        if any(x in name for x in ("cmd", "super", "win", "meta")):
            return "meta"
        return name
    if hasattr(key, "char") and key.char:
        return key.char.lower()
    return ""


def get_window_class(window_id):
    try:
        return subprocess.run(
            ["xprop", "-id", window_id, "WM_CLASS"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        ).stdout.lower()
    except Exception:
        return ""


def is_terminal_window(window_id):
    terminals = {
        "kitty", "alacritty", "st", "xterm", "urxvt", "gnome-terminal-server",
        "konsole", "xfce4-terminal", "foot", "wezterm-gui", "terminator", "tilix",
    }
    out = get_window_class(window_id)
    return any(t in out for t in terminals)


def is_kitty_window(window_id):
    return "kitty" in get_window_class(window_id)


def load_replacements_file(path):
    rules = []
    if not os.path.exists(path):
        return rules
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=>" not in line:
                continue
            left, right = line.split("=>", 1)
            left = left.strip()
            right = right.strip()
            if left and right:
                rules.append((left, right))
    return rules


def expand_pathspec(spec):
    parts = [p.strip() for p in str(spec).split(os.pathsep) if p.strip()]
    return os.pathsep.join(os.path.expanduser(p) for p in parts)


def load_replacements_sources(spec):
    rules = []
    parts = [p.strip() for p in str(spec).split(os.pathsep) if p.strip()]
    for p in parts:
        rules.extend(load_replacements_file(os.path.expanduser(p)))
    return rules


def append_jsonl(path, obj):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(obj, ensure_ascii=False) + "\n")
    except Exception:
        pass


def load_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def save_json(path, data):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def upsert_replacement_rule(path, wrong, right):
    wrong = wrong.strip()
    right = right.strip()
    if not wrong or not right or wrong.lower() == right.lower():
        return
    lines = []
    try:
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                lines = [ln.rstrip("\n") for ln in f]
    except Exception:
        lines = []

    out = []
    found = False
    for ln in lines:
        s = ln.strip()
        if not s or s.startswith("#") or "=>" not in s:
            out.append(ln)
            continue
        left, _ = s.split("=>", 1)
        if left.strip().lower() == wrong.lower():
            out.append(f"{wrong} => {right}")
            found = True
        else:
            out.append(ln)
    if not found:
        if out and out[-1].strip():
            out.append("")
        out.append(f"{wrong} => {right}")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            if out:
                f.write("\n".join(out) + "\n")
            else:
                f.write(f"{wrong} => {right}\n")
    except Exception:
        pass


def learning_tokens(text):
    return re.findall(r"[A-Za-z0-9]+|[\u4e00-\u9fff]+", text)


def auto_learn_corrections(raw_text, final_text, tech_words, state_path, auto_rules_path, min_hits=2):
    raw_toks = learning_tokens(raw_text)
    fin_toks = learning_tokens(final_text)
    if not raw_toks or not fin_toks:
        return []

    state = load_json(state_path, {"pairs": {}})
    pairs = state.get("pairs", {})
    if not isinstance(pairs, dict):
        pairs = {}

    canon = {w.lower() for w in tech_words if isinstance(w, str) and w.strip()}
    blocked_wrong = {
        "code", "open", "ai", "model", "performance", "agent",
        "api", "english", "today", "test",
    }

    sm = difflib.SequenceMatcher(None, [t.lower() for t in raw_toks], [t.lower() for t in fin_toks])
    learned = []

    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "replace":
            continue
        src_seg = raw_toks[i1:i2]
        dst_seg = fin_toks[j1:j2]
        if not src_seg or not dst_seg or len(dst_seg) != 1 or len(src_seg) > 4:
            continue

        right = dst_seg[0].strip()
        if not right:
            continue
        right_low = right.lower()
        if right_low not in canon:
            continue

        wrong_phrase = " ".join(src_seg).strip()
        wrong_compact = "".join(re.sub(r"[^A-Za-z0-9]", "", t) for t in src_seg).strip()
        score = max(
            difflib.SequenceMatcher(None, wrong_phrase.lower(), right_low).ratio(),
            difflib.SequenceMatcher(None, wrong_compact.lower(), right_low).ratio() if wrong_compact else 0.0,
        )
        if score < 0.58:
            continue

        if len(wrong_phrase) < 2 or len(wrong_phrase) > 24:
            continue
        if wrong_phrase.lower() in blocked_wrong:
            continue
        if wrong_phrase.lower() == right_low:
            continue

        key = f"{wrong_phrase.lower()}\t{right_low}"
        pairs[key] = int(pairs.get(key, 0)) + 1
        if pairs[key] >= min_hits:
            upsert_replacement_rule(auto_rules_path, wrong_phrase, right)
            learned.append((wrong_phrase, right))

    state["pairs"] = pairs
    save_json(state_path, state)
    return learned


def load_words_from_path(path):
    words = []
    if not os.path.exists(path):
        return words
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            w = line.strip()
            if not w or w.startswith("#"):
                continue
            words.append(w)
    return words


def load_words_sources(spec):
    # Support multiple lexicon files via os.pathsep, e.g. "a.words:b.words".
    parts = [p.strip() for p in str(spec).split(os.pathsep) if p.strip()]
    seen = set()
    merged = []
    for p in parts:
        for w in load_words_from_path(os.path.expanduser(p)):
            low = w.lower()
            if low in seen:
                continue
            seen.add(low)
            merged.append(w)
    return merged


def apply_replacements(text, rules, ignore_case=False):
    flags = re.IGNORECASE if ignore_case else 0
    for src, dst in rules:
        text = re.sub(re.escape(src), dst, text, flags=flags)
    return text


def apply_tech_fuzzy(text, tech_words):
    if not tech_words:
        return text

    word_map = {w.lower(): w for w in tech_words}
    candidates = list(word_map.keys())

    def repl(match):
        token = match.group(0)
        low = token.lower()
        if low in word_map:
            return word_map[low]
        if len(low) < 4:
            return token
        m = difflib.get_close_matches(low, candidates, n=1, cutoff=0.84)
        if not m:
            return token
        chosen = word_map[m[0]]
        # For acronyms, keep canonical uppercase.
        if chosen.isupper():
            return chosen
        return chosen

    return re.sub(r"[A-Za-z][A-Za-z0-9\-\._]{2,}", repl, text)


def normalize_tech_phrases(text):
    # Phrase-level normalization for common mixed zh/en ASR variants.
    rules = [
        (r"\bopen(?:[\s，,]+)*(?:a\s*i|ai|ei|eg|en|and\s+ai)\b", "OpenAI"),
        (r"\bopopen(?:[\s，,]+)*ai\b", "OpenAI"),
        (r"\bopen[\s，,]*(?:人|仁|en)[\s，,]*i\b", "OpenAI"),
        (r"\bopenai[\s，,]+i\b", "OpenAI"),
        (r"\bchat[\s，,]*g[\s，,]*p[\s，,]*t\b", "ChatGPT"),
        (r"\bg[\s，,]*p[\s，,]*t\b", "GPT"),
        (r"\b(?:code[\s，,]*x|de[\s，,]*lex|xcode)(?:[\s，,]+[a-z]{1,3})?\b", "Codex"),
        (r"\bag+agent\b", "agent"),
        (r"\benent\b", "agent"),
        (r"\bent(?:[\s，,]+ent)+\b", "agent"),
        (r"\bperfor(?:m|form|forform)\b", "performance"),
        (r"\bperm+?i\b", "performance"),
    ]
    for pattern, repl in rules:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)
    return text


def post_process_text(text, policy):
    text = text.strip()
    # Drop common Mandarin filler syllables at sentence start, e.g. "一我今天..."
    text = re.sub(r"^[一啊嗯呃额]\s*(?=[我你他她它这那今明昨])", "", text)
    # Keep Mandarin + English + digits and common punctuation, drop other scripts.
    text = re.sub(r"[^0-9A-Za-z\u4e00-\u9fff\s，。！？、,:;.!?\-_'\"()（）【】\[\]]+", "", text)
    if policy == "light-normalize":
        text = text.replace("：", "，").replace(":", "，")
        text = text.replace("；", "，").replace(";", "，")
        text = re.sub(r"[，,]{2,}", "，", text)
        text = re.sub(r"[。.!！？?]{2,}", lambda m: m.group(0)[0], text)
        text = re.sub(r"\s*[，]\s*", "，", text)

    # Common dictation corrections for zh+en usage.
    replacement_rules = [
        (r"一二三", "123"),
        (r"四五六", "456"),
        (r"七八九", "789"),
        (r"四点一", "4.1"),
        (r"四点(?=[\s，,。.!！？?]*$)", "4.1"),
        (r"\bfour\s+point\s+one\b", "4.1"),
        (r"\bfor\s+point\s+one\b", "4.1"),
        (r"\bone\s+four\s+point\b", "4.1"),
        (r"\bgpt[\s，,]*four\s+point(?:\s+one)?\b", "GPT 4.1"),
        (r"\bopopen\s*ai\b", "OpenAI"),
        (r"\bopen\s*a\s*i\b", "OpenAI"),
        (r"\bchat\s*g\s*p\s*t\b", "ChatGPT"),
        (r"\benglish\b", "English"),
        (r"\babc\b", "ABC"),
        (r"\bapi\b", "API"),
    ]
    for pattern, repl in replacement_rules:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)

    text = normalize_tech_phrases(text)

    # Merge spaced letter abbreviations and uppercase them, e.g. "g p t" -> "GPT".
    text = re.sub(
        r"\b([A-Za-z])(?:\s+([A-Za-z])){1,6}\b",
        lambda m: re.sub(r"\s+", "", m.group(0)).upper(),
        text,
    )

    text = re.sub(
        r"(?<!\d)(?:\d\s*[、,，]\s*)+\d(?!\d)",
        lambda m: re.sub(r"\D", "", m.group(0)),
        text,
    )
    if text:
        text += " "
    return text


def extract_text_from_result(obj):
    if isinstance(obj, dict):
        t = obj.get("text")
        if isinstance(t, str) and t.strip():
            return t.strip()
        for v in obj.values():
            x = extract_text_from_result(v)
            if x:
                return x
    elif isinstance(obj, (list, tuple)):
        for it in obj:
            x = extract_text_from_result(it)
            if x:
                return x
    elif isinstance(obj, str) and obj.strip():
        return obj.strip()
    return ""


def _filter_model_load_logs(text):
    noisy_patterns = NOISY_RUNTIME_PATTERNS + (
        "Notice: If you want to use whisper",
    )
    out = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s:
            continue
        if any(p in s for p in noisy_patterns):
            continue
        out.append(s)
    return out


class App:
    def __init__(self, cfg):
        self.cfg = cfg
        s = cfg["funasr_nano"]
        self.sample_rate = int(s.get("sample_rate", 16000))
        self.chunk_ms = int(s.get("chunk_ms", 320))
        self.max_utterance_ms = int(s.get("max_utterance_ms", 12000))
        self.punctuation_policy = s.get("punctuation_policy", "light-normalize")
        self.interaction_mode = str(s.get("interaction_mode", "hold-to-talk")).strip().lower()
        if self.interaction_mode not in {"hold-to-talk", "toggle"}:
            self.interaction_mode = "hold-to-talk"
        feedback = s.get("feedback", {}) if isinstance(s.get("feedback"), dict) else {}
        sound_cfg = feedback.get("sound", {}) if isinstance(feedback.get("sound"), dict) else {}
        self.recording_notify = to_bool(feedback.get("recording_notify", True), True)
        self.thinking_notify = to_bool(feedback.get("thinking_notify", True), True)
        self.done_notify = to_bool(feedback.get("done_notify", False), False)
        self.sound_enable = to_bool(sound_cfg.get("enable", True), True)
        self.sound_on_start = to_bool(sound_cfg.get("on_start", True), True)
        self.sound_on_stop = to_bool(sound_cfg.get("on_stop", True), True)
        self.sound_on_done = to_bool(sound_cfg.get("on_done", False), False)
        self.sound_theme = str(sound_cfg.get("theme", "wispr-like")).strip().lower()

        self.base_zh_spec = expand_pathspec(
            os.getenv("VOICE_INPUT_BASE_ZH_RULES", os.path.join("lexicons", "base_zh.rules"))
        )
        self.base_en_spec = expand_pathspec(
            os.getenv("VOICE_INPUT_BASE_EN_RULES", os.path.join("lexicons", "base_en.rules"))
        )
        self.user_corrections_spec = expand_pathspec(
            os.getenv(
                "VOICE_INPUT_USER_CORRECTIONS",
                "~/.local/share/voice-input-funasr-nano/lexicons/user_corrections.rules",
            )
        )
        self.auto_rules_spec = expand_pathspec(
            os.getenv(
                "VOICE_INPUT_AUTO_CORRECTIONS",
                "~/.local/state/voice-input-funasr-nano/auto_corrections.rules",
            )
        )
        self.auto_rules_write_path = os.path.expanduser(
            os.getenv(
                "VOICE_INPUT_AUTO_CORRECTIONS_WRITE",
                "~/.local/state/voice-input-funasr-nano/auto_corrections.rules",
            )
        )
        self.auto_learning_state_path = os.path.expanduser(
            os.getenv(
                "VOICE_INPUT_AUTO_LEARNING_STATE",
                "~/.local/state/voice-input-funasr-nano/auto_learning.json",
            )
        )
        self.tech_words_spec = expand_pathspec(
            os.getenv("VOICE_INPUT_TECH_WORDS", os.path.join("lexicons", "tech_en.words"))
        )
        self.base_zh_rules = load_replacements_sources(self.base_zh_spec)
        self.base_en_rules = load_replacements_sources(self.base_en_spec)
        self.user_correction_rules = load_replacements_sources(self.user_corrections_spec)
        self.auto_correction_rules = load_replacements_sources(self.auto_rules_spec)
        self.tech_words = load_words_sources(self.tech_words_spec)
        self.history_path = os.path.expanduser(
            os.getenv(
                "VOICE_INPUT_HISTORY_PATH",
                "~/.local/state/voice-input-funasr-nano/history.jsonl",
            )
        )

        self.required_keys = set()
        for raw in cfg["hotkey"].split("+"):
            tok = raw.strip().lower()
            if tok in ("super", "win", "cmd", "meta"):
                tok = "meta"
            if tok:
                self.required_keys.add(tok)
        self.pressed = set()
        self.chord_active = False
        self.state = "idle"

        self._recording = False
        self._q = queue.Queue()
        self._frames = []
        self._target_window = None
        self._lock = threading.Lock()
        self._status_notify_id = None

        self.model_id = str(
            s.get("model", "~/.cache/huggingface/FunAudioLLM-Fun-ASR-Nano-2512")
        ).strip()
        self.device = str(s.get("device", "cpu")).strip()
        self.dtype = str(s.get("dtype", "float32")).strip()
        self.hotword_boost_enable = to_bool(s.get("hotword_boost_enable", True), True)
        self.hotword_boost_weight = float(s.get("hotword_boost_weight", 0.6))
        self.learning_min_hits = int(s.get("learning_min_hits", 2))
        self.auto_learn_enable = to_bool(s.get("auto_learn_enable", True), True)
        self.warmup_on_start = to_bool(s.get("warmup_on_start", True), True)
        self.warmup_blocking_start = to_bool(s.get("warmup_blocking_start", True), True)
        self.torch_num_threads = int(s.get("torch_num_threads", 8))
        self.language = s.get("language", "中文")
        self.itn = to_bool(s.get("itn", True), True)

        self._nano_model = None
        self._nano_kwargs = None

    def _patch_whisper_asset_fallbacks(self):
        # Some FunASR wheels miss whisper_lib/assets in site-packages.
        # Patch loader functions to fallback to bundled local assets.
        try:
            tok_mod = importlib.import_module("funasr.models.sense_voice.whisper_lib.tokenizer")
            audio_mod = importlib.import_module("funasr.models.sense_voice.whisper_lib.audio")
        except Exception:
            return

        if not getattr(tok_mod, "_voice_input_assets_patched", False):
            original_get_encoding = tok_mod.get_encoding

            @lru_cache(maxsize=None)
            def patched_get_encoding(name: str = "gpt2", num_languages: int = 99, vocab_path: str = None):
                if vocab_path and not os.path.isfile(vocab_path):
                    fallback_path = os.path.join(
                        LOCAL_WHISPER_ASSETS,
                        os.path.basename(vocab_path),
                    )
                    if os.path.isfile(fallback_path):
                        vocab_path = fallback_path
                elif vocab_path is None:
                    default_path = os.path.join(
                        os.path.dirname(tok_mod.__file__),
                        "assets",
                        f"{name}.tiktoken",
                    )
                    if not os.path.isfile(default_path):
                        fallback_path = os.path.join(LOCAL_WHISPER_ASSETS, f"{name}.tiktoken")
                        if os.path.isfile(fallback_path):
                            vocab_path = fallback_path
                return original_get_encoding(
                    name=name,
                    num_languages=num_languages,
                    vocab_path=vocab_path,
                )

            tok_mod.get_encoding = patched_get_encoding
            tok_mod._voice_input_assets_patched = True

        if not getattr(audio_mod, "_voice_input_assets_patched", False):
            original_mel_filters = audio_mod.mel_filters

            @lru_cache(maxsize=None)
            def patched_mel_filters(device, n_mels: int, filters_path: str = None):
                if filters_path and not os.path.isfile(filters_path):
                    fallback_path = os.path.join(LOCAL_WHISPER_ASSETS, os.path.basename(filters_path))
                    if os.path.isfile(fallback_path):
                        filters_path = fallback_path
                elif filters_path is None:
                    default_path = os.path.join(
                        os.path.dirname(audio_mod.__file__),
                        "assets",
                        "mel_filters.npz",
                    )
                    if not os.path.isfile(default_path):
                        fallback_path = os.path.join(LOCAL_WHISPER_ASSETS, "mel_filters.npz")
                        if os.path.isfile(fallback_path):
                            filters_path = fallback_path
                return original_mel_filters(device, n_mels, filters_path=filters_path)

            audio_mod.mel_filters = patched_mel_filters
            audio_mod._voice_input_assets_patched = True

    def _model_artifacts_health(self, model_dir):
        required_root_files = [
            "model.pt",
            "configuration.json",
            "config.yaml",
        ]
        for rel in required_root_files:
            if not os.path.isfile(os.path.join(model_dir, rel)):
                return False, f"missing {rel}"

        qwen_dir = os.path.join(model_dir, QWEN_SUBDIR)
        if not os.path.isdir(qwen_dir):
            return False, f"missing {QWEN_SUBDIR}/"
        if not os.path.isfile(os.path.join(qwen_dir, "config.json")):
            return False, f"missing {QWEN_SUBDIR}/config.json"

        has_tokenizer = (
            os.path.isfile(os.path.join(qwen_dir, "tokenizer.json"))
            or (
                os.path.isfile(os.path.join(qwen_dir, "vocab.json"))
                and os.path.isfile(os.path.join(qwen_dir, "merges.txt"))
            )
        )
        if not has_tokenizer:
            return False, f"missing tokenizer files under {QWEN_SUBDIR}/"

        return True, "ok"

    def resolve_model_source(self):
        model_src = os.path.expanduser(self.model_id)
        if not os.path.isabs(model_src):
            raise RuntimeError(
                f"funasr_nano.model must be an absolute local path, got: {self.model_id}"
            )
        ok, reason = self._model_artifacts_health(model_src)
        if not ok:
            print(f"model incomplete ({reason}), downloading from: {MODEL_INFO_URL}", flush=True)
            self.ensure_local_model(model_src)

        if not os.path.isdir(model_src):
            raise RuntimeError(f"model directory not found after download: {model_src}")
        ok, reason = self._model_artifacts_health(model_src)
        if not ok:
            raise RuntimeError(
                f"model artifacts incomplete after download ({reason}); source: {MODEL_INFO_URL}"
            )
        return model_src

    def ensure_local_model(self, model_dir):
        notify(f"Model missing, downloading from {MODEL_INFO_URL}")
        print(f"model missing, downloading from: {MODEL_INFO_URL}", flush=True)
        os.makedirs(model_dir, exist_ok=True)
        try:
            from huggingface_hub import snapshot_download

            snapshot_download(
                repo_id=MODEL_REPO_ID,
                local_dir=model_dir,
                local_dir_use_symlinks=False,
                resume_download=True,
                allow_patterns=[
                    "model.pt",
                    "config*.json",
                    "**/*.json",
                    "*.yaml",
                    "*.txt",
                    "README.md",
                    "model.py",
                    "ctc.py",
                    "tools/*",
                    "tools/**",
                    "example/*",
                    "example/**",
                    "am.mvn",
                    "tokens.json",
                    f"{QWEN_SUBDIR}/*",
                    f"{QWEN_SUBDIR}/**",
                ],
            )
            notify("Model download complete")
        except Exception as e:
            raise RuntimeError(
                f"auto-download model failed from {MODEL_INFO_URL}: {e}"
            ) from e

    def run(self):
        if self.warmup_on_start:
            if self.warmup_blocking_start:
                print("warming up model before ready...", flush=True)
                self._warmup_model()
                print("warmup done", flush=True)
            else:
                threading.Thread(target=self._warmup_model, daemon=True).start()
        listener = keyboard.Listener(on_press=self.on_press, on_release=self.on_release)
        listener.start()
        print("voice-input-funasr-nano started")
        while True:
            time.sleep(1)

    def _warmup_model(self):
        try:
            self.ensure_model()
            example = os.path.join(
                os.path.expanduser(self.resolve_model_source()),
                "example",
                "zh.mp3",
            )
            if os.path.exists(example):
                self.transcribe_with_funasr(example)
        except Exception as e:
            print(f"warmup skipped: {e}", flush=True)

    def on_press(self, key):
        tok = norm_token(key)
        if not tok:
            return
        self.pressed.add(tok)
        active = self.required_keys.issubset(self.pressed)
        if active and not self.chord_active:
            self.chord_active = True
            if self.interaction_mode == "toggle":
                self.toggle_recording()
            else:
                self.start_recording()

    def on_release(self, key):
        tok = norm_token(key)
        if tok in self.pressed:
            self.pressed.remove(tok)
        if self.chord_active and not self.required_keys.issubset(self.pressed):
            self.chord_active = False
            if self.interaction_mode == "hold-to-talk":
                self.stop_to_thinking()

    def play_feedback_sound(self, event):
        if not self.sound_enable:
            return
        if event == "start" and not self.sound_on_start:
            return
        if event == "stop" and not self.sound_on_stop:
            return
        if event == "done" and not self.sound_on_done:
            return

        # Short non-blocking earcons, inspired by voice dictation UI cues.
        if self.sound_theme == "wispr-like":
            mapping = {
                "start": (987.77, 0.050),
                "stop": (659.25, 0.060),
                "done": (523.25, 0.050),
            }
        else:
            mapping = {
                "start": (880.0, 0.050),
                "stop": (660.0, 0.060),
                "done": (520.0, 0.050),
            }

        tone = mapping.get(event)
        if not tone:
            return
        freq, dur = tone
        try:
            sr = 24000
            n = max(1, int(sr * dur))
            t = np.arange(n, dtype=np.float32) / np.float32(sr)
            env = np.linspace(1.0, 0.75, n, dtype=np.float32)
            wave = (0.12 * np.sin(2.0 * np.pi * np.float32(freq) * t) * env).astype(np.float32)
            sd.play(wave, sr, blocking=False)
        except Exception:
            return

    def emit_feedback(self, event):
        if event == "start":
            if self.recording_notify:
                self._status_notify_id = notify(
                    "Recording...",
                    expire_ms=10000,
                    replace_id=self._status_notify_id,
                )
            self.play_feedback_sound("start")
            return
        if event == "stop":
            if self.thinking_notify:
                self._status_notify_id = notify(
                    "Thinking...",
                    expire_ms=10000,
                    replace_id=self._status_notify_id,
                )
            self.play_feedback_sound("stop")
            return
        if event == "done":
            if self.done_notify:
                self._status_notify_id = notify(
                    "Done",
                    expire_ms=400,
                    replace_id=self._status_notify_id,
                )
            elif self._status_notify_id is not None:
                self._status_notify_id = notify(
                    " ",
                    expire_ms=1,
                    replace_id=self._status_notify_id,
                )
            self.play_feedback_sound("done")
            return

    def save_active_window(self):
        try:
            wid = subprocess.run(
                ["xdotool", "getactivewindow"],
                capture_output=True,
                text=True,
                timeout=2,
                check=False,
            ).stdout.strip()
            self._target_window = wid or None
        except Exception:
            self._target_window = None

    def _audio_cb(self, indata, frames, _time_info, status):
        if status:
            return
        self._q.put(indata.copy())

    def toggle_recording(self):
        with self._lock:
            if self.state == "thinking":
                return
            if self.state == "recording":
                self._recording = False
                self.state = "thinking"
                self.emit_feedback("stop")
                return
            self._recording = True
            self.state = "recording"
            self._frames = []
            self.save_active_window()
            self.emit_feedback("start")
            threading.Thread(target=self.record_loop, daemon=True).start()

    def start_recording(self):
        with self._lock:
            if self.state != "idle":
                return
            self._recording = True
            self.state = "recording"
            self._frames = []
            self.save_active_window()
            self.emit_feedback("start")
            threading.Thread(target=self.record_loop, daemon=True).start()

    def stop_to_thinking(self):
        with self._lock:
            if self.state != "recording":
                return
            self._recording = False
            self.state = "thinking"
            self.emit_feedback("stop")

    def record_loop(self):
        blocksize = max(1, int(self.sample_rate * self.chunk_ms / 1000))
        started = time.time()
        try:
            with sd.InputStream(
                samplerate=self.sample_rate,
                channels=1,
                dtype="int16",
                blocksize=blocksize,
                callback=self._audio_cb,
            ):
                while True:
                    if not self._recording:
                        break
                    if (time.time() - started) * 1000 > self.max_utterance_ms:
                        self._recording = False
                        if self.state == "recording":
                            self.state = "thinking"
                            self.emit_feedback("stop")
                        break
                    try:
                        chunk = self._q.get(timeout=0.1).reshape(-1)
                    except queue.Empty:
                        continue
                    self._frames.append(chunk)
        except Exception as e:
            print(f"audio error: {e}")
            notify(f"audio error: {e}")
            return
        self.finish_transcription()

    def ensure_model(self):
        if self._nano_model is not None:
            return

        try:
            import torch
            if self.torch_num_threads > 0:
                torch.set_num_threads(self.torch_num_threads)
                torch.set_num_interop_threads(max(1, min(4, self.torch_num_threads // 2)))
            if str(self.device).startswith("cuda") and not torch.cuda.is_available():
                print(
                    "cuda requested but torch has no CUDA runtime; fallback to cpu",
                    flush=True,
                )
                self.device = "cpu"
        except Exception:
            pass

        self._patch_whisper_asset_fallbacks()

        module = importlib.import_module("model")
        if not hasattr(module, "FunASRNano"):
            raise RuntimeError("FunASRNano class not found in downloaded model")

        model_source = self.resolve_model_source()
        buf_out = io.StringIO()
        buf_err = io.StringIO()
        last_err = None
        for attempt in range(2):
            try:
                with redirect_stdout(buf_out), redirect_stderr(buf_err):
                    model, kwargs = module.FunASRNano.from_pretrained(
                        model=model_source,
                        device=self.device,
                    )
                last_err = None
                break
            except Exception as e:
                last_err = e
                if attempt == 0 and "Unrecognized model in" in str(e):
                    print(
                        "model load failed with incomplete HF artifacts; retrying download once...",
                        flush=True,
                    )
                    self.ensure_local_model(model_source)
                    continue
                break

        if last_err is not None:
            captured = "\n".join(
                _filter_model_load_logs("\n".join([buf_out.getvalue(), buf_err.getvalue()]))
            )
            msg = f"from_pretrained failed: {last_err}"
            if captured:
                msg = f"{msg}\n{captured[-800:]}"
            raise RuntimeError(msg) from last_err

        for ln in _filter_model_load_logs("\n".join([buf_out.getvalue(), buf_err.getvalue()])):
            print(ln, flush=True)
        model.eval()
        self._nano_model = model
        self._nano_kwargs = kwargs

    def transcribe_with_funasr(self, wav_path):
        self.ensure_model()
        infer_kwargs = dict(self._nano_kwargs or {})
        if self.hotword_boost_enable and self.tech_words:
            infer_kwargs["hotword"] = " ".join(self.tech_words)
            if "hotword_weight" in infer_kwargs:
                infer_kwargs["hotword_weight"] = self.hotword_boost_weight
        if self.dtype and "dtype" in infer_kwargs:
            infer_kwargs["dtype"] = self.dtype
        infer_kwargs.setdefault("language", self.language)
        infer_kwargs.setdefault("itn", self.itn)

        try:
            res = self._nano_model.inference(data_in=[wav_path], **infer_kwargs)
        except Exception as e:
            raise RuntimeError(f"nano inference failed: {e}") from e

        text = extract_text_from_result(res)
        if not text:
            print(
                f"ASR empty result: type={type(res).__name__}, sample={str(res)[:280]}",
                flush=True,
            )
        return text

    def finish_transcription(self):
        if not self._frames:
            self.state = "idle"
            return
        # Hot-reload user-updated correction/lexicon files without restarting service.
        self.base_zh_rules = load_replacements_sources(self.base_zh_spec)
        self.base_en_rules = load_replacements_sources(self.base_en_spec)
        self.user_correction_rules = load_replacements_sources(self.user_corrections_spec)
        self.auto_correction_rules = load_replacements_sources(self.auto_rules_spec)
        self.tech_words = load_words_sources(self.tech_words_spec)

        audio_i16 = np.concatenate(self._frames).astype(np.int16)
        audio_f32 = (audio_i16.astype(np.float32) / 32768.0).reshape(-1, 1)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            wav_path = tmp.name
        try:
            sf.write(wav_path, audio_f32, self.sample_rate, subtype="PCM_16", format="WAV")
            raw_text = self.transcribe_with_funasr(wav_path)
            pre_text = post_process_text(raw_text, self.punctuation_policy)
            text = pre_text
            # Three-layer lexicon correction pipeline: base_zh -> base_en -> tech_en
            text = apply_replacements(text, self.base_zh_rules, ignore_case=False)
            text = apply_replacements(text, self.base_en_rules, ignore_case=True)
            text = apply_replacements(text, self.user_correction_rules, ignore_case=True)
            text = apply_replacements(text, self.auto_correction_rules, ignore_case=True)
            text = apply_tech_fuzzy(text, self.tech_words)
            learned = []
            if self.auto_learn_enable:
                learned = auto_learn_corrections(
                    pre_text,
                    text,
                    self.tech_words,
                    self.auto_learning_state_path,
                    self.auto_rules_write_path,
                    min_hits=self.learning_min_hits,
                )
            append_jsonl(
                self.history_path,
                {
                    "ts": datetime.now(timezone.utc).isoformat(),
                    "raw_text": raw_text,
                    "final_text": text.strip(),
                    "auto_learned": learned,
                },
            )
            if text:
                self.inject_text(text)
                self.emit_feedback("done")
            else:
                self.emit_feedback("done")
        except Exception as e:
            print(f"ASR error: {e}", flush=True)
            notify(f"ASR error: {e}")
        finally:
            self.state = "idle"
            try:
                os.remove(wav_path)
            except Exception:
                pass

    def inject_text(self, text):
        wid = self._target_window
        if not wid:
            return
        is_term = is_terminal_window(wid)
        is_kitty = is_kitty_window(wid)
        try:
            p1 = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE)
            p1.communicate(input=text.encode("utf-8"), timeout=2)
        except Exception:
            return
        try:
            subprocess.run(["xdotool", "windowfocus", wid], timeout=2, check=False)
            time.sleep(0.12)
            if is_term:
                term_paste_key = "ctrl+shift+v"
                subprocess.run(
                    ["xdotool", "key", "--window", wid, "--clearmodifiers", term_paste_key],
                    timeout=3,
                    check=False,
                )
                if is_kitty:
                    # Clear residual selection/preedit visual state without mode switch.
                    subprocess.run(
                        ["xdotool", "key", "--window", wid, "--clearmodifiers", "Left", "Right"],
                        timeout=3,
                        check=False,
                    )
            else:
                subprocess.run(
                    ["xdotool", "key", "--window", wid, "--clearmodifiers", "ctrl+v"],
                    timeout=3,
                    check=False,
                )
        except Exception:
            return


def main():
    install_runtime_log_filter()
    cfg = load_config()
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        App(cfg).run()
    except Exception as e:
        reason = str(e)
        print(f"startup failed: {reason}")
        if cfg.get("fallback", {}).get("auto_to_fw_streaming", True):
            fallback_to_fw_streaming(reason)
        sys.exit(1)


if __name__ == "__main__":
    main()
