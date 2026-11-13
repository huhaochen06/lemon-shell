pragma Singleton

import Quickshell
import Quickshell.Services.Polkit

// The polkit authentication agent, shared by the dynamic island (PolkitActivity, on the focused monitor)
// and the full screen dialog (components/PolkitDialog.qml), which steps aside while the island covers it.
Singleton {
    readonly property alias agent: agent
    readonly property AuthFlow flow: agent.flow
    readonly property bool active: agent.isActive && agent.flow !== null

    PolkitAgent {
        id: agent
    }
}
