pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services

Scope {
    id: root

    // The agent lives in services/Polkit.qml so the dynamic island can answer it too
    PolkitDialog {
        agent: Polkit.agent
        screen: Quickshell.screens[0]
    }
}
