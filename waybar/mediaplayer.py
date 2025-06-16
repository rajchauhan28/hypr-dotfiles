#!/usr/bin/env python3
import json
import subprocess

player_icons = {
    "spotify": "",
    "firefox": "",
    "mpv": "🎞",
    "vlc": "🎬",
    "default": "🎜"
}

def get_player_metadata():
    try:
        player = subprocess.check_output(
            ["playerctl", "-l"], text=True
        ).strip().split("\n")[0]

        if not player:
            return None

        status = subprocess.check_output(
            ["playerctl", "-p", player, "status"], text=True
        ).strip()

        if status not in ["Playing", "Paused"]:
            return None

        artist = subprocess.check_output(
            ["playerctl", "-p", player, "metadata", "artist"], text=True
        ).strip()
        title = subprocess.check_output(
            ["playerctl", "-p", player, "metadata", "title"], text=True
        ).strip()

        icon = player_icons.get(player.lower(), player_icons["default"])
        text = f"{artist} - {title}"

        return {
            "text": text,
            "tooltip": f"{status} via {player}",
            "class": status.lower(),
            "alt": player.lower(),
            "icon": icon
        }

    except Exception:
        return None

def main():
    data = get_player_metadata()
    print(json.dumps(data if data else {"text": ""}))

if __name__ == "__main__":
    main()
