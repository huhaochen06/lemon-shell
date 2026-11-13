pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services

// Checks for package updates (checkupdates, plus the AUR with paru or yay) every few hours while the
// island's updates activity is on (UpdatesActivity shows them). Checks again after an update run from
// the island (or one the fish hook tracked) ends.
//   qs -c caelestia ipc call updates check | announce | count | list
Singleton {
    id: root

    readonly property bool active: IslandConfig.updates.enabled
    // [{ name, from, to, aur }]
    property var packages: []
    readonly property int count: packages.length
    property bool checking: false
    property real lastCheck: 0
    // paru or yay, if installed
    property string aurHelper: ""
    property bool helperChecked: false

    readonly property string updateCommand: IslandConfig.updates.command || (aurHelper ? `${aurHelper} -Syu` : "sudo pacman -Syu")

    // After each check: the packages that weren't in the previous one
    signal checked(var fresh)
    // Show the banner again (IPC "announce")
    signal showRequested

    function check(): void {
        if (checking || !helperChecked)
            return;
        checking = true;
        checkProc.running = true;
    }

    function parse(text: string): void {
        const seen = new Set(packages.map(p => `${p.name} ${p.to}`));
        const list = [];
        for (const line of text.split("\n")) {
            // "<repo|aur> name old -> new", maybe followed by "[ignored]"
            const m = line.trim().match(/^(repo|aur)\s+(\S+)\s+(\S+)\s+->\s+(\S+)(.*)$/);
            if (m && !m[5].includes("ignored"))
                list.push({
                    name: m[2],
                    from: m[3],
                    to: m[4],
                    aur: m[1] === "aur"
                });
        }
        packages = list;
        lastCheck = Date.now();
        checked(list.filter(p => !seen.has(`${p.name} ${p.to}`)));
    }

    // The configured terminal, running `argv`. Terminals differ in how they take a command: foot and kitty
    // run their arguments, most others want -e first, and a few have their own syntax.
    function inTerminal(argv: var): var {
        const term = GlobalConfig.general.apps.terminal;
        const name = (term[0] ?? "").split("/").pop();
        if (["kitty", "foot", "footclient"].includes(name))
            return [...term, ...argv];
        if (name === "wezterm")
            return [...term, "start", "--", ...argv];
        if (["gnome-terminal", "kgx", "ptyxis"].includes(name))
            return [...term, "--", ...argv];
        return [...term, "-e", ...argv];
    }

    // Opens a terminal running the update, as a live island task
    function runUpdate(): void {
        Quickshell.execDetached(inTerminal([`${Quickshell.shellDir}/scripts/island`, "run", "--title", qsTr("System update"), "--icon", "system_update", "--", "sh", "-c", `${root.updateCommand}; printf '\\n%s' 'Press Enter to close'; read _`]));
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v paru || command -v yay || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                root.aurHelper = path ? path.split("/").pop() : "";
                root.helperChecked = true;
            }
        }
    }

    Process {
        id: checkProc

        // checkupdates exits 2 when there's nothing to update, so the script always succeeds
        command: ["sh", "-c", "checkupdates --nocolor 2>/dev/null | sed 's/^/repo /'; if [ \"$2\" = 1 ] && [ -n \"$1\" ]; then \"$1\" -Qua --color never 2>/dev/null | sed 's/^/aur /'; fi; true", "sh", root.aurHelper, IslandConfig.updates.aur ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: root.checking = false
    }

    // First check a couple of minutes after startup, then every `interval` hours
    Timer {
        running: root.active && root.helperChecked
        interval: 2 * 60 * 1000
        onTriggered: root.check()
    }

    Timer {
        running: root.active && root.helperChecked
        repeat: true
        interval: Math.max(0.25, IslandConfig.updates.interval) * 3600 * 1000
        onTriggered: root.check()
    }

    Connections {
        target: IslandTasks

        function onTaskEnded(task: var): void {
            if (!root.active)
                return;
            if (task.title === qsTr("System update") || /^(sudo\s+)?(paru|yay|pacman)\b/.test(task.title ?? ""))
                recheck.restart();
        }
    }

    Timer {
        id: recheck

        interval: 3000
        onTriggered: root.check()
    }

    IpcHandler {
        target: "updates"

        function check(): void {
            root.check();
        }

        function announce(): string {
            if (root.count === 0)
                return root.lastCheck > 0 ? "no updates" : "not checked yet";
            root.showRequested();
            return `${root.count} updates`;
        }

        function count(): int {
            return root.count;
        }

        function list(): string {
            return root.packages.map(p => `${p.name} ${p.from} -> ${p.to}${p.aur ? " (aur)" : ""}`).join("\n");
        }
    }
}
