#!/usr/bin/env python3

import subprocess
import json
import os
import urllib.request

def get_metadata(field):
    try:
        return subprocess.check_output(["playerctl", "metadata", field]).decode().strip()
    except subprocess.CalledProcessError:
        return None

def get_player_name():
    try:
        players = subprocess.check_output(["playerctl", "-l"]).decode().splitlines()
        return players[0] if players else "media"
    except:
        return "media"

def download_art(art_url, save_path="/tmp/album_art.jpg"):
    try:
        # Spotify URLs are prefixed with "open.spotify.com", which needs to be stripped sometimes
        if art_url.startswith("https://") or art_url.startswith("http://"):
            urllib.request.urlretrieve(art_url, save_path)
            print("Downloaded the image")
            print("At :", save_path)
            return save_path
    except:
        pass
    return None

def main():
    title = get_metadata("title")
    artist = get_metadata("artist")
    album = get_metadata("album")
    art_url = get_metadata("mpris:artUrl")
    player = get_player_name().capitalize()

    if not title and not artist:
        subprocess.run(["notify-send", "⏸ Nothing Playing"])
        return

    art_path = download_art(art_url)

    body = f"{title or 'Unknown'}\n{artist or 'Unknown'}"
    if album:
        body += f"\n{album}"

    notify_cmd = [
        "notify-send",
        "-a", player,
        "-t", "5000",  # Show for 5 seconds
    ]

    if art_path and os.path.exists(art_path):
        notify_cmd += ["-i", art_path]
    else:
        notify_cmd += ["-i", "multimedia-player"]

    notify_cmd += [f"🎵 Now Playing", body]
    subprocess.run(notify_cmd)

if __name__ == "__main__":
    main()
