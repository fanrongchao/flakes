#!/usr/bin/env python3
import os
import queue
import re
import shutil
import signal
import subprocess
import sys
import threading
import time

import numpy as np
import sounddevice as sd
import webrtcvad
import yaml
from faster_whisper import WhisperModel
from pynput import keyboard


def load_config():
    path = os.getenv("VOICE_INPUT_STREAMING_CONFIG", os.path.expanduser("~/.config/voice-input-streaming/config.yaml"))
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def notify(msg):
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "Voice Input Streaming", msg], check=False)


def fallback_to_whisper_writer(reason):
    notify(f"streaming failed, fallback to whisper-writer: {reason}")
    subprocess.run(["systemctl", "--user", "start", "whisper-writer.service"], check=False)


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


def post_process_text(text):
    text = text.strip()
    # Normalize punctuation for dictation: colon/semicolon are often over-produced.
    text = text.replace("：", "，").replace(":", "，")
    text = text.replace("；", "，").replace(";", "，")
    text = re.sub(r"[，,]{2,}", "，", text)
    text = re.sub(r"[。.!！？?]{2,}", lambda m: m.group(0)[0], text)
    text = re.sub(r"\s*[，]\s*", "，", text)
    text = re.sub(r"\s*[。！？!?]\s*", lambda m: m.group(0).strip(), text)
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
        s = cfg["streaming"]
        m = cfg["model"]
        self.sample_rate = int(s.get("sample_rate", 16000))
        self.chunk_ms = int(s.get("chunk_ms", 320))
        self.endpoint_ms = int(s.get("endpoint_ms", 260))
        self.max_utterance_ms = int(s.get("max_utterance_ms", 12000))
        self.language = m.get("language")
        self.initial_prompt = m.get("initial_prompt")
        self.temperature = float(m.get("temperature", 0.0))
        self.vad_filter = bool(m.get("vad_filter", True))

        self.model = WhisperModel(
            m["name"],
            device=m["device"],
            compute_type=m["compute_type"],
        )
        self.vad = webrtcvad.Vad(2)

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
        self._stream = None
        self._q = queue.Queue()
        self._frames = []
        self._last_speech_ts = 0.0
        self._target_window = None
        self._lock = threading.Lock()

    def run(self):
        listener = keyboard.Listener(on_press=self.on_press, on_release=self.on_release)
        listener.start()
        print("voice-input-fw-streaming started")
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

    def _chunk_has_speech(self, chunk):
        pcm = chunk.astype(np.int16).tobytes()
        frame_len = int(self.sample_rate * 0.03) * 2
        if len(pcm) < frame_len:
            return False
        for i in range(0, len(pcm) - frame_len + 1, frame_len):
            if self.vad.is_speech(pcm[i:i + frame_len], self.sample_rate):
                return True
        return False

    def toggle_recording(self):
        with self._lock:
            if self._recording:
                self._recording = False
                notify("Thinking...")
                return
            self._recording = True
            self._frames = []
            self._last_speech_ts = time.time()
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
                    if self._chunk_has_speech(chunk):
                        self._last_speech_ts = time.time()
                    elif (time.time() - self._last_speech_ts) * 1000 > self.endpoint_ms and len(self._frames) > 2:
                        self._recording = False
                        break
        except Exception as e:
            print(f"audio error: {e}")
            return
        self.finish_transcription()

    def finish_transcription(self):
        if not self._frames:
            notify("Done (no audio)")
            return
        audio = np.concatenate(self._frames).astype(np.float32) / 32768.0
        segments, _ = self.model.transcribe(
            audio=audio,
            language=self.language,
            initial_prompt=self.initial_prompt,
            condition_on_previous_text=False,
            temperature=self.temperature,
            vad_filter=self.vad_filter,
        )
        text = "".join(seg.text for seg in segments)
        text = post_process_text(text)
        if text:
            self.inject_text(text)
            notify("Done")
        else:
            notify("Done (empty)")

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
        if cfg.get("fallback", {}).get("auto_to_whisper_writer", True):
            fallback_to_whisper_writer(reason)
        sys.exit(1)


if __name__ == "__main__":
    main()
