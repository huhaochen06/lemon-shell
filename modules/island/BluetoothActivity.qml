pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.utils

// Bluetooth: a banner when a device connects (icon, name, battery ring if it reports one) or
// disconnects. Battery levels usually arrive a moment after connecting, so connects wait briefly.
Activity {
    id: root

    function show(device: BluetoothDevice, connected: bool): void {
        if (!connected && !IslandConfig.bluetooth.disconnects)
            return;

        const battery = device.batteryAvailable ? device.battery : -1;
        const low = battery >= 0 && battery < 0.2;
        quick(`bluetooth-${device.address}`, {
            icon: Icons.getBluetoothIcon(device.icon),
            circleColour: connected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest,
            iconColour: connected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant,
            title: device.name || device.address,
            subtitle: connected ? qsTr("Connected") : qsTr("Disconnected"),
            trailingIcon: connected ? "bluetooth_connected" : "bluetooth_disabled",
            trailingText: connected && battery >= 0 ? `${Math.round(battery * 100)}` : "",
            progress: connected ? battery : -1,
            progressColour: low ? Colours.palette.m3error : Colours.palette.m3primary
        });
    }

    name: "bluetooth"
    enabled: IslandConfig.bluetooth.enabled
    priority: IslandConfig.bluetooth.priority

    Instantiator {
        model: Bluetooth.devices

        delegate: QtObject {
            id: device

            required property BluetoothDevice modelData
            property bool wasConnected: modelData.connected

            readonly property Connections conn: Connections {
                target: device.modelData

                function onConnectedChanged(): void {
                    const connected = device.modelData.connected;
                    if (connected === device.wasConnected)
                        return;
                    device.wasConnected = connected;
                    if (connected) {
                        device.batteryWait.restart();
                    } else {
                        device.batteryWait.stop();
                        root.show(device.modelData, false);
                    }
                }

                // Update an already showing banner when the battery level comes in
                function onBatteryChanged(): void {
                    if (device.modelData.connected && !device.batteryWait.running && root.island.current?.key === `bluetooth-${device.modelData.address}`)
                        root.show(device.modelData, true);
                }
            }

            readonly property Timer batteryWait: Timer {
                interval: 1200
                onTriggered: {
                    if (device.modelData.connected)
                        root.show(device.modelData, true);
                }
            }
        }
    }
}
