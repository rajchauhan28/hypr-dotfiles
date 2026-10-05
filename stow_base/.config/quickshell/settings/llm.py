#!/usr/bin/env python3
"""Local LLM server control for the settings app's AI page.

    llm.py status                       -> one JSON object on stdout
    llm.py start <model> [--no-webui] [--thinking|--no-thinking]
                                        -> stops any llama-server, starts <model>, waits for /health
                                           (thinking defaults to the last choice)
    llm.py stop
    llm.py opencode on|off              -> offer opencode the running model only / hide them all

The model table below is the single source of truth for how each model is run.
Every flag in it was validated on this laptop (RTX 4050 6 GB, 15 GB RAM); see
the notes per model before changing one -- most "obvious" tweaks broke them.
Only one model fits the GPU at a time, so start always stops whatever runs.
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request

HOME = os.path.expanduser("~")
# Absolute, not PATH-relative: the settings app is launched from a Hyprland
# keybind, and Hyprland's environment has no ~/.local/bin, where the build lives.
LLAMA_SERVER = shutil.which("llama-server") or os.path.join(HOME, ".local", "bin", "llama-server")
LOG_DIR = os.path.join(HOME, ".cache", "llama-server")
STATE = os.path.join(HOME, ".local", "state", "llm-server.json")
OPENCODE = os.path.join(HOME, ".config", "opencode", "opencode.json")
E4B_DIR = os.path.join(HOME, "ddrive", "GenAI", "models")
BIG_DIR = os.path.join(HOME, "edrive", "models")
# Google's updated Gemma 4 template. The heretic GGUF embeds the April one,
# which llama.cpp flags as outdated (and patches around) and whose tool
# definitions are formatted the old way.
GEMMA4_TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gemma4-chat-template.jinja")

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
        "thinking": {"on": ["--reasoning", "on"], "off": ["--reasoning", "off"]},
    },
    "26b": {
        "label": "Gemma 4 26B heretic",
        "detail": "Uncensored MoE, 64K context, text only. ~20-29 tok/s, needs ~6 GB free RAM",
        "port": 8082,
        "provider": "llamacpp-26b",
        "model": os.path.join(BIG_DIR, "gemma-4-26B-A4B-it-ultra-uncensored-heretic.i1-IQ3_XXS.gguf"),
        # q8_0 KV (turbo4 V loops on long prompts), n-cpu-moe 22 + -ub 256 (20
        # OOMs mid-prompt), no MTP (slower on this MoE). 128K never fits.
        "args": ["-ngl", "99", "--n-cpu-moe", "22", "-fa", "on", "-c", "65536", "-ub", "256",
                 "-ctk", "q8_0", "-ctv", "q8_0", "-t", "6", "--cache-ram", "2048"],
        # Thinking off is the validated mode. On with the embedded template the
        # model sometimes garbles its own <|channel> marker (HTTP 500, or the
        # thought leaking into the answer), so thinking uses the official one.
        "thinking": {"on": ["--reasoning", "on", "--chat-template-file", GEMMA4_TEMPLATE],
                     "off": ["--reasoning", "off"]},
    },
    "ornith": {
        "label": "Ornith 1.0 9B",
        "detail": "Agentic coding model, 64K context, all on GPU. ~40 tok/s; thinks long, turn off for chat",
        "port": 8083,
        "provider": "llamacpp-ornith",
        "model": os.path.join(E4B_DIR, "Ornith-1.0-9B-UD-IQ3_XXS.gguf"),
        # 3-bit, because IQ4_XS only fits 32K on the GPU; 64K q8_0 leaves ~0.8 GB
        # for long-prompt buffers (a 55K prompt ran clean). Sampling per the model card.
        "args": ["-ngl", "99", "-fa", "on", "-c", "65536", "-ctk", "q8_0", "-ctv", "q8_0", "-t", "6",
                 "--temp", "0.6", "--top-p", "0.95", "--top-k", "20", "--cache-ram", "2048"],
        "thinking": {"on": ["--reasoning", "on"], "off": ["--reasoning", "off"]},
    },
    "ornith-heretic": {
        "label": "Ornith 1.5 9B heretic",
        "detail": "Uncensored agentic coder (0/100 refusals, KL 0.04), 64K, images. ~40 tok/s",
        "port": 8084,
        "provider": "llamacpp-ornith-heretic",
        "model": os.path.join(E4B_DIR, "Ornith-1.5-9B-heretic.i1-IQ3_XS.gguf"),
        # Same settings as Ornith 1.0: 64K q8_0 measured 5.4 GB VRAM, stable through a 55K prompt.
        # Vision runs on the CPU (the GPU has no room beside 64K); at the default token count it
        # misread small text ("H2O NaOH" for "INVOICE 7419"), at 512+ it reads it exactly.
        # 512-1024 tokens = ~10-25 s to encode an image, cached for follow-up turns.
        "args": ["-ngl", "99", "-fa", "on", "-c", "65536", "-ctk", "q8_0", "-ctv", "q8_0", "-t", "6",
                 "--temp", "0.6", "--top-p", "0.95", "--top-k", "20", "--cache-ram", "2048",
                 "--mmproj", os.path.join(E4B_DIR, "Ornith-1.5-9B-heretic.mmproj-Q8_0.gguf"),
                 "--no-mmproj-offload", "--image-min-tokens", "512", "--image-max-tokens", "1024"],
        "thinking": {"on": ["--reasoning", "on"], "off": ["--reasoning", "off"]},
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


def load_state():
    s = read_json(STATE, {})
    if "opencode" not in s:
        # Before the preference was stored, the toggle was read off opencode.json.
        disabled = read_json(OPENCODE, {}).get("disabled_providers", [])
        s["opencode"] = not all(m["provider"] in disabled for m in MODELS.values())
    s.setdefault("model", "e4b")
    s.setdefault("webui", True)
    s.setdefault("thinking", True)
    return s


def running_model():
    for pid in server_pids():
        path = arg_after(cmdline(pid), "-m")
        return next((k for k, m in MODELS.items() if m["model"] == path), None)
    return None


def offered_model(state):
    # The running model, else the one Start would launch. Offering any other
    # local provider would point opencode at a port nothing listens on.
    if not state["opencode"]:
        return None
    return running_model() or state["model"]


def sync_opencode(state):
    if not os.path.exists(OPENCODE):
        print(f"{OPENCODE} not found", file=sys.stderr)
        return False
    cfg = read_json(OPENCODE, None)
    if cfg is None:
        print(f"{OPENCODE} is not valid JSON; not touching it", file=sys.stderr)
        return False
    offered = offered_model(state)
    keep = MODELS[offered]["provider"] if offered in MODELS else None
    ours = [m["provider"] for m in MODELS.values()]
    old = cfg.get("disabled_providers", [])
    new = [p for p in old if p not in ours] + [p for p in ours if p != keep]
    if new == old:
        return True
    if new:
        cfg["disabled_providers"] = new
    else:
        cfg.pop("disabled_providers", None)
    write_json(OPENCODE, cfg)
    return True


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
            "thinking": arg_after(args, "--reasoning") != "off",
            "url": f"http://127.0.0.1:{port}",
            "healthy": healthy(port),
        }
        break
    used, total = vram() if running else (None, None)
    state = load_state()
    print(json.dumps({
        "running": running,
        "vramUsed": used,
        "vramTotal": total,
        "opencode": state["opencode"],
        "opencodeModel": offered_model(state),
        "last": {"model": state["model"], "webui": state["webui"], "thinking": state["thinking"]},
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


def start(key, webui, thinking=None):
    m = MODELS.get(key)
    if not m:
        print(f"unknown model {key!r}; known: {', '.join(MODELS)}", file=sys.stderr)
        return 2
    if not os.path.exists(m["model"]):
        print(f"model file missing: {m['model']}", file=sys.stderr)
        return 1
    if not os.access(LLAMA_SERVER, os.X_OK):
        print(f"llama-server not found (looked on PATH and at {LLAMA_SERVER})", file=sys.stderr)
        return 1
    if server_pids():
        stop()
    os.makedirs(LOG_DIR, exist_ok=True)
    log_path = os.path.join(LOG_DIR, f"{key}.log")
    state = load_state()
    if thinking is None:
        thinking = state["thinking"]
    cmd = [LLAMA_SERVER, "-m", m["model"], *m["args"], *m["thinking"]["on" if thinking else "off"],
           "--host", "127.0.0.1", "--port", str(m["port"])]
    if not webui:
        cmd.append("--no-webui")
    with open(log_path, "w") as log:
        # Own session: the settings window kills itself on close, and the
        # server must outlive it.
        proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=True)
    state.update(model=key, webui=webui, thinking=thinking)
    write_json(STATE, state)
    print(f"starting {m['label']} on :{m['port']}, thinking {'on' if thinking else 'off'} (log {log_path})", flush=True)
    if state["opencode"] and sync_opencode(state):
        print(f"opencode now offers {m['label']} (new sessions)", flush=True)
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
    state = load_state()
    state["opencode"] = on
    if not sync_opencode(state):
        return 1
    write_json(STATE, state)
    offered = offered_model(state)
    print(f"opencode offers {MODELS[offered]['label']} (new sessions)" if offered
          else "local models hidden from opencode")
    return 0


def main():
    a = sys.argv[1:]
    if a == ["status"]:
        return status()
    if a == ["stop"]:
        return stop()
    if len(a) >= 2 and a[0] == "start":
        flags = set(a[2:])
        if not flags - {"--no-webui", "--thinking", "--no-thinking"} and len(flags) == len(a) - 2 \
                and not {"--thinking", "--no-thinking"} <= flags:
            thinking = True if "--thinking" in flags else (False if "--no-thinking" in flags else None)
            return start(a[1], webui="--no-webui" not in flags, thinking=thinking)
    if len(a) == 2 and a[0] == "opencode" and a[1] in ("on", "off"):
        return set_opencode(a[1] == "on")
    print("usage: llm.py status | start <model> [--no-webui] [--thinking|--no-thinking] | stop | opencode on|off",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
