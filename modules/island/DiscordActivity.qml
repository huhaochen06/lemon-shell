pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Discord call: live while Discord (or Vesktop, WebCord, Legcord...) is in a voice call
// (app icon | dock | call time), expands into mute / deafen controls.
//
// Discord doesn't tell other apps about calls without an approved OAuth app, so the call is detected
// through PipeWire instead: while in a voice channel Discord keeps a microphone capture stream open.
// Mute and deafen act on Discord's PipeWire streams (its microphone input and its audio output), so
// they work even though Discord's own buttons won't show them.
Activity {
    id: root

    readonly property list<string> clients: ["discord", "vesktop", "webcord", "legcord", "armcord", "equibop", "dorion"]

    function isDiscord(node: PwNode): bool {
        const p = node.properties ?? {};
        const names = [p["application.name"], p["application.process.binary"], p["application.id"], node.name].filter(n => n).map(n => n.toString().toLowerCase());
        return names.some(n => clients.some(c => n.includes(c)));
    }

    readonly property var discordStreams: Audio.streams.filter(s => isDiscord(s))
    // Capture streams (Discord recording the mic) mean a call; playback streams are what you hear
    readonly property var micStreams: discordStreams.filter(s => !s.isSink)
    readonly property var outputStreams: discordStreams.filter(s => s.isSink)
    readonly property bool inCall: micStreams.length > 0
    readonly property bool muted: inCall && micStreams.every(s => s.audio?.muted)
    readonly property bool deafened: outputStreams.length > 0 && outputStreams.every(s => s.audio?.muted)

    // Debounced so a mic test or a brief reconnect doesn't flash the activity
    property bool callActive: false
    property real callStart: 0
    property real now: Date.now()
    readonly property string timeStr: {
        const t = Math.max(0, Math.floor((now - callStart) / 1000));
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const s = (t % 60).toString().padStart(2, "0");
        return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    readonly property string appIcon: {
        const p = micStreams[0]?.properties ?? {};
        const name = (p["application.icon_name"] || p["application.process.binary"] || "discord").toString().toLowerCase();
        return Quickshell.iconPath(name, "discord");
    }

    function setMuted(m: bool): void {
        for (const s of micStreams)
            Audio.setStreamMuted(s, m);
    }

    function setDeafened(d: bool): void {
        for (const s of outputStreams)
            Audio.setStreamMuted(s, d);
        // Deafening mutes you too, like Discord does
        if (d)
            setMuted(true);
    }

    function focusDiscord(): void {
        const toplevel = Hyprland.toplevels.values.find(t => {
            const cls = (t.lastIpcObject?.class ?? "").toLowerCase();
            return clients.some(c => cls.includes(c));
        });
        if (toplevel)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${toplevel.address}" })` : `focuswindow address:0x${toplevel.address}`);
    }

    name: "discord"
    enabled: IslandConfig.discord.enabled
    priority: IslandConfig.discord.priority
    live: enabled && callActive

    onInCallChanged: {
        if (inCall)
            startDelay.restart();
        else
            endDelay.restart();
    }

    Timer {
        id: startDelay

        interval: 1500
        onTriggered: {
            if (!root.inCall || root.callActive)
                return;
            root.callStart = Date.now();
            root.now = root.callStart;
            root.callActive = true;
        }
    }

    Timer {
        id: endDelay

        interval: 2000
        onTriggered: {
            if (!root.inCall)
                root.callActive = false;
        }
    }

    Timer {
        running: root.callActive
        repeat: true
        interval: 1000
        onTriggered: root.now = Date.now()
    }

    leading: Component {
        AppIcon {
            size: root.island.compactSize
        }
    }

    trailingWidth: clockMetrics.implicitWidth + Math.round((island.rowH - island.compactSize * 0.6) / 2) * 2
    trailing: Component {
        ClockText {
            text: root.timeStr
            colour: root.muted ? Colours.palette.m3error : Colours.palette.m3onSurface
        }
    }

    // app icon | Discord call / time | mute | deafen | open slot
    expandedWidth: Math.min(330, island.width - island.margin * 2)
    expanded: Component {
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                IslandSlot {
                    size: root.island.bannerH

                    AppIcon {
                        anchors.centerIn: parent
                        size: root.island.coverSize
                    }
                }

                InkText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: qsTr("Voice call")
                    subtitle: root.deafened ? qsTr("%1 · deafened").arg(root.timeStr) : root.muted ? qsTr("%1 · muted").arg(root.timeStr) : root.timeStr
                }

                IslandButton {
                    Layout.alignment: Qt.AlignVCenter
                    island: root.island
                    icon: root.muted ? "mic_off" : "mic"
                    variant: root.muted ? "danger" : "secondary"
                    onClicked: root.setMuted(!root.muted)
                }

                IslandButton {
                    Layout.alignment: Qt.AlignVCenter
                    island: root.island
                    icon: root.deafened ? "headset_off" : "headset"
                    variant: root.deafened ? "danger" : "secondary"
                    onClicked: root.setDeafened(!root.deafened)
                }

                IslandSlot {
                    size: root.island.bannerH

                    IslandButton {
                        anchors.centerIn: parent
                        island: root.island
                        icon: "open_in_new"
                        variant: "plain"
                        onClicked: root.focusDiscord()
                    }
                }
            }
        }
    }

    ClockText {
        id: clockMetrics

        visible: false
        text: root.timeStr
    }

    // The app's icon, with a red mic-off badge while muted
    component AppIcon: Item {
        id: icon

        required property real size

        implicitWidth: size
        implicitHeight: size

        IconImage {
            anchors.fill: parent
            source: root.appIcon
            asynchronous: true
        }

        StyledRect {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -1
            visible: root.muted
            implicitWidth: Math.round(icon.size * 0.5)
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: Colours.palette.m3error

            IslandIcon {
                anchors.fill: parent
                text: "mic_off"
                fontStyle: Tokens.font.icon.size(Math.max(1, Math.round(icon.size * 0.35))).build()
                color: Colours.palette.m3onError
            }
        }
    }
}
