#!/usr/bin/env python3
import argparse
import json
import os


def ensure_parent(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)


def load_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        return [ln.rstrip("\n") for ln in f]


def read_last_history_text(path):
    if not os.path.exists(path):
        return ""
    last = ""
    with open(path, "r", encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                obj = json.loads(ln)
            except json.JSONDecodeError:
                continue
            t = (obj.get("final_text") or "").strip()
            if t:
                last = t
    return last


def upsert_rule(path, wrong, right):
    ensure_parent(path)
    lines = load_lines(path)
    kept = []
    found = False
    for ln in lines:
        s = ln.strip()
        if not s or s.startswith("#") or "=>" not in s:
            kept.append(ln)
            continue
        left, _ = s.split("=>", 1)
        if left.strip().lower() == wrong.lower():
            kept.append(f"{wrong} => {right}")
            found = True
        else:
            kept.append(ln)
    if not found:
        if kept and kept[-1].strip():
            kept.append("")
        kept.append(f"{wrong} => {right}")
    with open(path, "w", encoding="utf-8") as f:
        if not kept:
            f.write("# User correction rules: wrong => right\n")
            f.write(f"{wrong} => {right}\n")
            return
        f.write("\n".join(kept) + "\n")


def main():
    p = argparse.ArgumentParser(description="Learn one correction rule for voice input.")
    p.add_argument("--wrong", default="", help="Wrong phrase")
    p.add_argument("--right", required=True, help="Correct phrase")
    p.add_argument(
        "--from-last",
        action="store_true",
        help="Use latest final_text from history as --wrong when --wrong is empty",
    )
    p.add_argument(
        "--rules",
        default=os.path.expanduser("~/.local/share/voice-input-funasr-nano/lexicons/user_corrections.rules"),
        help="Rules file path",
    )
    p.add_argument(
        "--history",
        default=os.path.expanduser("~/.local/state/voice-input-funasr-nano/history.jsonl"),
        help="History jsonl path",
    )
    args = p.parse_args()

    wrong = args.wrong.strip()
    if not wrong and args.from_last:
        wrong = read_last_history_text(os.path.expanduser(args.history)).strip()
    if not wrong:
        raise SystemExit("error: provide --wrong or use --from-last")
    right = args.right.strip()
    if not right:
        raise SystemExit("error: --right cannot be empty")

    rules_path = os.path.expanduser(args.rules)
    upsert_rule(rules_path, wrong, right)
    print(f"learned: {wrong} => {right}")
    print(f"rules: {rules_path}")


if __name__ == "__main__":
    main()
