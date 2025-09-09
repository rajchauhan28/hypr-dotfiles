#!/usr/bin/env python

import json
import sys
from gi.repository import GLib
from pydbus import SessionBus

class Kdeconnect:
    def __init__(self):
        self.bus = SessionBus()
        self.print_output()

    def print_output(self, text="", tooltip="KDE Connect", css_class="disconnected"):
        output = {"text": text, "tooltip": tooltip, "class": css_class}
        sys.stdout.write(json.dumps(output) + '\n')
        sys.stdout.flush()

    def get_devices(self):
        try:
            kdeconnect_proxy = self.bus.get("org.kde.kdeconnect", "/modules/kdeconnect")
            devices = kdeconnect_proxy.devices()
            return devices
        except Exception as e:
            return []

    def update(self):
        devices = self.get_devices()
        if not devices:
            self.print_output()
            return

        total_notif_count = 0
        all_devices_tooltip = ""
        media_info_text = ""
        media_class = ""
        battery_info_text = ""

        for device_id in devices:
            try:
                device_proxy = self.bus.get(f"org.kde.kdeconnect", f"/modules/kdeconnect/devices/{device_id}")
                device_name = device_proxy.name

                # Notifications
                notif_count = 0
                if hasattr(device_proxy, "notifications"):
                    # This is a guess, the API might be different
                    notif_count = len(device_proxy.notifications())
                total_notif_count += notif_count
                all_devices_tooltip += f"\nDevice: {device_name}"
                if notif_count > 0:
                    all_devices_tooltip += f"\nNotifications: {notif_count}"

                # Battery
                if hasattr(device_proxy, "battery"):
                    charge = device_proxy.charge
                    is_charging = device_proxy.isCharging
                    battery_info_text = f"{charge}%"
                    all_devices_tooltip += f"\nBattery: {charge}%"
                    if is_charging:
                        battery_info_text += " "
                        all_devices_tooltip += " (Charging)"
            except Exception as e:
                continue

        info_text = ""
        info_class = "connected"
        tooltip = "KDE Connect"

        if battery_info_text:
            info_text = battery_info_text
        if total_notif_count > 0:
            info_text = f" {total_notif_count}"
            info_class = "notifications"

        self.print_output(info_text, f"{tooltip}{all_devices_tooltip}", info_class)


if __name__ == "__main__":
    kdeconnect = Kdeconnect()
    main_loop = GLib.MainLoop()

    def update_loop():
        kdeconnect.update()
        return True

    GLib.timeout_add_seconds(5, update_loop)

    try:
        main_loop.run()
    except KeyboardInterrupt:
        pass
