pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Quick Share (Android, QuickShare.qml) and AirDrop (iPhone, AirDrop.qml) side by side, for the UI
// both share: the utilities card, device selector, delete modal and the island's transfer activity.
// Each runs on its own toggle. Devices, history and transfers are merged here, tagged with the
// backend they came from, and every action is routed back to that backend.
Singleton {
    id: root

    readonly property var backends: ({
            quickshare: QuickShare,
            airdrop: AirDrop
        })

    readonly property bool isEnabled: QuickShare.isEnabled || AirDrop.isEnabled
    readonly property bool isVisible: (QuickShare.isEnabled && QuickShare.isVisible) || (AirDrop.isEnabled && AirDrop.isVisible)

    // Device ids are "<backend>:<id>"
    readonly property var nearbyDevices: [...tag("quickshare", QuickShare.nearbyDevices), ...tag("airdrop", AirDrop.nearbyDevices)].map(d => Object.assign({}, d, {
                id: `${d.backend}:${d.id}`,
                deviceId: d.id
            }))

    // Newest first. index is the entry's place in its own backend's list.
    readonly property var transferHistory: [...tag("quickshare", QuickShare.transferHistory), ...tag("airdrop", AirDrop.transferHistory)].sort((a, b) => (b.timestamp ?? 0) - (a.timestamp ?? 0))

    readonly property var transfer: QuickShare.transfer ? Object.assign({}, QuickShare.transfer, {
            backend: "quickshare"
        }) : AirDrop.transfer ? Object.assign({}, AirDrop.transfer, {
            backend: "airdrop"
        }) : null

    // The backend whose incoming request is waiting for an answer
    property string pendingBackend: ""
    readonly property var pending: backends[pendingBackend] ?? null
    readonly property string currentPinCode: pending?.currentPinCode ?? ""
    readonly property var currentNotification: pending?.currentNotification ?? null

    // A short description of what's on, for status lines
    readonly property string statusText: {
        const on = [];
        if (QuickShare.isEnabled)
            on.push(qsTr("Quick Share"));
        if (AirDrop.isEnabled)
            on.push(qsTr("AirDrop"));
        return on.length > 0 ? qsTr("%1 on").arg(on.join(qsTr(" and "))) : qsTr("Disabled");
    }

    signal transferRequested(string deviceName, string fileName, real fileSize)
    signal transferEnded(var info, bool success)

    function tag(backend: string, list: var): var {
        return (list ?? []).map((item, index) => Object.assign({}, item, {
                    backend,
                    index
                }));
    }

    function sendFile(deviceId: string, filePath: string): void {
        const device = root.nearbyDevices.find(d => d.id === deviceId);
        if (device)
            root.backends[device.backend].sendFile(device.deviceId, filePath);
    }

    function acceptIncomingTransfer(): void {
        root.pending?.acceptIncomingTransfer();
        root.pendingBackend = "";
    }

    function rejectIncomingTransfer(): void {
        root.pending?.currentNotification?.close();
        root.pending?.rejectIncomingTransfer();
        root.pendingBackend = "";
    }

    // index is into Sharing.transferHistory
    function removeHistoryEntry(index: int): void {
        const entry = root.transferHistory[index];
        if (entry)
            root.backends[entry.backend].removeHistoryEntry(entry.index);
    }

    function clearHistory(): void {
        QuickShare.clearHistory();
        AirDrop.clearHistory();
    }

    // While the device selector is open: discovery on each backend that's on
    function startBleWakeupBroadcast(): void {
        if (QuickShare.isEnabled)
            QuickShare.startBleWakeupBroadcast();
        if (AirDrop.isEnabled)
            AirDrop.startBleWakeupBroadcast();
    }

    function stopBleWakeupBroadcast(): void {
        QuickShare.stopBleWakeupBroadcast();
        AirDrop.stopBleWakeupBroadcast();
    }

    Connections {
        target: QuickShare

        function onTransferRequested(deviceName: string, fileName: string, fileSize: real): void {
            root.pendingBackend = "quickshare";
            root.transferRequested(deviceName, fileName, fileSize);
        }

        function onTransferEnded(info: var, success: bool): void {
            if (root.pendingBackend === "quickshare")
                root.pendingBackend = "";
            root.transferEnded(Object.assign({}, info, {
                backend: "quickshare"
            }), success);
        }
    }

    Connections {
        target: AirDrop

        function onTransferRequested(deviceName: string, fileName: string, fileSize: real): void {
            root.pendingBackend = "airdrop";
            root.transferRequested(deviceName, fileName, fileSize);
        }

        function onTransferEnded(info: var, success: bool): void {
            if (root.pendingBackend === "airdrop")
                root.pendingBackend = "";
            root.transferEnded(Object.assign({}, info, {
                backend: "airdrop"
            }), success);
        }
    }

    // qs -c caelestia ipc call quickshare <enable|disable|toggle|status>
    IpcHandler {
        target: "quickshare"

        function enable(): void {
            QuickShare.setEnabled(true);
            QuickShare.setVisible(true);
        }

        function disable(): void {
            QuickShare.setEnabled(false);
            QuickShare.setVisible(false);
        }

        function toggle(): void {
            const on = !QuickShare.isEnabled;
            QuickShare.setEnabled(on);
            QuickShare.setVisible(on);
        }

        function status(): string {
            return QuickShare.isEnabled ? (QuickShare.isVisible ? "visible" : "on") : "off";
        }

        function devices(): string {
            return JSON.stringify(QuickShare.nearbyDevices);
        }
    }
}
