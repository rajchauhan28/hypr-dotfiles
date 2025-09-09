#!/usr/bin/env python3
import subprocess

hindi_nums = {
    "1": "१", "2": "२", "3": "३", "4": "४", "5": "५",
    "6": "६", "7": "७", "8": "८", "9": "९", "10": "१०"
}

def get_workspaces():
    try:
        out = subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True)
    except Exception:
        return {"text": "—"}
    import json
    try:
        data = json.loads(out)
        active = [w for w in data if w.get("focused")]
        nums = [hindi_nums.get(str(w["id"]), str(w["id"])) for w in data]
        return {
            "text": " ".join(nums),
            "class": "workspace"
        }
    except Exception:
        return {"text": "?"}

if __name__ == "__main__":
    import json
    print(json.dumps(get_workspaces()))

