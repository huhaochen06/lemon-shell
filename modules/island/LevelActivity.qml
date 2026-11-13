pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Volume / microphone / brightness: posts a level banner (icon | bar | percentage) on changes. While it
// is enabled the island takes over the OSD's change popup (see ContentWindow).
Activity {
    id: root

    readonly property var monitor: Brightness.getMonitorForScreen(island.bar.screen)
    property string kind: "volume" // volume | mic | brightness
    // Audio and brightness report their initial values after startup; don't show those
    property bool armed: false

    readonly property real maxValue: kind === "brightness" ? 1 : GlobalConfig.services.maxVolume
    readonly property real value: kind === "brightness" ? (monitor?.brightness ?? 0) : kind === "mic" ? Audio.sourceVolume : Audio.volume
    readonly property bool muted: kind === "volume" ? Audio.muted : kind === "mic" ? Audio.sourceMuted : false
    readonly property string icon: {
        if (kind === "brightness")
            return `brightness_${Math.round(value * 6) + 1}`;
        if (kind === "mic")
            return Icons.getMicVolumeIcon(value, muted);
        return Icons.getVolumeIcon(value, muted);
    }

    function show(k: string): void {
        if (!armed || !enabled)
            return;
        kind = k;
        post({
            key: "level",
            component: levelBanner,
            duration: IslandConfig.levels.duration,
            // A level that couldn't show right away is stale; the OSD shows it instead
            queueable: false
        });
    }

    function set(fraction: real): void {
        const f = Math.max(0, Math.min(1, fraction));
        if (kind === "brightness")
            monitor?.setBrightness(f);
        else if (kind === "mic")
            Audio.setSourceVolume(f * maxValue);
        else
            Audio.setVolume(f * maxValue);
    }

    function step(up: bool): void {
        if (kind === "brightness") {
            if (monitor)
                monitor.setBrightness(monitor.brightness + (up ? 1 : -1) * GlobalConfig.services.brightnessIncrement);
        } else if (kind === "mic") {
            up ? Audio.incrementSourceVolume() : Audio.decrementSourceVolume();
        } else {
            up ? Audio.incrementVolume() : Audio.decrementVolume();
        }
    }

    // Icon tap: mute for audio (the tap is disabled for brightness)
    function toggle(): void {
        const node = kind === "mic" ? Audio.source : Audio.sink;
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    name: "levels"
    enabled: IslandConfig.levels.enabled
    priority: IslandConfig.levels.priority

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            if (IslandConfig.levels.volume)
                root.show("volume");
        }

        function onMutedChanged(): void {
            if (IslandConfig.levels.volume)
                root.show("volume");
        }

        function onSourceVolumeChanged(): void {
            if (IslandConfig.levels.microphone)
                root.show("mic");
        }

        function onSourceMutedChanged(): void {
            if (IslandConfig.levels.microphone)
                root.show("mic");
        }
    }

    Connections {
        target: root.monitor

        function onBrightnessChanged(): void {
            if (IslandConfig.levels.brightness)
                root.show("brightness");
        }
    }

    Component {
        id: levelBanner

        // icon slot | level bar | percentage slot
        Item {
            id: banner

            readonly property real fraction: Math.max(0, Math.min(1, root.value / Math.max(0.01, root.maxValue)))
            property real shownFraction: fraction

            implicitWidth: Math.min(300, root.island.width - root.island.margin * 2)
            implicitHeight: root.island.bannerH

            Behavior on shownFraction {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y !== 0)
                        root.step(event.angleDelta.y > 0);
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
                        color: root.muted ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3primaryContainer

                        IslandIcon {
                            anchors.fill: parent
                            text: root.icon
                            animate: true
                            fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                            color: root.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onPrimaryContainer
                        }

                        TapHandler {
                            enabled: root.kind !== "brightness"
                            cursorShape: Qt.PointingHandCursor
                            onTapped: root.toggle()
                        }
                    }
                }

                // Click or drag to set
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledRect {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 6
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

                        StyledRect {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            // Keep a dot at 0 so the bar never disappears
                            implicitWidth: Math.max(parent.height, parent.width * banner.shownFraction)
                            radius: Tokens.rounding.full
                            color: root.muted ? Colours.palette.m3outline : Colours.palette.m3primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onPressed: mouse => root.set(mouse.x / width)
                        onPositionChanged: mouse => {
                            if (pressed)
                                root.set(mouse.x / width);
                        }
                    }
                }

                IslandSlot {
                    size: root.island.bannerH

                    BlurText {
                        anchors.centerIn: parent
                        text: Math.round(root.value * 100)
                        font: Tokens.font.label.medium
                        color: root.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                    }
                }
            }
        }
    }
}
