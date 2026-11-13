pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Screen recording: live while recording (pulsing dot | dock | elapsed time), expands into pause/stop
// controls, and posts a banner when the recording is saved.
Activity {
    id: root

    readonly property bool recording: Recorder.running
    // Recorder.running, but a stop only counts once it has lasted a moment. Starting a recording makes
    // Recorder.running blip off: the shell marks it running straight away, then its once-a-second
    // poll can run before the CLI has launched gpu-screen-recorder and flip it back off until the
    // next poll. Without this the wings would flicker and "Recording saved" would show on start.
    property bool active: recording
    property real startedAt: recording ? Date.now() : 0
    readonly property bool paused: Recorder.paused
    readonly property string elapsedStr: {
        const t = Math.max(0, Math.floor(Recorder.elapsed));
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const s = (t % 60).toString().padStart(2, "0");
        return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    // Keeps the recorder polling so recordings started from the CLI/keybinds show up
    property bool polling: false

    function updatePolling(): void {
        if (enabled === polling)
            return;
        Recorder.refCount += enabled ? 1 : -1;
        polling = enabled;
    }

    name: "recording"
    enabled: IslandConfig.recording.enabled
    priority: IslandConfig.recording.priority
    live: enabled && active

    leading: Component {
        Item {
            implicitWidth: root.island.compactSize
            implicitHeight: root.island.compactSize

            RecordDot {
                anchors.centerIn: parent
                size: Math.round(parent.width * 0.6)
            }
        }
    }

    // The elapsed time; the wing fits it (measured with the widest digit so it doesn't jitter) with the same
    // padding on the outer side as the dot has on its side: the dot's centre is half a row from the end
    trailingWidth: Math.ceil(timeMetrics.advanceWidth) + Math.round((island.rowH - island.compactSize * 0.6) / 2) * 2
    // Sized to the digits' ink rather than the font's line box (which has room for descenders digits
    // don't use), so the island centres the visible numbers
    trailing: Component {
        ClockText {
            text: root.elapsedStr
            font: Tokens.font.label.medium
            colour: root.paused ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        }
    }

    bubble: Component {
        Item {
            implicitWidth: root.island.compactSize
            implicitHeight: root.island.compactSize

            RecordDot {
                anchors.centerIn: parent
                size: Math.round(parent.width * 0.6)
            }
        }
    }

    // dot slot | Recording / elapsed | pause | stop slot
    expandedWidth: Math.min(300, island.width - island.margin * 2)
    expanded: Component {
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                IslandSlot {
                    size: root.island.bannerH

                    RecordDot {
                        anchors.centerIn: parent
                        size: Math.round(root.island.coverSize * 0.55)
                    }
                }

                InkText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: root.paused ? qsTr("Paused") : qsTr("Recording")
                    subtitle: root.elapsedStr
                }

                RoundButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: root.paused ? "play_arrow" : "pause"
                    onClicked: Recorder.togglePause()
                }

                IslandSlot {
                    size: root.island.bannerH

                    RoundButton {
                        anchors.centerIn: parent
                        icon: "stop"
                        danger: true
                        onClicked: Recorder.stop()
                    }
                }
            }
        }
    }

    onEnabledChanged: updatePolling()
    Component.onCompleted: updatePolling()
    Component.onDestruction: {
        if (polling)
            Recorder.refCount--;
    }

    onRecordingChanged: {
        if (recording) {
            stopConfirm.stop();
            if (!active)
                startedAt = Date.now();
            active = true;
        } else if (active) {
            // The blip only happens just after starting, and can last until the next poll (1s)
            stopConfirm.interval = Date.now() - startedAt < 2500 ? 1500 : 500;
            stopConfirm.restart();
        }
    }

    // How long a stop must last before it counts (and "Recording saved" shows)
    Timer {
        id: stopConfirm

        interval: 500
        onTriggered: {
            if (root.recording)
                return;
            root.active = false;
            if (root.enabled && IslandConfig.recording.savedBanner)
                root.post({
                    key: "recording-saved",
                    component: savedBanner,
                    duration: 4,
                    requeue: true
                });
        }
    }

    FontMetrics {
        id: timeFontMetrics

        font: Tokens.font.label.medium
    }

    // The font's digits aren't all the same width; size for the widest so the wing never has to grow
    readonly property string widestDigit: {
        let widest = "0";
        for (let d = 1; d <= 9; d++)
            if (timeFontMetrics.advanceWidth(`${d}`) > timeFontMetrics.advanceWidth(widest))
                widest = `${d}`;
        return widest;
    }

    TextMetrics {
        id: timeMetrics

        font: Tokens.font.label.medium
        text: root.elapsedStr.replace(/[0-9]/g, root.widestDigit)
    }

    Component {
        id: savedBanner

        // icon slot | Recording saved / Open folder | folder slot
        Item {
            readonly property real slot: root.island.bannerH

            implicitWidth: slot * 2 + Tokens.spacing.small * 2 + text.naturalWidth
            implicitHeight: slot

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: {
                    Quickshell.execDetached(["xdg-open", Paths.recsdir]);
                    root.dismiss("recording-saved");
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                IslandSlot {
                    size: root.island.bannerH

                    StyledRect {
                        anchors.centerIn: parent
                        implicitWidth: root.island.coverSize
                        implicitHeight: root.island.coverSize
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primaryContainer

                        IslandIcon {
                            anchors.fill: parent
                            text: "check"
                            fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }
                }

                InkText {
                    id: text

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: qsTr("Recording saved")
                    subtitle: qsTr("Click to open the folder")
                }

                IslandSlot {
                    size: root.island.bannerH

                    IslandIcon {
                        anchors.fill: parent
                        text: "folder_open"
                        fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.6)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }

    // Red recording dot; pulses while recording, turns into a still tertiary dot while paused
    component RecordDot: StyledRect {
        id: dot

        required property real size

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: root.paused ? Colours.palette.m3tertiary : Colours.palette.m3error

        SequentialAnimation on opacity {
            running: !root.paused && root.active
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                dot.opacity = 1

            NumberAnimation {
                to: 0.35
                duration: 700
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 700
                easing.type: Easing.InOutSine
            }
        }
    }

    component RoundButton: StyledRect {
        id: button

        property string icon
        property bool danger
        signal clicked

        implicitWidth: root.island.coverSize
        implicitHeight: root.island.coverSize
        radius: Tokens.rounding.full
        color: danger ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: button.danger ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
            onClicked: button.clicked()
        }

        IslandIcon {
            anchors.fill: parent
            text: button.icon
            fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
            color: button.danger ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
        }
    }
}
