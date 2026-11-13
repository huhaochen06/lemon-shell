pragma Singleton
import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.Services

QtObject {
    id: root

    property bool isEnabled: QuickShareService.isEnabled
    property bool isVisible: QuickShareService.isVisible
    property var nearbyDevices: QuickShareService.nearbyDevices
    property var transferHistory: QuickShareService.transferHistory

    property var currentNotification: null
    property string currentDeviceName: ""
    property string currentFileName: ""
    property string currentPinCode: ""
    property real currentFileSize: 0

    // The transfer in progress, or null:
    //   { direction: "send" | "receive", deviceName, fileName, sent, total }
    // sent is -1 when progress isn't known (incoming transfers don't report it)
    property var transfer: null

    signal transferRequested(string deviceName, string fileName, real fileSize)
    signal transferEnded(var info, bool success)

    function setEnabled(enabled: bool) {
        QuickShareService.isEnabled = enabled
    }

    function setVisible(visible: bool) {
        QuickShareService.isVisible = visible
    }

    function sendFile(deviceId: string, filePath: string) {
        const device = (root.nearbyDevices ?? []).find(d => d.id === deviceId)
        root.transfer = {
            direction: "send",
            deviceName: device?.name || deviceId,
            fileName: filePath.split("/").pop(),
            filePath: filePath,
            sent: 0,
            total: 0
        }
        QuickShareService.sendFile(deviceId, filePath)
    }

    function acceptIncomingTransfer() {
        root.transfer = {
            direction: "receive",
            deviceName: root.currentDeviceName,
            fileName: root.currentFileName,
            filePath: "",
            sent: -1,
            total: root.currentFileSize
        }
        QuickShareService.acceptIncomingTransfer()
    }

    function rejectIncomingTransfer() {
        QuickShareService.rejectIncomingTransfer()
    }

    function clearHistory() {
        QuickShareService.clearHistory()
    }

    function removeHistoryEntry(index: int) {
        QuickShareService.removeHistoryEntry(index)
    }

    function startBleWakeupBroadcast() {
        QuickShareService.startBleWakeupBroadcast()
    }

    function stopBleWakeupBroadcast() {
        QuickShareService.stopBleWakeupBroadcast()
    }

    // Connect to C++ signals
    Component.onCompleted: {
        QuickShareService.incomingTransferRequested.connect(function(deviceName, fileName, fileSize) {
            console.log("Quick Share: Incoming transfer from " + deviceName + " - " + fileName)
            root.currentDeviceName = deviceName
            root.currentFileName = fileName
            root.currentFileSize = fileSize
            root.transferRequested(deviceName, fileName, fileSize)
            let body = qsTr("%1 wants to share %2").arg(deviceName).arg(fileName)
            if (root.currentPinCode)
                body += qsTr("\nPIN: %1").arg(root.currentPinCode)
            root.currentNotification = Notifs.addCustomNotification(
                qsTr("Incoming file"),
                body,
                "",
                [
                    { text: qsTr("Decline"), invoke: function() { root.rejectIncomingTransfer(); } },
                    { text: qsTr("Accept"), invoke: function() { root.acceptIncomingTransfer(); } }
                ],
                true
            );
        })
        QuickShareService.incomingTransferPinReady.connect(function(pinCode) {
            root.currentPinCode = pinCode
            if (root.currentNotification) {
                root.currentNotification.body = qsTr("%1 wants to share %2\nPIN: %3").arg(root.currentDeviceName).arg(root.currentFileName).arg(pinCode)
            }
        })
        QuickShareService.errorOccurred.connect(function(message) {
            Toaster.toast(qsTr("Quick Share Error"), message, "error");
        })
        QuickShareService.transferProgress.connect(function(deviceId, sent, total) {
            if (root.transfer)
                root.transfer = Object.assign({}, root.transfer, { sent: sent, total: total })
        })
        QuickShareService.transferFinished.connect(function(deviceId, success) {
            const info = root.transfer
            root.transfer = null
            if (info) {
                // Received files are saved to ~/Downloads (see quickshare_service.cpp)
                if (info.direction === "receive" && success && root.transferHistory?.length > 0)
                    info.filePath = root.transferHistory[0].filePath ?? ""
                root.transferEnded(info, success)
            }
            if (root.currentNotification) {
                root.currentNotification.close();
                root.currentNotification = null;
            }
            root.currentDeviceName = ""
            root.currentFileName = ""
            root.currentPinCode = ""
        })

        if (GlobalConfig.services.quickShareAutoStart) {
            root.setEnabled(true);
            root.setVisible(true);
        }
    }
}
