#!/usr/bin/env python3
"""Local LLM server control for the settings app's AI page.

    llm.py status                       -> one JSON object on stdout
    llm.py start <model> [--no-webui]   -> stops any llama-server, starts <model>, waits for /health
    llm.py stop
    llm.py opencode on|off              -> offer / hide the local providers in opencode

The model table below is the single source of truth for how each model is run.
Every flag in it was validated on this laptop (RTX 4050 6 GB, 15 GB RAM); see
the notes per model before changing one -- most "obvious" tweaks broke them.
Only one model fits the GPU at a time, so start always stops whatever runs.
"""

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request

HOME = os.path.expanduser("~")
LOG_DIR = os.path.join(HOME, ".cache", "llama-server")
STATE = os.path.join(HOME, ".local", "state", "llm-server.json")
OPENCODE = os.path.join(HOME, ".config", "opencode", "opencode.json")
E4B_DIR = os.path.join(HOME, "ddrive", "GenAI", "models")
BIG_DIR = os.path.join(HOME, "edrive", "models")

MODELS = {
    "e4b": {
        "label": "Gemma 4 E4B",
        "detail": "QAT 4-bit, 128K context, images, MTP. ~90-110 tok/s",
        "port": 8081,
        "provider": "llamacpp-gemma",
        "model": os.path.join(E4B_DIR, "gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf"),
        # 128K only fits 6 GB with q8_0 K + turbo4 V and -ub 256.
        "args": ["--mmproj", os.path.join(E4B_DIR, "mmproj-BF16.gguf"),
                 "-ngl", "99", "-fa", "on", "--cache-ram", "2048",
                 "-c", "131072", "-ctk", "q8_0", "-ctv", "turbo4", "-ub", "256",
                 "--spec-type", "draft-mtp", "-md", os.path.join(E4B_DIR, "mtp-gemma-4-E4B-it.gguf"),
                 "-ngld", "99"],
    },
    "26b": {
        "label": "Gemma 4 26B heretic",
        "detail": "Uncensored MoE, 64K context, text only. ~20-29 tok/s, needs ~6 GB free RAM",
        "port": 8082,
        "provider": "llamacpp-26b",
        "model": os.path.join(BIG_DIR, "gemma-4-26B-A4B-it-ultra-uncensored-heretic.i1-IQ3_XXS.gguf"),
        # Thinking off (garbled <|channel> markers -> HTTP 500), q8_0 KV (turbo4 V
        # loops on long prompts), n-cpu-moe 22 + -ub 256 (20 OOMs mid-prompt),
        # no MTP (slower on this MoE). 128K never fits.
        "args": ["-ngl", "99", "--n-cpu-moe", "22", "-fa", "on", "-c", "65536", "-ub", "256",
                 "-ctk", "q8_0", "-ctv", "q8_0", "-t", "6", "--reasoning", "off", "--cache-ram", "2048"],
    },
}


def server_pids():
    out = subprocess.run(["pgrep", "-x", "llama-server"], capture_output=True, text=True).stdout
    return [int(p) for p in out.split()]


def cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
    except OSError:
        return []


def arg_after(args, flag):
    try:
        return args[args.index(flag) + 1]
    except (ValueError, IndexError):
        return None


def healthy(port):
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{port}/health", headers={"User-Agent": "llm.py"})
        with urllib.request.urlopen(req, timeout=1.5) as r:
            return r.status == 200
    except Exception:
        return False


def vram():
    # Only called while a server runs: polling NVML keeps the dGPU awake.
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,memory.total",
                              "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=5).stdout
        used, total = (int(x) for x in out.strip().splitlines()[0].split(","))
        return used, total
    except Exception:
        return None, None


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return default


def write_json(path, obj):
    # Same atomic swap as store.py: a reader sees the old file or the new one.
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".llm-")
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write("\n")
    if os.path.exists(path):
        os.chmod(tmp, os.stat(path).st_mode & 0o777)
    os.replace(tmp, path)


def opencode_enabled():
    disabled = read_json(OPENCODE, {}).get("disabled_providers", [])
    return all(m["provider"] not in disabled for m in MODELS.values())


