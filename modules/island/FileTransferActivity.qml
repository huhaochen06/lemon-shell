pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// File transfer (Quick Share or AirDrop, through Sharing): live while a file is sent or received (direction | dock | progress ring),
// expands into the file, device and progress. Incoming requests get a banner with accept / decline
// (instead of the notification), and a banner shows when a transfer finishes.
// Incoming transfers don't report progress, so they show a spinner instead of a ring.
Activity {
    id: root

    readonly property var transfer: Sharing.transfer
    readonly property bool sending: transfer?.direction === "send"
    readonly property real progress: transfer && transfer.sent >= 0 && transfer.total > 0 ? transfer.sent / transfer.total : -1

    function size(bytes: real): string {
        if (!(bytes > 0))
            return "";
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${bytes.toFixed(bytes >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
    }

    name: "transfer"
    enabled: IslandConfig.transfer.enabled
    priority: IslandConfig.transfer.priority
    live: enabled && transfer !== null

    leading: Component {
        Item {
            implicitWidth: root.island.compactSize
            implicitHeight: root.island.compactSize

            IslandIcon {
                anchors.fill: parent
                text: root.sending ? "upload" : "download"
                fontStyle: Tokens.font.icon.size(Math.round(root.island.compactSize * 0.8)).build()
                color: Colours.palette.m3primary
            }
        }
    }

    trailing: Component {
        Progress {
            size: root.island.compactSize
            strokeWidth: 2
        }
    }

    // direction | file / device · progress | progress ring slot
    expandedWidth: Math.min(340, island.width - island.margin * 2)
    expanded: Component {
        Item {
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
                            text: root.sending ? "upload" : "download"
                            fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }
                }

                InkText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: root.transfer?.fileName || qsTr("File")
                    subtitle: {
                        const device = root.transfer?.deviceName ?? "";
                        const what = root.sending ? qsTr("To %1").arg(device) : qsTr("From %1").arg(device);
                        if (root.progress >= 0)
                            return `${what} · ${root.size(root.transfer.sent)} / ${root.size(root.transfer.total)}`;
                        const total = root.size(root.transfer?.total ?? 0);
                        return total ? `${what} · ${total}` : what;
                    }
                }

                IslandSlot {
                    size: root.island.bannerH

                    Progress {
                        anchors.centerIn: parent
                        size: root.island.coverSize
                        strokeWidth: 3
                    }

                    BlurText {
                        anchors.centerIn: parent
                        visible: root.progress >= 0
                        text: Math.round(root.progress * 100)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }

    Connections {
        target: Sharing

        function onTransferRequested(deviceName: string, fileName: string, fileSize: real): void {
            if (!root.enabled || !root.island.isFocusScreen)
                return;
            root.post({
                key: "transfer-request",
                component: requestBanner,
                data: {
                    deviceName: deviceName,
                    fileName: fileName,
                    fileSize: fileSize
                },
                priority: root.priority + 20,
                duration: 60,
                requeue: true
            });
        }

        function onTransferEnded(info: var, success: bool): void {
            root.dismiss("transfer-request");
            if (!root.enabled || !IslandConfig.transfer.finishedBanner || !root.island.isFocusScreen)
                return;
            const sent = info.direction === "send";
            root.quick("transfer-done", {
                icon: success ? "check" : "error",
                circleColour: success ? Colours.palette.m3primaryContainer : Colours.palette.m3errorContainer,
                iconColour: success ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onErrorContainer,
                title: success ? (sent ? qsTr("Sent %1").arg(info.fileName) : qsTr("Received %1").arg(info.fileName)) : qsTr("Transfer failed"),
                subtitle: success ? (sent ? qsTr("To %1").arg(info.deviceName) : qsTr("Saved to Downloads · click to open")) : info.fileName,
                trailingIcon: !success ? "" : sent ? "upload" : "folder_open",
                onClick: success && !sent && info.filePath ? () => Quickshell.execDetached(["xdg-open", info.filePath.substring(0, info.filePath.lastIndexOf("/"))]) : undefined
            }, {
                duration: IslandConfig.quickDuration * 1.5
            });
        }
    }

    // A ring for sends (which report progress), a spinner for receives (which don't)
    component Progress: Item {
        id: prog

        required property real size
        required property real strokeWidth

        implicitWidth: size
        implicitHeight: size

        CircularProgress {
            anchors.fill: parent
            visible: root.progress >= 0
            implicitSize: prog.size
            value: Math.max(0, root.progress)
            strokeWidth: prog.strokeWidth
            padding: 0
            bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.12)
        }

        CircularIndicator {
            anchors.fill: parent
            visible: root.progress < 0
            implicitSize: prog.size
            strokeWidth: prog.strokeWidth
            running: visible
            bgColour: "transparent"
        }
    }

    Component {
        id: requestBanner

        // device | name / wants to share file (PIN) | decline | accept slot
        Item {
            id: request

            // Set by the island
            property var banner
            readonly property var d: banner?.data ?? ({})
            readonly property real slot: root.island.bannerH

            implicitWidth: Math.min(440, slot * 2 + root.island.coverSize + Tokens.spacing.small * 3 + text.naturalWidth)
            implicitHeight: slot

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
                            text: "share"
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
                    title: request.d.deviceName || qsTr("Nearby device")
                    subtitle: {
                        const what = [request.d.fileName, root.size(request.d.fileSize)].filter(s => s).join(" · ");
                        return Sharing.currentPinCode ? qsTr("%1 · PIN %2").arg(what).arg(Sharing.currentPinCode) : what;
                    }
                }

                IslandButton {
                    Layout.alignment: Qt.AlignVCenter
                    island: root.island
                    icon: "close"
                    variant: "danger"
                    onClicked: {
                        Sharing.rejectIncomingTransfer();
                        Sharing.currentNotification?.close();
                        if (request.banner)
                            root.dismiss(request.banner.key);
                    }
                }

                IslandSlot {
                    size: root.island.bannerH

                    IslandButton {
                        anchors.centerIn: parent
                        island: root.island
                        icon: "check"
                        variant: "primary"
                        onClicked: {
                            Sharing.acceptIncomingTransfer();
                            if (request.banner)
                                root.dismiss(request.banner.key);
                        }
                    }
                }
            }
        }
    }
}
