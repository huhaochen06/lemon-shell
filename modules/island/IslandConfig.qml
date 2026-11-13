pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Settings for the dynamic island, stored in ~/.config/caelestia/island.json. Kept on the QML side
// (FileView + JsonAdapter) so new options don't need the C++ config plugin to be rebuilt.
// Edited from Nexus > Panels > Dynamic island; changes are written back immediately.
Singleton {
    id: root

    // General
    property alias hoverExpand: adapter.hoverExpand
    property alias hoverDelay: adapter.hoverDelay
    property alias hideDockDuringActivity: adapter.hideDockDuringActivity
    property alias multiActivity: adapter.multiActivity
    // How long the quick activity banners (bluetooth, network, battery, toggles, keyboard) stay
    property alias quickDuration: adapter.quickDuration

    // Per activity. Priority decides which live activity gets the wings and which banner shows first
    // (higher wins; a higher priority banner interrupts a lower one).
    readonly property alias media: adapter.media
    readonly property alias recording: adapter.recording
    readonly property alias levels: adapter.levels
    readonly property alias notifications: adapter.notifications
    readonly property alias bluetooth: adapter.bluetooth
    readonly property alias network: adapter.network
    readonly property alias battery: adapter.battery
    readonly property alias toggles: adapter.toggles
    readonly property alias keyboard: adapter.keyboard
    readonly property alias timer: adapter.timer
    readonly property alias discord: adapter.discord
    readonly property alias transfer: adapter.transfer
    readonly property alias ipc: adapter.ipc
    readonly property alias screenshots: adapter.screenshots
    readonly property alias polkit: adapter.polkit
    readonly property alias downloads: adapter.downloads
    readonly property alias updates: adapter.updates

    FileView {
        path: `${Paths.config}/island.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property bool hoverExpand: true
            property int hoverDelay: 350
            property bool hideDockDuringActivity: true
            property bool multiActivity: true
            property real quickDuration: 3 // seconds

            property JsonObject media: JsonObject {
                property bool enabled: true
                property int priority: 40
                property bool trackBanner: true
                property real bannerDuration: 2.5 // seconds
                property real keepAfterPause: 1.5 // seconds
            }

            property JsonObject recording: JsonObject {
                property bool enabled: true
                property int priority: 80
                property bool savedBanner: true
            }

            property JsonObject levels: JsonObject {
                property bool enabled: true
                property int priority: 70
                property bool volume: true
                property bool brightness: true
                property bool microphone: false
                property real duration: 2 // seconds
            }

            property JsonObject notifications: JsonObject {
                property bool enabled: true
                property int priority: 60
                property bool replacePopups: true
                property bool showBody: true
                property real duration: 5 // seconds
                // Hovering a notification banner opens it up: the whole body and its actions
                property bool expandOnHover: true
            }

            property JsonObject bluetooth: JsonObject {
                property bool enabled: true
                property int priority: 50
                property bool disconnects: true
            }

            property JsonObject network: JsonObject {
                property bool enabled: true
                property int priority: 50
                property bool wifi: true
                property bool ethernet: true
                property bool vpn: true
            }

            property JsonObject battery: JsonObject {
                property bool enabled: true
                property int priority: 75
                property bool charging: true
                property bool lowWarnings: true
                property bool peripherals: true
                property int peripheralLevel: 15 // percent
            }

            property JsonObject toggles: JsonObject {
                property bool enabled: true
                property int priority: 55
                property bool doNotDisturb: true
                property bool gameMode: true
            }

            property JsonObject keyboard: JsonObject {
                property bool enabled: true
                property int priority: 55
            }

            property JsonObject timer: JsonObject {
                property bool enabled: true
                property int priority: 65
            }

            property JsonObject discord: JsonObject {
                property bool enabled: true
                property int priority: 70
            }

            property JsonObject transfer: JsonObject {
                property bool enabled: true
                property int priority: 60
                property bool finishedBanner: true
            }

            // Live activities and banners from scripts (qs ipc call island ..., scripts/island)
            property JsonObject ipc: JsonObject {
                property bool enabled: true
                property int priority: 45
                property real duration: 4 // seconds, for banners that don't set their own
            }

            // caelestia screenshot: replaces its "Screenshot taken / copied / saved" notifications
            property JsonObject screenshots: JsonObject {
                property bool enabled: true
                property int priority: 85
                property real duration: 6 // seconds
            }

            // Password prompts from polkit (pkexec, systemctl, ...), instead of the full screen dialog
            property JsonObject polkit: JsonObject {
                property bool enabled: true
            }

            // Browser downloads in progress (.part / .crdownload files in the downloads folder)
            property JsonObject downloads: JsonObject {
                property bool enabled: true
                property int priority: 50
                property bool finishedBanner: true
            }

            // Package updates (checkupdates, plus the AUR with paru / yay)
            property JsonObject updates: JsonObject {
                property bool enabled: true
                property int priority: 30
                property real interval: 3 // hours between checks
                property bool aur: true
                // Run in a terminal when the banner is clicked; empty picks paru, yay or pacman
                property string command: ""
            }
        }
    }
}
