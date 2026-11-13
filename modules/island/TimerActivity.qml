pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Timer / stopwatch (services/Timers.qml): live while one runs (countdown ring | dock | time), expands
// into pause / +1 min / stop controls, and posts a banner when the timer is done. Start one from the
// launcher (">timer 25m") or IPC ("qs -c caelestia ipc call timer start 25m").
Activity {
    id: root

    readonly property bool isTimer: Timers.mode === "timer"
    readonly property string title: Timers.label || (isTimer ? qsTr("Timer") : qsTr("Stopwatch"))
    readonly property color accent: Timers.paused ? Colours.palette.m3outline : Colours.palette.m3tertiary

    name: "timer"
    enabled: IslandConfig.timer.enabled
    priority: IslandConfig.timer.priority
    live: enabled && Timers.running

    leading: Component {
        Indicator {
            size: root.island.compactSize
            strokeWidth: 2
            iconScale: 0.6
        }
    }

    // Fits the time with the same padding on the outer side as the indicator has on its side
    trailingWidth: clockMetrics.implicitWidth + Math.round((island.rowH - island.compactSize * 0.6) / 2) * 2
    trailing: Component {
        ClockText {
            text: Timers.timeStr
            colour: Timers.paused ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        }
    }

    // indicator slot | time / title | pause | (+1 min) | stop slot
    expandedWidth: Math.min(isTimer ? 320 : 280, island.width - island.margin * 2)
    expanded: Component {
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                IslandSlot {
                    size: root.island.bannerH

                    Indicator {
                        anchors.centerIn: parent
                        size: root.island.coverSize
                        strokeWidth: 3
                        iconScale: 0.5
                    }
                }

                InkText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: Timers.timeStr
                    subtitle: Timers.paused ? qsTr("%1 · paused").arg(root.title) : root.title
                }

                IslandButton {
                    Layout.alignment: Qt.AlignVCenter
                    island: root.island
                    icon: Timers.paused ? "play_arrow" : "pause"
                    onClicked: Timers.togglePause()
                }

                IslandButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.isTimer
                    island: root.island
                    icon: "more_time"
                    onClicked: Timers.addSeconds(60)
                }

                IslandSlot {
                    size: root.island.bannerH

                    IslandButton {
                        anchors.centerIn: parent
                        island: root.island
                        icon: "stop"
                        variant: "danger"
                        onClicked: Timers.stop()
                    }
                }
            }
        }
    }

    // Measures the time for the trailing wing's width
    ClockText {
        id: clockMetrics

        visible: false
        text: Timers.timeStr
    }

    Connections {
        target: Timers

        function onFinished(label: string, duration: real): void {
            const seconds = Math.round(duration / 1000);
            root.post({
                key: "timer-done",
                component: doneBanner,
                data: {
                    label: label,
                    seconds: seconds
                },
                priority: root.priority + 20,
                duration: 10,
                requeue: true
            });
        }
    }

    // Timer: a ring that empties; stopwatch: a stopwatch icon
    component Indicator: Item {
        id: indicator

        required property real size
        required property real strokeWidth
        required property real iconScale

        implicitWidth: size
        implicitHeight: size

        CircularProgress {
            anchors.fill: parent
            visible: root.isTimer
            implicitSize: indicator.size
            value: Timers.progress
            strokeWidth: indicator.strokeWidth
            padding: 0
            fgColour: root.accent
            bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.12)
        }

        IslandIcon {
            anchors.fill: parent
            text: Timers.paused ? "pause" : root.isTimer ? "timer" : "timer_play"
            fontStyle: Tokens.font.icon.size(Math.max(1, Math.round(indicator.size * indicator.iconScale))).build()
            color: root.accent
        }
    }

    Component {
        id: doneBanner

        // alarm | label / length | restart slot
        IconBanner {
            id: done

            // Set by the island
            property var banner
            readonly property var d: banner?.data ?? ({})

            island: root.island
            icon: "alarm"
            circleColour: Colours.palette.m3tertiaryContainer
            iconColour: Colours.palette.m3onTertiaryContainer
            title: d.label || qsTr("Timer done")
            subtitle: qsTr("%1 timer").arg(Timers.describe(d.seconds ?? 0))
            trailingIcon: "replay"
            trailingColour: Colours.palette.m3tertiary
            trailingClickable: true

            onClicked: {
                if (done.banner)
                    root.dismiss(done.banner.key);
            }
            onTrailingClicked: {
                Timers.startTimer(d.seconds, d.label);
                if (done.banner)
                    root.dismiss(done.banner.key);
            }
        }
    }
}
