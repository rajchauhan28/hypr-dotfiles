#!/usr/bin/env python3
import sys, json, os

DATA_FILE = os.path.expanduser("~/.config/quickshell/widgets/clock/events.json")

def load_events():
    if not os.path.exists(DATA_FILE):
        return {}
    try:
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def save_events(data):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)

def main():
    if len(sys.argv) < 2:
        print(json.dumps(load_events()))
        return

    cmd = sys.argv[1]
    data = load_events()

    if cmd == "list":
        print(json.dumps(data))
    elif cmd == "add" and len(sys.argv) >= 4:
        date_key = sys.argv[2]
        note_text = sys.argv[3].strip()
        if note_text:
            if date_key not in data:
                data[date_key] = []
            data[date_key].append(note_text)
            save_events(data)
        print(json.dumps(data))
    elif cmd == "delete" and len(sys.argv) >= 4:
        date_key = sys.argv[2]
        try:
            idx = int(sys.argv[3])
            if date_key in data and 0 <= idx < len(data[date_key]):
                data[date_key].pop(idx)
                if not data[date_key]:
                    del data[date_key]
                save_events(data)
        except Exception:
            pass
        print(json.dumps(data))

if __name__ == "__main__":
    main()
