#!/usr/bin/env python3
import subprocess, json

def get_audio_info():
    try:
        sinks_raw = subprocess.check_output(["pactl", "-f", "json", "list", "sinks"], stderr=subprocess.DEVNULL).decode("utf-8")
        sinks_json = json.loads(sinks_raw)
    except Exception:
        sinks_json = []

    try:
        sources_raw = subprocess.check_output(["pactl", "-f", "json", "list", "sources"], stderr=subprocess.DEVNULL).decode("utf-8")
        sources_json = json.loads(sources_raw)
    except Exception:
        sources_json = []

    try:
        default_sink_name = subprocess.check_output(["pactl", "get-default-sink"], stderr=subprocess.DEVNULL).decode("utf-8").strip()
    except Exception:
        default_sink_name = ""

    try:
        default_source_name = subprocess.check_output(["pactl", "get-default-source"], stderr=subprocess.DEVNULL).decode("utf-8").strip()
    except Exception:
        default_source_name = ""

    sinks = []
    for s in sinks_json:
        name = s.get("name", "")
        desc = s.get("description", name)
        is_active = (name == default_sink_name)
        sinks.append({"name": name, "description": desc, "active": is_active})

    sources = []
    for s in sources_json:
        name = s.get("name", "")
        if "monitor" in name:
            continue
        desc = s.get("description", name)
        is_active = (name == default_source_name)
        sources.append({"name": name, "description": desc, "active": is_active})

    active_sink_desc = next((s["description"] for s in sinks if s["active"]), "Default Audio Device")

    res = {
        "active_sink_description": active_sink_desc,
        "default_sink_name": default_sink_name,
        "sinks": sinks,
        "sources": sources
    }
    print(json.dumps(res))

if __name__ == "__main__":
    get_audio_info()
