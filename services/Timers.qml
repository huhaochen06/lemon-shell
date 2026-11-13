pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

// A countdown timer and a stopwatch (one at a time). Survives shell reloads. Shown by the dynamic island
// (modules/island/TimerActivity.qml); started from the launcher (">timer 5m") or IPC:
//   qs -c caelestia ipc call timer start 25m       (also "1h30m", "90s", "5:00", or a bare number of minutes)
//   qs -c caelestia ipc call timer stopwatch
//   qs -c caelestia ipc call timer toggle | pause | resume | stop | add 60
Singleton {
    id: root

    // "" | "timer" | "stopwatch"
    readonly property alias mode: props.mode
    readonly property alias label: props.label
    readonly property alias paused: props.paused
    readonly property bool running: mode !== ""
    // Timer: total length including added time, in ms
    readonly property alias duration: props.duration

    property real now: Date.now()

    // ms left on the timer / ms on the stopwatch
    readonly property real remaining: mode !== "timer" ? 0 : paused ? props.pausedValue : Math.max(0, props.endsAt - now)
    readonly property real elapsed: mode !== "stopwatch" ? 0 : paused ? props.pausedValue : Math.max(0, now - props.startedAt)
    readonly property real progress: mode === "timer" && duration > 0 ? remaining / duration : 0
    // What to show: the timer counts down, the stopwatch up
    readonly property string timeStr: format(mode === "timer" ? Math.ceil(remaining / 1000) * 1000 : elapsed)

    signal finished(string label, real duration)

    function format(ms: real): string {
        const t = Math.max(0, Math.floor(ms / 1000));
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const s = (t % 60).toString().padStart(2, "0");
        return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    // "1h30m", "25m", "90s", "1h 5m 10s", "5:00", "1:02:03", or a bare number of minutes. 0 if invalid.
    function parseDuration(text: string): int {
        const t = (text ?? "").trim().toLowerCase();
        if (!t)
            return 0;
        if (/^\d+(\.\d+)?$/.test(t))
            return Math.round(parseFloat(t) * 60);
        if (/^\d+(:\d{1,2}){1,2}$/.test(t)) {
            const parts = t.split(":").map(Number);
            return parts.reduce((acc, p) => acc * 60 + p, 0);
        }
        const re = /(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds)/g;
        let total = 0;
        let matched = "";
        let m;
        while ((m = re.exec(t)) !== null) {
            const n = parseFloat(m[1]);
            const unit = m[2][0];
            total += unit === "h" ? n * 3600 : unit === "m" ? n * 60 : n;
            matched += m[0];
        }
        // Everything must have been a duration (ignoring spaces)
        return matched.replace(/\s/g, "") === t.replace(/\s/g, "") ? Math.round(total) : 0;
    }

    // Short human form for labels: "25 min", "1 h 30 min", "45 s"
    function describe(seconds: int): string {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        const parts = [];
        if (h)
            parts.push(qsTr("%1 h").arg(h));
        if (m)
            parts.push(qsTr("%1 min").arg(m));
        if (s || parts.length === 0)
            parts.push(qsTr("%1 s").arg(s));
        return parts.join(" ");
    }

    function startTimer(seconds: int, label: string): void {
        if (seconds <= 0)
            return;
        now = Date.now();
        props.mode = "timer";
        props.label = label ?? "";
        props.duration = seconds * 1000;
        props.endsAt = now + props.duration;
        props.paused = false;
    }

    function startStopwatch(label: string): void {
        now = Date.now();
        props.mode = "stopwatch";
        props.label = label ?? "";
        props.duration = 0;
        props.startedAt = now;
        props.paused = false;
    }

    function pause(): void {
        if (!running || paused)
            return;
        now = Date.now();
        props.pausedValue = mode === "timer" ? remaining : elapsed;
        props.paused = true;
    }

    function resume(): void {
        if (!running || !paused)
            return;
        now = Date.now();
        if (mode === "timer")
            props.endsAt = now + props.pausedValue;
        else
            props.startedAt = now - props.pausedValue;
        props.paused = false;
    }

    function togglePause(): void {
        paused ? resume() : pause();
    }

    function addSeconds(seconds: int): void {
        if (mode !== "timer")
            return;
        props.duration += seconds * 1000;
        if (paused)
            props.pausedValue += seconds * 1000;
        else
            props.endsAt += seconds * 1000;
    }

    function stop(): void {
        props.mode = "";
        props.paused = false;
    }

    PersistentProperties {
        id: props

        property string mode
        property string label
        property bool paused
        property real duration
        property real endsAt
        property real startedAt
        property real pausedValue

        reloadableId: "timers"
    }

    // Ticks while something runs; a timer that ran out while the shell was reloading finishes on the first tick
    Timer {
        running: root.running && !root.paused
        repeat: true
        interval: 250
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            if (root.mode === "timer" && root.remaining <= 0) {
                const label = root.label;
                const duration = root.duration;
                root.stop();
                Audio.playNotification();
                root.finished(label, duration);
                // The dynamic island shows this itself when it can
                if (!IslandState.covers("timer"))
                    Toaster.toast(label || qsTr("Timer finished"), qsTr("%1 timer is done").arg(root.describe(Math.round(duration / 1000))), "alarm");
            }
        }
    }

    IpcHandler {
        target: "timer"

        function start(duration: string): string {
            const parts = duration.trim().split(/\s+/);
            // Allow a label after the duration: "25m tea"
            for (let i = parts.length; i > 0; i--) {
                const seconds = root.parseDuration(parts.slice(0, i).join(" "));
                if (seconds > 0) {
                    root.startTimer(seconds, parts.slice(i).join(" "));
                    return `Timer started: ${root.describe(seconds)}`;
                }
            }
            return `Invalid duration: ${duration}`;
        }

        function stopwatch(): void {
            root.startStopwatch("");
        }

        function pause(): void {
            root.pause();
        }

        function resume(): void {
            root.resume();
        }

        function toggle(): void {
            root.togglePause();
        }

        function stop(): void {
            root.stop();
        }

        function add(seconds: string): void {
            root.addSeconds(parseInt(seconds) || 60);
        }

        function status(): string {
            if (!root.running)
                return "idle";
            return `${root.mode} ${root.paused ? "paused" : "running"} ${root.timeStr}${root.label ? ` (${root.label})` : ""}`;
        }
    }
}
