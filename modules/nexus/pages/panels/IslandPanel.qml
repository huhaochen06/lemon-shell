pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.services
import qs.modules.nexus.common
import qs.modules.island

// Settings for the dynamic island (modules/island). Stored in ~/.config/caelestia/island.json via
// IslandConfig; changes apply immediately.
PageBase {
    id: root

    title: qsTr("Dynamic island")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General -------------------------------------------------------------------------------

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Expand on hover")
            subtext: qsTr("Hovering an activity's sides opens its expanded view (clicking always does)")
            checked: IslandConfig.hoverExpand
            onToggled: IslandConfig.hoverExpand = checked
        }

        StepperRow {
            label: qsTr("Hover delay (ms)")
            subtext: qsTr("How long to hover before the island expands")
            from: 0
            to: 2000
            stepSize: 50
            value: IslandConfig.hoverDelay
            onMoved: v => IslandConfig.hoverDelay = v
        }

        ToggleRow {
            text: qsTr("Hide app tiles during activities")
            subtext: qsTr("Hide the dock in compact live activities; hover the centre to reveal apps")
            checked: IslandConfig.hideDockDuringActivity
            onToggled: IslandConfig.hideDockDuringActivity = checked
        }

        StepperRow {
            label: qsTr("Quick banner duration (s)")
            subtext: qsTr("Bluetooth, network, battery, toggles and keyboard layout banners")
            from: 0.5
            to: 10
            stepSize: 0.5
            value: IslandConfig.quickDuration
            onMoved: v => IslandConfig.quickDuration = v
        }

        ToggleRow {
            last: true
            text: qsTr("Show more activities")
            subtext: qsTr("When several activities are live, show up to two more as bubbles on either side of the island. Tap one to swap")
            checked: IslandConfig.multiActivity
            onToggled: IslandConfig.multiActivity = checked
        }

        // Media ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Media")
        }

        ToggleRow {
            first: true
            text: qsTr("Show playing media")
            subtext: qsTr("Cover art and visualiser around the dock while something plays")
            checked: IslandConfig.media.enabled
            onToggled: IslandConfig.media.enabled = checked
        }

        ToggleRow {
            text: qsTr("Track change banner")
            subtext: qsTr("Briefly show the new title and artist when the track changes")
            disabled: !IslandConfig.media.enabled
            checked: IslandConfig.media.trackBanner
            onToggled: IslandConfig.media.trackBanner = checked
        }

        StepperRow {
            label: qsTr("Banner duration (s)")
            from: 0.5
            to: 10
            stepSize: 0.5
            value: IslandConfig.media.bannerDuration
            onMoved: v => IslandConfig.media.bannerDuration = v
        }

        StepperRow {
            label: qsTr("Keep after pausing (s)")
            subtext: qsTr("How long the media stays in the island after playback stops")
            from: 0
            to: 30
            stepSize: 0.5
            value: IslandConfig.media.keepAfterPause
            onMoved: v => IslandConfig.media.keepAfterPause = v
        }

        PriorityRow {
            last: true
            value: IslandConfig.media.priority
            onMoved: v => IslandConfig.media.priority = v
        }

        // Screen recording -----------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Screen recording")
        }

        ToggleRow {
            first: true
            text: qsTr("Show screen recordings")
            subtext: qsTr("Recording dot and elapsed time; hover for pause and stop")
            checked: IslandConfig.recording.enabled
            onToggled: IslandConfig.recording.enabled = checked
        }

        ToggleRow {
            text: qsTr("Saved banner")
            subtext: qsTr("Show a banner when a recording is saved. Click it to open the folder")
            disabled: !IslandConfig.recording.enabled
            checked: IslandConfig.recording.savedBanner
            onToggled: IslandConfig.recording.savedBanner = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.recording.priority
            onMoved: v => IslandConfig.recording.priority = v
        }

        // Volume & brightness ---------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Volume & brightness")
        }

        ToggleRow {
            first: true
            text: qsTr("Show level changes")
            subtext: qsTr("Replaces the on-screen display popup; hovering the screen edge still opens it")
            checked: IslandConfig.levels.enabled
            onToggled: IslandConfig.levels.enabled = checked
        }

        ToggleRow {
            text: qsTr("Volume")
            disabled: !IslandConfig.levels.enabled
            checked: IslandConfig.levels.volume
            onToggled: IslandConfig.levels.volume = checked
        }

        ToggleRow {
            text: qsTr("Brightness")
            disabled: !IslandConfig.levels.enabled
            checked: IslandConfig.levels.brightness
            onToggled: IslandConfig.levels.brightness = checked
        }

        ToggleRow {
            text: qsTr("Microphone")
            disabled: !IslandConfig.levels.enabled
            checked: IslandConfig.levels.microphone
            onToggled: IslandConfig.levels.microphone = checked
        }

        StepperRow {
            label: qsTr("Duration (s)")
            from: 0.5
            to: 10
            stepSize: 0.5
            value: IslandConfig.levels.duration
            onMoved: v => IslandConfig.levels.duration = v
        }

        PriorityRow {
            last: true
            value: IslandConfig.levels.priority
            onMoved: v => IslandConfig.levels.priority = v
        }

        // Notifications ---------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Notifications")
        }

        ToggleRow {
            first: true
            text: qsTr("Show notifications")
            subtext: qsTr("Do not disturb and an open sidebar hide them, like popups")
            checked: IslandConfig.notifications.enabled
            onToggled: IslandConfig.notifications.enabled = checked
        }

        ToggleRow {
            text: qsTr("Replace popups")
            subtext: qsTr("Show notifications only in the island, not also as a popup")
            disabled: !IslandConfig.notifications.enabled
            checked: IslandConfig.notifications.replacePopups
            onToggled: IslandConfig.notifications.replacePopups = checked
        }

        ToggleRow {
            text: qsTr("Show message text")
            subtext: qsTr("Otherwise only the title and app name are shown")
            disabled: !IslandConfig.notifications.enabled
            checked: IslandConfig.notifications.showBody
            onToggled: IslandConfig.notifications.showBody = checked
        }

        ToggleRow {
            text: qsTr("Open on hover")
            subtext: qsTr("Hovering a banner shows the whole message and its actions")
            disabled: !IslandConfig.notifications.enabled || !IslandConfig.notifications.showBody
            checked: IslandConfig.notifications.expandOnHover
            onToggled: IslandConfig.notifications.expandOnHover = checked
        }

        StepperRow {
            label: qsTr("Duration (s)")
            subtext: qsTr("Critical notifications stay twice as long")
            from: 1
            to: 30
            stepSize: 0.5
            value: IslandConfig.notifications.duration
            onMoved: v => IslandConfig.notifications.duration = v
        }

        PriorityRow {
            value: IslandConfig.notifications.priority
            onMoved: v => IslandConfig.notifications.priority = v
        }

        RowButton {
            last: true
            icon: "notifications"
            text: qsTr("Send a test notification")
            // Straight over D-Bus: notify-send isn't always installed (or working)
            onClicked: Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "Dynamic island", "0", "", qsTr("Test notification"), qsTr("This is what notifications look like in the island"), "[]", "{}", "5000"])
        }

        // Bluetooth -------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Bluetooth")
        }

        ToggleRow {
            first: true
            text: qsTr("Show device connections")
            subtext: qsTr("Device name and battery level when a device connects")
            checked: IslandConfig.bluetooth.enabled
            onToggled: IslandConfig.bluetooth.enabled = checked
        }

        ToggleRow {
            text: qsTr("Disconnections")
            disabled: !IslandConfig.bluetooth.enabled
            checked: IslandConfig.bluetooth.disconnects
            onToggled: IslandConfig.bluetooth.disconnects = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.bluetooth.priority
            onMoved: v => IslandConfig.bluetooth.priority = v
        }

        // Network ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Network")
        }

        ToggleRow {
            first: true
            text: qsTr("Show network changes")
            subtext: qsTr("Connecting and disconnecting, with the network name")
            checked: IslandConfig.network.enabled
            onToggled: IslandConfig.network.enabled = checked
        }

        ToggleRow {
            text: qsTr("Wi-Fi")
            disabled: !IslandConfig.network.enabled
            checked: IslandConfig.network.wifi
            onToggled: IslandConfig.network.wifi = checked
        }

        ToggleRow {
            text: qsTr("Ethernet")
            disabled: !IslandConfig.network.enabled
            checked: IslandConfig.network.ethernet
            onToggled: IslandConfig.network.ethernet = checked
        }

        ToggleRow {
            text: qsTr("VPN")
            subtext: qsTr("Replaces the VPN connected/disconnected toasts; errors still show as toasts")
            disabled: !IslandConfig.network.enabled
            checked: IslandConfig.network.vpn
            onToggled: IslandConfig.network.vpn = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.network.priority
            onMoved: v => IslandConfig.network.priority = v
        }

        // Battery ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Battery")
        }

        ToggleRow {
            first: true
            text: qsTr("Show battery events")
            checked: IslandConfig.battery.enabled
            onToggled: IslandConfig.battery.enabled = checked
        }

        ToggleRow {
            text: qsTr("Charger plugged in / unplugged")
            subtext: qsTr("Laptops only. Replaces the charging toasts")
            disabled: !IslandConfig.battery.enabled
            checked: IslandConfig.battery.charging
            onToggled: IslandConfig.battery.charging = checked
        }

        ToggleRow {
            text: qsTr("Low battery warnings")
            subtext: qsTr("Laptops only, at the shell's battery warning levels. Replaces those toasts")
            disabled: !IslandConfig.battery.enabled
            checked: IslandConfig.battery.lowWarnings
            onToggled: IslandConfig.battery.lowWarnings = checked
        }

        ToggleRow {
            text: qsTr("Peripheral low battery")
            subtext: qsTr("Mice, keyboards, headsets and other devices that report a battery")
            disabled: !IslandConfig.battery.enabled
            checked: IslandConfig.battery.peripherals
            onToggled: IslandConfig.battery.peripherals = checked
        }

        StepperRow {
            label: qsTr("Peripheral warning level (%)")
            from: 5
            to: 50
            stepSize: 5
            value: IslandConfig.battery.peripheralLevel
            onMoved: v => IslandConfig.battery.peripheralLevel = v
        }

        PriorityRow {
            last: true
            value: IslandConfig.battery.priority
            onMoved: v => IslandConfig.battery.priority = v
        }

        // Toggles ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Toggles")
        }

        ToggleRow {
            first: true
            text: qsTr("Show toggles")
            subtext: qsTr("Tap the switch on the banner to undo")
            checked: IslandConfig.toggles.enabled
            onToggled: IslandConfig.toggles.enabled = checked
        }

        ToggleRow {
            text: qsTr("Do not disturb")
            subtext: qsTr("Replaces the do not disturb toast")
            disabled: !IslandConfig.toggles.enabled
            checked: IslandConfig.toggles.doNotDisturb
            onToggled: IslandConfig.toggles.doNotDisturb = checked
        }

        ToggleRow {
            text: qsTr("Game mode")
            subtext: qsTr("Replaces the game mode toast")
            disabled: !IslandConfig.toggles.enabled
            checked: IslandConfig.toggles.gameMode
            onToggled: IslandConfig.toggles.gameMode = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.toggles.priority
            onMoved: v => IslandConfig.toggles.priority = v
        }

        // Keyboard --------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Keyboard layout")
        }

        ToggleRow {
            first: true
            text: qsTr("Show layout changes")
            subtext: qsTr("Replaces the keyboard layout toast")
            checked: IslandConfig.keyboard.enabled
            onToggled: IslandConfig.keyboard.enabled = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.keyboard.priority
            onMoved: v => IslandConfig.keyboard.priority = v
        }

        // Timer & stopwatch -----------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Timer & stopwatch")
        }

        ToggleRow {
            first: true
            text: qsTr("Show timers")
            subtext: qsTr("Start one from the launcher (%1timer 25m) or with \"qs -c caelestia ipc call timer start 25m\"").arg(GlobalConfig.launcher.actionPrefix)
            checked: IslandConfig.timer.enabled
            onToggled: IslandConfig.timer.enabled = checked
        }

        PriorityRow {
            value: IslandConfig.timer.priority
            onMoved: v => IslandConfig.timer.priority = v
        }

        RowButton {
            last: true
            icon: "timer"
            text: qsTr("Start a 1 minute test timer")
            onClicked: Timers.startTimer(60, qsTr("Test timer"))
        }

        // Discord ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Discord calls")
        }

        ToggleRow {
            first: true
            text: qsTr("Show voice calls")
            subtext: qsTr("Discord, Vesktop, WebCord, Legcord. Mute and deafen act on Discord's audio streams, so Discord's own buttons won't show them")
            checked: IslandConfig.discord.enabled
            onToggled: IslandConfig.discord.enabled = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.discord.priority
            onMoved: v => IslandConfig.discord.priority = v
        }

        // File transfers --------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("File transfers")
        }

        ToggleRow {
            first: true
            text: qsTr("Show Quick Share and AirDrop transfers")
            subtext: qsTr("Progress while sending or receiving; incoming requests get accept / decline here")
            checked: IslandConfig.transfer.enabled
            onToggled: IslandConfig.transfer.enabled = checked
        }

        ToggleRow {
            text: qsTr("Finished banner")
            disabled: !IslandConfig.transfer.enabled
            checked: IslandConfig.transfer.finishedBanner
            onToggled: IslandConfig.transfer.finishedBanner = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.transfer.priority
            onMoved: v => IslandConfig.transfer.priority = v
        }

        // Scripts ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Scripts")
        }

        ToggleRow {
            first: true
            text: qsTr("Show activities from scripts")
            subtext: qsTr("\"island run -- cargo build\", \"island notify Title Text\" (scripts/island), or \"qs -c caelestia ipc call island ...\"")
            checked: IslandConfig.ipc.enabled
            onToggled: IslandConfig.ipc.enabled = checked
        }

        StepperRow {
            label: qsTr("Banner duration (s)")
            subtext: qsTr("For banners that don't set their own")
            from: 1
            to: 15
            stepSize: 0.5
            value: IslandConfig.ipc.duration
            onMoved: v => IslandConfig.ipc.duration = v
        }

        PriorityRow {
            value: IslandConfig.ipc.priority
            onMoved: v => IslandConfig.ipc.priority = v
        }

        RowButton {
            last: true
            icon: "terminal"
            text: qsTr("Run a 10 second test task")
            onClicked: Quickshell.execDetached([`${Quickshell.shellDir}/scripts/island`, "run", "--title", qsTr("Test task"), "--", "sleep", "10"])
        }

        // Screenshots -----------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Screenshots")
        }

        ToggleRow {
            first: true
            text: qsTr("Show screenshots")
            subtext: qsTr("A thumbnail with edit and save instead of the notification; hover it for a preview")
            checked: IslandConfig.screenshots.enabled
            onToggled: IslandConfig.screenshots.enabled = checked
        }

        StepperRow {
            label: qsTr("Duration (s)")
            from: 2
            to: 20
            stepSize: 1
            value: IslandConfig.screenshots.duration
            onMoved: v => IslandConfig.screenshots.duration = v
        }

        PriorityRow {
            value: IslandConfig.screenshots.priority
            onMoved: v => IslandConfig.screenshots.priority = v
        }

        RowButton {
            last: true
            icon: "screenshot_monitor"
            text: qsTr("Take a screenshot")
            onClicked: Quickshell.execDetached(["caelestia", "screenshot"])
        }

        // Authentication --------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Authentication")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Ask for passwords in the island")
            subtext: qsTr("Polkit prompts (pkexec, systemctl, ...) instead of the full screen dialog, which still shows over fullscreen apps")
            checked: IslandConfig.polkit.enabled
            onToggled: IslandConfig.polkit.enabled = checked
        }

        // Downloads -------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Downloads")
        }

        ToggleRow {
            first: true
            text: qsTr("Show downloads")
            subtext: qsTr("Browser downloads (.part, .crdownload) in your downloads folder")
            checked: IslandConfig.downloads.enabled
            onToggled: IslandConfig.downloads.enabled = checked
        }

        ToggleRow {
            text: qsTr("Finished banner")
            disabled: !IslandConfig.downloads.enabled
            checked: IslandConfig.downloads.finishedBanner
            onToggled: IslandConfig.downloads.finishedBanner = checked
        }

        PriorityRow {
            last: true
            value: IslandConfig.downloads.priority
            onMoved: v => IslandConfig.downloads.priority = v
        }

        // Updates ---------------------------------------------------------------------------------

        SectionHeader {
            text: qsTr("Package updates")
        }

        ToggleRow {
            first: true
            text: qsTr("Check for updates")
            subtext: qsTr("A banner when new updates show up; click it to update in a terminal")
            checked: IslandConfig.updates.enabled
            onToggled: IslandConfig.updates.enabled = checked
        }

        ToggleRow {
            text: qsTr("Include the AUR")
            subtext: UpdateChecker.aurHelper ? qsTr("With %1").arg(UpdateChecker.aurHelper) : qsTr("Needs paru or yay")
            disabled: !IslandConfig.updates.enabled
            checked: IslandConfig.updates.aur
            onToggled: IslandConfig.updates.aur = checked
        }

        StepperRow {
            label: qsTr("Check every (hours)")
            from: 0.5
            to: 24
            stepSize: 0.5
            value: IslandConfig.updates.interval
            onMoved: v => IslandConfig.updates.interval = v
        }

        PriorityRow {
            value: IslandConfig.updates.priority
            onMoved: v => IslandConfig.updates.priority = v
        }

        RowButton {
            last: true
            icon: "refresh"
            text: UpdateChecker.checking ? qsTr("Checking...") : qsTr("Check now")
            subtext: UpdateChecker.lastCheck > 0 ? qsTr("%n update(s) at the last check", "", UpdateChecker.count) : ""
            disabled: !IslandConfig.updates.enabled || UpdateChecker.checking
            onClicked: UpdateChecker.check()
        }
    }

    // Higher priority activities take the island first, and their banners interrupt lower ones
    component PriorityRow: StepperRow {
        label: qsTr("Priority")
        subtext: qsTr("Higher wins when several activities want the island")
        from: 0
        to: 100
        stepSize: 5
    }
}
