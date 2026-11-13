pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.utils

// AirDrop with iPhones, through Owly (https://github.com/t4t5/owly).
//
// The same API as QuickShare (Android), so the sharing UI drives both through Sharing.qml.
// Drives the owly CLI:
//   owly radio up    holds the AWDL radio (owlyd) while enabled. On Intel cards this takes
//                    Wi-Fi down until it's given back.
//   owly receive     the receiver, while enabled and visible. Asks on stdin, y/N.
//   owly browse      nearby receivers, while the device selector is open.
//   owly send        one transfer at a time.
Singleton {
    id: root

    property bool isEnabled: false
    property bool isVisible: false
    // awdl0 is up: the radio has been lent to us
    property bool radioUp: false
    property var nearbyDevices: []
    property var transferHistory: []

    property var currentNotification: null
    property string currentDeviceName: ""
    property string currentFileName: ""
    property string currentPinCode: "" // AirDrop has no PIN; kept for the UI
    property real currentFileSize: 0

    // The transfer in progress, or null:
    //   { direction: "send" | "receive", deviceName, fileName, sent, total }
    // sent is -1 when progress isn't known (owly receive doesn't report it)
    property var transfer: null

    readonly property string downloadDir: Quickshell.env("XDG_DOWNLOAD_DIR") || `${Paths.home}/Downloads`

    signal transferRequested(string deviceName, string fileName, real fileSize)
    signal transferEnded(var info, bool success)

    // ---- API used by the UI ----

    function setEnabled(enabled: bool): void {
        root.isEnabled = enabled;
    }

    function setVisible(visible: bool): void {
        root.isVisible = visible;
    }

    function sendFile(deviceId: string, filePath: string): void {
        if (!root.radioUp) {
            root.error(qsTr("AirDrop isn't on"));
            return;
        }
        if (sendProc.running) {
            root.error(qsTr("Already sending a file"));
            return;
        }
        const device = root.nearbyDevices.find(d => d.id === deviceId);
        root.transfer = {
            direction: "send",
            deviceName: device?.name || deviceId,
            fileName: filePath.split("/").pop(),
            filePath: filePath,
            sent: 0,
            total: 0
        };
        sendProc.result = "";
        sendProc.command = ["owly", "send", "--to", deviceId, filePath];
        sendProc.running = true;
    }

    function acceptIncomingTransfer(): void {
        if (!receiveProc.pending)
            return;
        receiveProc.pending = false;
        root.transfer = {
            direction: "receive",
            deviceName: root.currentDeviceName,
            fileName: root.currentFileName,
            filePath: "",
            sent: -1,
            total: root.currentFileSize
        };
        receiveProc.write("y\n");
        root.closeNotification();
    }

    function rejectIncomingTransfer(): void {
        if (!receiveProc.pending)
            return;
        receiveProc.pending = false;
        receiveProc.write("n\n");
        root.clearRequest();
    }

    function clearHistory(): void {
        root.transferHistory = [];
        root.saveHistory();
    }

    function removeHistoryEntry(index: int): void {
        const list = root.transferHistory.slice();
        list.splice(index, 1);
        root.transferHistory = list;
        root.saveHistory();
    }

    // Called while the device selector is open: browse for receivers. owly browse also sends
    // the Bluetooth advert that wakes iPhones' AirDrop.
    function startBleWakeupBroadcast(): void {
        root.nearbyDevices = [];
        browseProc.wanted = true;
        if (root.radioUp)
            browseProc.running = true;
    }

    function stopBleWakeupBroadcast(): void {
        browseProc.wanted = false;
        browseProc.running = false;
    }

    // ---- internals ----

    function error(message: string): void {
        console.warn("AirDrop:", message);
        Toaster.toast(qsTr("AirDrop"), message, "error");
    }

    // owly prints what senders send with Rust's {:?}: a quoted, escaped string
    function unquote(s: string): string {
        if (s.length < 2 || s[0] !== '"' || s[s.length - 1] !== '"')
            return s;
        return s.slice(1, -1).replace(/\\u\{([0-9a-fA-F]+)\}|\\(.)/g, (m, hex, c) => {
            if (hex)
                return String.fromCodePoint(parseInt(hex, 16));
            return c === "n" ? "\n" : c === "t" ? "\t" : c === "r" ? "\r" : c === "0" ? "\0" : c;
        });
    }

    function addHistory(entry: var): void {
        root.transferHistory = [entry, ...root.transferHistory].slice(0, 100);
        root.saveHistory();
    }

    function saveHistory(): void {
        historyFile.setText(JSON.stringify(root.transferHistory));
    }

    function closeNotification(): void {
        if (root.currentNotification) {
            root.currentNotification.close();
            root.currentNotification = null;
        }
    }

    function clearRequest(): void {
        root.closeNotification();
        root.currentDeviceName = "";
        root.currentFileName = "";
        root.currentFileSize = 0;
    }

    function finish(success: bool): void {
        const info = root.transfer;
        root.transfer = null;
        if (info)
            root.transferEnded(info, success);
        root.clearRequest();
    }

    function raiseRequest(): void {
        const files = receiveProc.files;
        const urls = receiveProc.urls;
        let name;
        if (files.length > 0)
            name = files.length === 1 ? files[0].name : qsTr("%1 and %2 more").arg(files[0].name).arg(files.length - 1);
        else if (urls.length > 0)
            name = urls.length === 1 ? urls[0] : qsTr("%1 links").arg(urls.length);
        else
            name = qsTr("something");

        root.currentDeviceName = receiveProc.sender || qsTr("An iPhone");
        root.currentFileName = name;
        root.currentFileSize = files.reduce((sum, f) => sum + (f.size || 0), 0);
        receiveProc.pending = true;

        root.transferRequested(root.currentDeviceName, root.currentFileName, root.currentFileSize);
        root.currentNotification = Notifs.addCustomNotificationAs("AirDrop", qsTr("Incoming file"), qsTr("%1 wants to share %2").arg(root.currentDeviceName).arg(root.currentFileName), "", [
            {
                text: qsTr("Decline"),
                invoke: () => root.rejectIncomingTransfer()
            },
            {
                text: qsTr("Accept"),
                invoke: () => root.acceptIncomingTransfer()
            }
        ], true);
    }

    onIsEnabledChanged: {
        if (isEnabled) {
            radioProc.running = true;
        } else {
            browseProc.running = false;
            receiveProc.running = false;
            sendProc.running = false;
            radioProc.running = false; // SIGTERM: owly gives the radio, and Wi-Fi, back
            root.nearbyDevices = [];
        }
    }

    Component.onCompleted: {
    }

    // Turn on when the shell starts. Its own setting, not Quick Share's: on Intel cards AirDrop
    // takes Wi-Fi down while it's on.
    property alias autoStart: settings.autoStart

    FileView {
        id: settingsFile

        path: `${Paths.state}/airdrop.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            if (settings.autoStart && !root.started) {
                root.started = true;
                root.setEnabled(true);
                root.setVisible(true);
            }
        }
        onLoadFailed: root.started = true

        JsonAdapter {
            id: settings

            property bool autoStart: false
        }
    }

    property bool started: false

    // qs -c caelestia ipc call airdrop <toggle|enable|disable|status|send <name> <path>>
    IpcHandler {
        target: "airdrop"

        function toggle(): void {
            root.setEnabled(!root.isEnabled);
            root.setVisible(root.isEnabled);
        }

        function enable(): void {
            root.setEnabled(true);
            root.setVisible(true);
        }

        function disable(): void {
            root.setEnabled(false);
        }

        function status(): string {
            if (!root.isEnabled)
                return "off";
            if (!root.radioUp)
                return "starting";
            if (root.transfer)
                return `${root.transfer.direction} ${root.transfer.fileName} ${root.transfer.sent}/${root.transfer.total}`;
            return root.isVisible ? "receiving" : "on";
        }

        function devices(): string {
            return JSON.stringify(root.nearbyDevices);
        }

        function send(to: string, path: string): void {
            root.sendFile(to, path);
        }
    }

    FileView {
        id: historyFile

        path: `${Paths.state}/airdrop_history.json`
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.transferHistory = list;
            } catch (e) {}
        }
    }

    // Holds the radio while enabled
    Process {
        id: radioProc

        command: ["owly", "radio", "up"]

        stderr: SplitParser {
            onRead: line => {
                if (/ is up: /.test(line)) {
                    root.radioUp = true;
                } else if (line.startsWith("owly: ")) {
                    root.error(line.slice(6));
                }
            }
        }

        onExited: (code, status) => {
            root.radioUp = false;
            if (root.isEnabled) {
                // It went down by itself (or never came up)
                if (code !== 0)
                    console.warn("AirDrop: owly radio up exited with", code);
                root.isEnabled = false;
            }
        }
    }

    // The receiver
    Process {
        id: receiveProc

        property string sender: ""
        property var files: []
        property var urls: []
        property bool collecting: false
        property bool pending: false
        property var received: []
        property string lastLine: ""
        // Not a binding on running: an exit would break it, and the receiver would stay down
        readonly property bool wanted: root.radioUp && root.isVisible

        onWantedChanged: running = wanted
        command: ["owly", "receive", "--dir", root.downloadDir]
        stdinEnabled: true

        stderr: SplitParser {
            onRead: line => {
                receiveProc.lastLine = line;
                let m;
                if ((m = line.match(/^(".*") \((".*")\) wants to send:$/))) {
                    receiveProc.sender = root.unquote(m[1]);
                    receiveProc.files = [];
                    receiveProc.urls = [];
                    receiveProc.collecting = true;
                    requestTimer.restart();
                } else if (receiveProc.collecting && line.startsWith("  ")) {
                    const entry = line.slice(2);
                    if ((m = entry.match(/^(".*") (\S+)(?: (\d+) bytes)?$/)))
                        receiveProc.files = [...receiveProc.files, {
                                name: root.unquote(m[1]),
                                type: m[2],
                                size: m[3] ? parseInt(m[3]) : 0
                            }];
                    else
                        receiveProc.urls = [...receiveProc.urls, root.unquote(entry)];
                    requestTimer.restart();
                } else if (/the request was withdrawn|timed out/.test(line)) {
                    receiveProc.pending = false;
                    root.clearRequest();
                } else if (line.startsWith("transfer failed: ")) {
                    root.error(qsTr("Transfer failed: %1").arg(line.slice(17)));
                    root.finish(false);
                } else if (line.startsWith("owly: ")) {
                    root.error(line.slice(6));
                }
            }
        }

        stdout: SplitParser {
            onRead: line => {
                if (!line)
                    return;
                if (line.startsWith('"')) {
                    // A link: shown, not opened
                    const url = root.unquote(line);
                    Notifs.addCustomNotificationAs("AirDrop", qsTr("AirDrop link"), url, "", [
                        {
                            text: qsTr("Open"),
                            invoke: () => Quickshell.execDetached(["xdg-open", url])
                        }
                    ], false);
                    root.finish(true);
                    return;
                }
                receiveProc.received = [...receiveProc.received, line];
                receivedTimer.restart();
            }
        }

        onExited: code => {
            pending = false;
            if (root.transfer?.direction === "receive")
                root.finish(false);
            else
                root.clearRequest();
            if (wanted) {
                console.warn("AirDrop: owly receive exited with", code, "-", lastLine, "- restarting");
                receiveRestart.restart();
            }
        }
    }

    Timer {
        id: receiveRestart

        interval: 1000
        onTriggered: {
            if (receiveProc.wanted)
                receiveProc.running = true;
        }
    }

    // The ask's file lines come one by one, and "accept? [y/N] " has no newline
    Timer {
        id: requestTimer

        interval: 150
        onTriggered: {
            receiveProc.collecting = false;
            root.raiseRequest();
        }
    }

    // All the paths of one transfer are printed together
    Timer {
        id: receivedTimer

        interval: 200
        onTriggered: {
            const now = Math.floor(Date.now() / 1000);
            for (const path of receiveProc.received)
                root.addHistory({
                    fileName: path.split("/").pop(),
                    filePath: path,
                    timestamp: now,
                    direction: "received",
                    deviceName: root.transfer?.deviceName || root.currentDeviceName || qsTr("iPhone")
                });
            if (root.transfer)
                root.transfer = Object.assign({}, root.transfer, {
                    filePath: receiveProc.received[0]
                });
            receiveProc.received = [];
            root.finish(true);
        }
    }

    // Nearby receivers, while the device selector is open
    Process {
        id: browseProc

        property bool wanted: false
        property var found: []

        command: ["owly", "browse", "--seconds", "8"]

        stdout: SplitParser {
            onRead: line => {
                // "<service id>    "<name>" (<address>)"
                const m = line.match(/^(\S+)\s+(".*") \((.*)\)$/);
                if (!m)
                    return;
                const device = {
                    id: m[1],
                    name: root.unquote(m[2]),
                    address: m[3]
                };
                const others = root.nearbyDevices.filter(d => d.id !== device.id);
                root.nearbyDevices = [...others, device];
            }
        }

        onExited: {
            if (wanted && root.radioUp)
                browseRestart.restart();
        }
    }

    Timer {
        id: browseRestart

        interval: 500
        onTriggered: {
            if (browseProc.wanted && root.radioUp)
                browseProc.running = true;
        }
    }

    Connections {
        target: root

        function onRadioUpChanged(): void {
            if (root.radioUp && browseProc.wanted)
                browseProc.running = true;
        }
    }

    // One transfer out
    Process {
        id: sendProc

        property string result: ""

        // Progress is "\r<sent> / <total> bytes", without newlines
        stderr: SplitParser {
            splitMarker: "\r"
            onRead: chunk => {
                for (const line of chunk.split("\n")) {
                    const m = line.match(/^(\d+) \/ (\d+) bytes$/);
                    if (m && root.transfer)
                        root.transfer = Object.assign({}, root.transfer, {
                            sent: parseInt(m[1]),
                            total: parseInt(m[2])
                        });
                    else if (line.startsWith("owly: "))
                        sendProc.result = line.slice(6);
                }
            }
        }

        stdout: SplitParser {
            onRead: line => {
                if (line)
                    sendProc.result = line;
            }
        }

        onExited: code => {
            const info = root.transfer;
            const ok = sendProc.result === "delivered";
            if (ok && info)
                root.addHistory({
                    fileName: info.fileName,
                    filePath: info.filePath,
                    timestamp: Math.floor(Date.now() / 1000),
                    direction: "sent",
                    deviceName: info.deviceName
                });
            else if (sendProc.result === "declined")
                Toaster.toast(qsTr("AirDrop"), qsTr("%1 declined the file").arg(info?.deviceName ?? qsTr("The receiver")), "near_me");
            else
                root.error(sendProc.result ? sendProc.result.replace(/^failed: /, qsTr("Failed: ")) : qsTr("Couldn't send the file"));
            root.finish(ok);
        }
    }
}
