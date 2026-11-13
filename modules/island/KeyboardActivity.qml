pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Keyboard layout: a banner with the layout code and name when it changes. The shell's own toast for
// this comes from the C++ plugin, so it is filtered out in the toast list instead (see IslandState).
Activity {
    id: root

    readonly property string layout: Hypr.kbLayoutFull

    name: "keyboard"
    enabled: IslandConfig.keyboard.enabled
    priority: IslandConfig.keyboard.priority

    onLayoutChanged: {
        if (!Hypr.keyboard)
            return;
        quick("keyboard-layout", {
            leadingText: Hypr.kbLayout.toUpperCase().slice(0, 3),
            title: layout,
            subtitle: qsTr("Keyboard layout"),
            trailingIcon: "keyboard"
        });
    }
}
