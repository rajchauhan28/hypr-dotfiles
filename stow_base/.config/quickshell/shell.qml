// Consolidated shell: one QML engine hosting every panel that used to be its
// own `qs -d -c <name>` process (topbar, leftbar, dock, sidepanel,
// notifications, desktop_clock).
//
// The lockscreen is deliberately NOT here — see lock/lock.sh. It stays a
// separate daemon so that reloading the bars cannot drop an active lock and a
// QML fault in a panel cannot take the lockscreen down while the session is
// locked.
//
// Imports are QUALIFIED on purpose: every panel directory carries its own
// `pragma Singleton` Theme.qml (and topbar/settings both define Card.qml), so
// an unqualified directory import would collide on those names. Each component
// still resolves Theme/Card from its own directory internally.
import Quickshell

import "topbar" as TopbarNS
import "leftbar" as LeftbarNS
import "dock" as DockNS
import "sidepanel" as SidepanelNS
import "notifications" as NotificationsNS
import "widgets/desktop_clock" as DesktopClockNS

ShellRoot {
    TopbarNS.TopbarPanel {}
    LeftbarNS.LeftbarPanel {}
    DockNS.DockPanel {}
    SidepanelNS.SidepanelPanel {}
    NotificationsNS.NotificationsPanel {}
    DesktopClockNS.DesktopClockPanel {}
}
