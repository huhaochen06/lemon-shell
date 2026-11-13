pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import qs.services
import qs.utils

// Battery: charger plugged in / unplugged and low battery warnings for the laptop battery (using the
// shell's battery warn levels), and low battery warnings for peripherals (mouse, keyboard, headset...).
// While shown here, BatteryMonitor skips its own toasts for these (see IslandState).
Activity {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real percentage: battery?.percentage ?? 0
    readonly property list<var> warnLevels: [...GlobalConfig.general.battery.warnLevels.values].sort((a, b) => a.level - b.level)
    property real lastPercentage: 100

    function duration(seconds: real): string {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? qsTr("%1h %2m").arg(h).arg(m) : qsTr("%1m").arg(m);
    }

    function showCharging(): void {
        if (!hasBattery || !IslandConfig.battery.charging)
            return;
        const charging = !UPower.onBattery;
        const time = duration(charging ? battery.timeToFull : battery.timeToEmpty);
        quick("battery-charging", {
            icon: charging ? "power" : "power_off",
            title: charging ? qsTr("Charging") : qsTr("On battery"),
            subtitle: time ? (charging ? qsTr("%1 until full").arg(time) : qsTr("%1 remaining").arg(time)) : (charging ? qsTr("Charger plugged in") : qsTr("Charger unplugged")),
            trailingText: `${Math.round(percentage * 100)}`,
            progress: percentage
        });
    }

    function checkWarnings(): void {
        const p = percentage * 100;
        if (!hasBattery || !UPower.onBattery) {
            lastPercentage = p;
            return;
        }
        if (IslandConfig.battery.lowWarnings) {
            for (const level of warnLevels) {
                if (p <= level.level && lastPercentage > level.level) {
                    quick("battery-low", {
                        icon: level.icon ?? "battery_android_alert",
                        circleColour: level.critical ? Colours.palette.m3error : Colours.palette.m3errorContainer,
                        iconColour: level.critical ? Colours.palette.m3onError : Colours.palette.m3onErrorContainer,
                        title: level.title ?? qsTr("Battery low"),
                        subtitle: level.message ?? qsTr("Plug in a charger soon"),
                        trailingText: `${Math.round(p)}`,
                        progress: percentage,
                        progressColour: Colours.palette.m3error
                    }, {
                        priority: priority + (level.critical ? 30 : 10),
                        duration: IslandConfig.quickDuration * 2,
                        requeue: true
                    });
                    break;
                }
            }
        }
        lastPercentage = p;
    }

    function peripheralIcon(device: UPowerDevice): string {
        switch (device.type) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
            return "headphones";
        case UPowerDeviceType.GamingInput:
            return "sports_esports";
        case UPowerDeviceType.Phone:
            return "smartphone";
        case UPowerDeviceType.Tablet:
            return "tablet";
        case UPowerDeviceType.Speakers:
            return "speaker";
        default:
            return "battery_alert";
        }
    }

    name: "battery"
    enabled: IslandConfig.battery.enabled
    priority: IslandConfig.battery.priority

    Connections {
        target: UPower

        function onOnBatteryChanged(): void {
            if (!root.battery?.ready)
                return;
            root.showCharging();
            if (UPower.onBattery)
                root.checkWarnings();
            else
                root.lastPercentage = 100;
        }
    }

    Connections {
        target: root.battery

        function onPercentageChanged(): void {
            if (root.battery?.ready)
                root.checkWarnings();
        }
    }

    // Peripherals: warn once when one drops to the threshold, again only after it has been charged
    Instantiator {
        model: ScriptModel {
            values: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent && !GlobalConfig.bar.peripheralBatteryExcluded.some(e => e === d.model || e === d.nativePath)) // qmllint disable unresolved-type
        }

        delegate: QtObject {
            id: peripheral

            required property UPowerDevice modelData
            readonly property real level: modelData.percentage * 100
            readonly property bool charging: modelData.state === UPowerDeviceState.Charging || modelData.state === UPowerDeviceState.FullyCharged || modelData.state === UPowerDeviceState.PendingCharge
            // Below the threshold at startup counts as already warned
            property bool warned: level <= IslandConfig.battery.peripheralLevel

            onLevelChanged: {
                const threshold = IslandConfig.battery.peripheralLevel;
                if (warned) {
                    if (level > threshold + 5 || charging)
                        warned = false;
                    return;
                }
                if (level > threshold || charging || !root.ready || !IslandConfig.battery.peripherals)
                    return;
                warned = true;
                root.quick(`battery-peripheral-${modelData.nativePath}`, {
                    icon: root.peripheralIcon(modelData),
                    circleColour: Colours.palette.m3errorContainer,
                    iconColour: Colours.palette.m3onErrorContainer,
                    title: modelData.model || qsTr("Device"),
                    subtitle: qsTr("Battery low"),
                    trailingText: `${Math.round(level)}`,
                    progress: modelData.percentage,
                    progressColour: Colours.palette.m3error
                }, {
                    duration: IslandConfig.quickDuration * 2,
                    requeue: true
                });
            }
        }
    }
}