def status():
    running = None
    for pid in server_pids():
        args = cmdline(pid)
        path = arg_after(args, "-m")
        key = next((k for k, m in MODELS.items() if m["model"] == path), None)
        port = int(arg_after(args, "--port") or 8080)
        running = {
            "pid": pid,
            "model": key,
            "label": MODELS[key]["label"] if key else os.path.basename(path or "unknown"),
            "port": port,
            "webui": "--no-webui" not in args,
            "url": f"http://127.0.0.1:{port}",
            "healthy": healthy(port),
        }
        break
    used, total = vram() if running else (None, None)
    print(json.dumps({
        "running": running,
        "vramUsed": used,
        "vramTotal": total,
        "opencode": opencode_enabled(),
        "last": read_json(STATE, {"model": "e4b", "webui": True}),
        "models": [{"key": k, "label": m["label"], "detail": m["detail"], "port": m["port"],
                    "present": os.path.exists(m["model"])} for k, m in MODELS.items()],
    }))
    return 0


def stop():
    pids = server_pids()
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.time() + 15
    while server_pids() and time.time() < deadline:
        time.sleep(0.3)
    for pid in server_pids():
        os.kill(pid, signal.SIGKILL)
    print("stopped" if pids else "nothing was running")
    return 0


def start(key, webui):
    m = MODELS.get(key)
    if not m:
        print(f"unknown model {key!r}; known: {', '.join(MODELS)}", file=sys.stderr)
        return 2
    if not os.path.exists(m["model"]):
        print(f"model file missing: {m['model']}", file=sys.stderr)
        return 1
    if server_pids():
        stop()
    os.makedirs(LOG_DIR, exist_ok=True)
    log_path = os.path.join(LOG_DIR, f"{key}.log")
    cmd = ["llama-server", "-m", m["model"], *m["args"], "--host", "127.0.0.1", "--port", str(m["port"])]
    if not webui:
        cmd.append("--no-webui")
    with open(log_path, "w") as log:
        # Own session: the settings window kills itself on close, and the
        # server must outlive it.
        proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=True)
    write_json(STATE, {"model": key, "webui": webui})
    print(f"starting {m['label']} on :{m['port']} (log {log_path})", flush=True)
    deadline = time.time() + 300
    while time.time() < deadline:
        if healthy(m["port"]):
            print(f"up on http://127.0.0.1:{m['port']}")
            return 0
        if proc.poll() is not None:
            print(f"llama-server exited with code {proc.returncode}; last log lines:", file=sys.stderr)
            with open(log_path, errors="replace") as f:
                for line in f.readlines()[-6:]:
                    print("  " + line.rstrip()[:200], file=sys.stderr)
            return 1
        time.sleep(1)
    print("timed out waiting for /health after 300 s", file=sys.stderr)
    return 1


def set_opencode(on):
    if not os.path.exists(OPENCODE):
        print(f"{OPENCODE} not found", file=sys.stderr)
        return 1
    cfg = read_json(OPENCODE, None)
    if cfg is None:
        print(f"{OPENCODE} is not valid JSON; not touching it", file=sys.stderr)
        return 1
    ours = [m["provider"] for m in MODELS.values()]
    disabled = [p for p in cfg.get("disabled_providers", []) if p not in ours]
    if not on:
        disabled += ours
    if disabled:
        cfg["disabled_providers"] = disabled
    else:
        cfg.pop("disabled_providers", None)
    write_json(OPENCODE, cfg)
    print("local models " + ("offered in" if on else "hidden from") + " opencode")
    return 0


def main():
    a = sys.argv[1:]
    if a == ["status"]:
        return status()
    if a == ["stop"]:
        return stop()
    if len(a) in (2, 3) and a[0] == "start" and (len(a) == 2 or a[2] == "--no-webui"):
        return start(a[1], webui=len(a) == 2)
    if len(a) == 2 and a[0] == "opencode" and a[1] in ("on", "off"):
        return set_opencode(a[1] == "on")
    print("usage: llm.py status | start <model> [--no-webui] | stop | opencode on|off", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
