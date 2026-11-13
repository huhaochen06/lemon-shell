pragma Singleton

import Quickshell

// Shared state from the dynamic island (modules/island) for the rest of the shell.
// `covered` lists the events the island on the focused screen currently shows itself, so code that
// would also toast about them (battery, VPN, do not disturb, ...) can skip its toast. Written only by
// DynamicIsland; empty while the island is hidden or disabled, so the toasts come back.
Singleton {
    property var covered: ({})

    function covers(kind: string): bool {
        return covered[kind] === true;
    }
}
