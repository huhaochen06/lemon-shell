pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.State
import qs.services

// System toggles: a banner when do not disturb or game mode is switched. The trailing
// switch undoes it. While shown here, the matching shell toasts are skipped (see IslandState).
Activity {
    id: root

    function toggleBanner(key: string, on: bool, data: var, undo: var): void {
        quick(key, Object.assign({
            circleColour: on ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest,
            iconColour: on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant,
            trailingIcon: on ? "toggle_on" : "toggle_off",
            trailingColour: on ? Colours.palette.m3primary : Colours.palette.m3outline,
            onTrailingClick: undo
        }, data));
    }

    name: "toggles"
    enabled: IslandConfig.toggles.enabled
    priority: IslandConfig.toggles.priority

    Connections {
        target: PersistentState

        function onDoNotDisturbChanged(): void {
            if (!IslandConfig.toggles.doNotDisturb)
                return;
            const on = PersistentState.doNotDisturb;
            root.toggleBanner("toggle-dnd", on, {
                icon: on ? "do_not_disturb_on" : "do_not_disturb_off",
                title: on ? qsTr("Do not disturb on") : qsTr("Do not disturb off"),
                subtitle: on ? qsTr("Notifications are silenced") : qsTr("Notifications will show again")
            }, () => PersistentState.doNotDisturb = !PersistentState.doNotDisturb);
        }
    }

    Connections {
        target: RuntimeState

        function onGameModeChanged(): void {
            if (!IslandConfig.toggles.gameMode)
                return;
            const on = RuntimeState.gameMode;
            root.toggleBanner("toggle-gamemode", on, {
                icon: on ? "sports_esports" : "gamepad",
                title: on ? qsTr("Game mode on") : qsTr("Game mode off"),
                subtitle: on ? qsTr("Animations, blur, gaps and shadows off") : qsTr("Hyprland settings restored")
            }, () => RuntimeState.gameMode = !RuntimeState.gameMode);
        }
    }
}
