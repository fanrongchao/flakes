#!/usr/bin/env python3
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

import numpy as np
import sounddevice as sd
import soundfile as sf
import yaml
from pynput import keyboard


def load_config():
    path = os.getenv("VOICE_INPUT_SHERPA_CONFIG", os.path.expanduser("~/.config/voice-input-sherpa-onnx/config.yaml"))
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def notify(msg):
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "Voice Input Sherpa", msg], check=False)


def fallback_to_fw_streaming(reason):
    notify(f"sherpa failed, fallback to fw-streaming: {reason}")
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


def is_terminal_window(window_id):
    terminals = {
        "kitty", "alacritty", "st", "xterm", "urxvt", "gnome-terminal-server",
        "konsole", "xfce4-terminal", "foot", "wezterm-gui", "terminator", "tilix",
    }
    try:
        out = subprocess.run(
            ["xprop", "-id", window_id, "WM_CLASS"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        ).stdout.lower()
        return any(t in out for t in terminals)
    except Exception:
        return False


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


class App:
    def __init__(self, cfg):
        self.cfg = cfg
        s = cfg["sherpa"]
        self.sample_rate = int(s.get("sample_rate", 16000))
        self.chunk_ms = int(s.get("chunk_ms", 320))
        self.max_utterance_ms = int(s.get("max_utterance_ms", 12000))
        self.punctuation_policy = s.get("punctuation_policy", "light-normalize")

        self.base_zh_spec = expand_pathspec(
            os.getenv("VOICE_INPUT_BASE_ZH_RULES", os.path.join("lexicons", "base_zh.rules"))
        )
        self.base_en_spec = expand_pathspec(
            os.getenv("VOICE_INPUT_BASE_EN_RULES", os.path.join("lexicons", "base_en.rules"))
        )
        self.user_corrections_spec = expand_pathspec(
            os.getenv(
                "VOICE_INPUT_USER_CORRECTIONS",
                "~/.local/share/voice-input-sherpa-onnx/lexicons/user_corrections.rules",
            )
        )
        self.auto_rules_spec = expand_pathspec(
            os.getenv(
                "VOICE_INPUT_AUTO_CORRECTIONS",
                "~/.local/state/voice-input-sherpa-onnx/auto_corrections.rules",
            )
        )
        self.auto_rules_write_path = os.path.expanduser(
            os.getenv(
                "VOICE_INPUT_AUTO_CORRECTIONS_WRITE",
                "~/.local/state/voice-input-sherpa-onnx/auto_corrections.rules",
            )
        )
        self.auto_learning_state_path = os.path.expanduser(
            os.getenv(
                "VOICE_INPUT_AUTO_LEARNING_STATE",
                "~/.local/state/voice-input-sherpa-onnx/auto_learning.json",
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
                "~/.local/state/voice-input-sherpa-onnx/history.jsonl",
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

        self._recording = False
        self._q = queue.Queue()
        self._frames = []
        self._target_window = None
        self._lock = threading.Lock()

        self.model_dir = os.getenv("SHERPA_ONNX_MODEL_DIR", "")
        self.bin_dir = os.getenv("SHERPA_ONNX_BIN_DIR", "")
        self.offline_bin = os.path.join(self.bin_dir, "sherpa-onnx")
        self.encoder = os.path.join(self.model_dir, "encoder.int8.onnx")
        self.decoder = os.path.join(self.model_dir, "decoder.int8.onnx")
        self.tokens = os.path.join(self.model_dir, "tokens.txt")

        for p in [self.offline_bin, self.encoder, self.decoder, self.tokens]:
            if not os.path.exists(p):
                raise RuntimeError(f"missing sherpa asset: {p}")

    def run(self):
        listener = keyboard.Listener(on_press=self.on_press, on_release=self.on_release)
        listener.start()
        print("voice-input-sherpa-onnx started")
        while True:
            time.sleep(1)

    def on_press(self, key):
        tok = norm_token(key)
        if not tok:
            return
        self.pressed.add(tok)
        active = self.required_keys.issubset(self.pressed)
        if active and not self.chord_active:
            self.chord_active = True
            self.toggle_recording()

    def on_release(self, key):
        tok = norm_token(key)
        if tok in self.pressed:
            self.pressed.remove(tok)
        if self.chord_active and not self.required_keys.issubset(self.pressed):
            self.chord_active = False

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
            if self._recording:
                self._recording = False
                notify("Thinking...")
                return
            self._recording = True
            self._frames = []
            self.save_active_window()
            notify("Recording... (press hotkey again to stop)")
            threading.Thread(target=self.record_loop, daemon=True).start()

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

    def transcribe_with_sherpa(self, wav_path):
        cmd = [
            self.offline_bin,
            f"--tokens={self.tokens}",
            f"--paraformer-encoder={self.encoder}",
            f"--paraformer-decoder={self.decoder}",
            "--num-threads=2",
            "--decoding-method=greedy_search",
            "--provider=cpu",
            wav_path,
        ]
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        out = "\n".join([r.stdout, r.stderr]).strip()
        if r.returncode != 0:
            raise RuntimeError(out[-300:] if out else f"exit {r.returncode}")

        # Prefer structured JSON output when available.
        json_seen = False
        json_text = ""
        for ln in out.splitlines():
            ln = ln.strip()
            if ln.startswith("{") and "\"text\"" in ln:
                try:
                    obj = json.loads(ln)
                    if isinstance(obj, dict):
                        json_seen = True
                        t = obj.get("text")
                        is_final = bool(obj.get("is_final", False))
                        if isinstance(t, str) and t.strip():
                            # Prefer final segment text when available.
                            if is_final:
                                json_text = t.strip()
                            elif not json_text:
                                json_text = t.strip()
                except Exception:
                    pass
        if json_seen:
            return json_text

        m = re.findall(r"Output text:\s*'([^']*)'", out)
        if m:
            return m[-1].strip()
        lines = [ln.strip() for ln in out.splitlines() if ln.strip()]
        lines = [ln for ln in lines if not (ln.startswith("{") and "\"text\"" in ln)]
        lines = [ln for ln in lines if not ln.startswith(("[I:", "[W:", "[E:", "LOG ", "Creating recognizer"))]
        return lines[-1] if lines else ""

    def finish_transcription(self):
        if not self._frames:
            notify("Done (no audio)")
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
            raw_text = self.transcribe_with_sherpa(wav_path)
            pre_text = post_process_text(raw_text, self.punctuation_policy)
            text = pre_text
            # Three-layer lexicon correction pipeline: base_zh -> base_en -> tech_en
            text = apply_replacements(text, self.base_zh_rules, ignore_case=False)
            text = apply_replacements(text, self.base_en_rules, ignore_case=True)
            text = apply_replacements(text, self.user_correction_rules, ignore_case=True)
            text = apply_replacements(text, self.auto_correction_rules, ignore_case=True)
            text = apply_tech_fuzzy(text, self.tech_words)
            learned = auto_learn_corrections(
                pre_text,
                text,
                self.tech_words,
                self.auto_learning_state_path,
                self.auto_rules_write_path,
                min_hits=2,
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
                notify("Done")
            else:
                notify("Done (empty)")
        except Exception as e:
            notify(f"ASR error: {e}")
        finally:
            try:
                os.remove(wav_path)
            except Exception:
                pass

    def inject_text(self, text):
        wid = self._target_window
        if not wid:
            return
        is_term = is_terminal_window(wid)
        try:
            p = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE)
            p.communicate(input=text.encode("utf-8"), timeout=2)
        except Exception:
            return
        try:
            subprocess.run(["xdotool", "windowfocus", wid], timeout=2, check=False)
            time.sleep(0.12)
            if is_term:
                subprocess.run(
                    ["xdotool", "key", "--window", wid, "--clearmodifiers", "ctrl+shift+v"],
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
