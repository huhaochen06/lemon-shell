pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.utils

// Network: banners when Wi-Fi / Ethernet connects or disconnects and when the VPN goes up or down.
// Based on the active device and connection from NetworkManager's device status (stable, unlike the
// scan list), debounced so a quick reconnect doesn't flash two banners.
Activity {
    id: root

    readonly property string connection: Nmcli.isConnected ? Nmcli.activeConnection : ""
    readonly property bool isEthernet: Nmcli.ethernetDevices.some(d => d.iface === Nmcli.activeInterface)
    // What was last announced (or seen at startup)
    property string lastConnection
    property bool lastEthernet
    property bool lastVpn

    function checkConnection(): void {
        const conn = connection;
        if (conn === lastConnection)
            return;
        const wasConnection = lastConnection;
        const wasEthernet = lastEthernet;
        lastConnection = conn;
        lastEthernet = isEthernet;

        if (conn) {
            if (!(isEthernet ? IslandConfig.network.ethernet : IslandConfig.network.wifi))
                return;
            const ap = Nmcli.active;
            quick("network", {
                icon: isEthernet ? "lan" : Icons.getNetworkIcon(ap?.strength ?? 100, ap?.isSecure ?? false),
                title: conn,
                subtitle: isEthernet ? qsTr("Ethernet connected") : qsTr("Wi-Fi connected"),
                trailingText: !isEthernet && ap ? `${ap.strength}` : "",
                progress: !isEthernet && ap ? ap.strength / 100 : -1
            });
        } else if (wasConnection) {
            if (!(wasEthernet ? IslandConfig.network.ethernet : IslandConfig.network.wifi))
                return;
            quick("network", {
                icon: wasEthernet ? "lan" : Nmcli.wifiEnabled ? "wifi_off" : "signal_wifi_off",
                circleColour: Colours.palette.m3errorContainer,
                iconColour: Colours.palette.m3onErrorContainer,
                title: wasConnection,
                subtitle: wasEthernet ? qsTr("Ethernet disconnected") : Nmcli.wifiEnabled ? qsTr("Wi-Fi disconnected") : qsTr("Wi-Fi turned off")
            });
        }
    }

    name: "network"
    enabled: IslandConfig.network.enabled
    priority: IslandConfig.network.priority

    onConnectionChanged: settle.restart()
    onReadyChanged: {
        // Whatever is connected at startup is the baseline, not news
        lastConnection = connection;
        lastEthernet = isEthernet;
        lastVpn = VPN.connected;
    }

    Timer {
        id: settle

        interval: 2000
        onTriggered: {
            if (root.ready)
                root.checkConnection();
            else
                root.lastConnection = root.connection;
        }
    }

    Connections {
        target: VPN

        function onConnectedChanged(): void {
            if (VPN.connected === root.lastVpn || !root.ready)
                return;
            root.lastVpn = VPN.connected;
            if (!IslandConfig.network.vpn)
                return;
            root.quick("vpn", {
                icon: VPN.connected ? "vpn_key" : "vpn_key_off",
                circleColour: VPN.connected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest,
                iconColour: VPN.connected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant,
                title: VPN.active?.displayName || qsTr("VPN"),
                subtitle: VPN.connected ? (VPN.serverLocation ? qsTr("Connected · %1").arg(VPN.serverLocation) : qsTr("Connected")) : qsTr("Disconnected")
            });
        }
    }
}
