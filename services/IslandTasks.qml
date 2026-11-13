pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services

// Live activities and banners for the dynamic island, driven from outside the shell over IPC
// (modules/island/IpcActivity.qml shows them). scripts/island wraps this for shell scripts:
//   island run -- cargo build            live while the command runs, then a done / failed banner
//   island notify "Backup done" "12 GB"  a banner
//
// Raw IPC (each <json> is an object; plain text is taken as the title):
//   qs -c caelestia ipc call island banner <title> <subtitle> <icon>
//   qs -c caelestia ipc call island post <json>           banner
//   qs -c caelestia ipc call island start <id> <json>     start (or replace) a live task
//   qs -c caelestia ipc call island update <id> <json>    merge into a task (starts it if missing)
//   qs -c caelestia ipc call island progress <id> <0..1 | 45%>
//   qs -c caelestia ipc call island end <id> [<json>]     end it, with an optional final banner
//   qs -c caelestia ipc call island dismiss <id>          end it without a banner
//   qs -c caelestia ipc call island list                  the live tasks, as JSON
//
// Task fields:
//   title, subtitle
//   icon       Material Symbols name (default "terminal"); or appIcon (an icon theme name or path),
//              or image (a file path) for artwork
//   colour     primary (default), secondary, tertiary or error
//   progress   0..1 draws a ring; -1 a spinner; leave it out to show the elapsed time
//   text       short text for the trailing wing instead (e.g. "3/12")
//   priority   against other activities (default from the island settings)
//   command    run when the task is clicked (a string for sh -c, or an argv array)
//   window     Hyprland window address; clicking focuses it (when there's no command)
//   actions    up to two buttons in the expanded view: [{ icon, command }]
//   pid        end the task (silently) when this process exits
//   ttl        end the task when it hasn't been updated for this many seconds
// Banner fields: title, subtitle, icon / appIcon / image, colour, progress, trailingIcon, trailingText,
//   status ("success" / "error": picks the icon and colour), duration (seconds), command, window,
//   quietIfFocused (skip the banner while `window` is focused), urgent (raises its priority), key
//   (banners with the same key replace each other)
Singleton {
    id: root

    // Live tasks, in the order they started. Each update replaces the task with a new object.
    property var tasks: []

    // The island on the focused monitor posts these (IpcActivity)
    signal bannerRequested(var data)
    // A task ended (by `end`, `dismiss`, its process exiting or its ttl running out)
    signal taskEnded(var task)

    function parse(json: string): var {
        if (!json || !json.trim())
            return {};
        try {
            const v = JSON.parse(json);
            if (v && typeof v === "object" && !Array.isArray(v))
                return v;
            return {
                title: String(v)
            };
        } catch (e) {
            return {
                title: json
            };
        }
    }

    function parseProgress(value: var): var {
        if (value === undefined || value === null || value === "")
            return undefined;
        if (typeof value === "string") {
            const s = value.trim();
            const n = parseFloat(s);
            if (isNaN(n))
                return undefined;
            return s.endsWith("%") ? Math.max(0, Math.min(1, n / 100)) : root.parseProgress(n);
        }
        const n = Number(value);
        if (isNaN(n))
            return undefined;
        return n < 0 ? -1 : Math.min(1, n);
    }

    // Normalises incoming fields
    function clean(data: var): var {
        const d = Object.assign({}, data ?? {});
        delete d.id;
        if ("progress" in d) {
            const p = parseProgress(d.progress);
            if (p === undefined)
                delete d.progress;
            else
                d.progress = p;
        }
        if (typeof d.window === "string")
            d.window = d.window.replace(/^0x/, "");
        if (d.pid !== undefined)
            d.pid = parseInt(d.pid) || 0;
        if (d.ttl !== undefined)
            d.ttl = Number(d.ttl) || 0;
        if (d.actions !== undefined && !Array.isArray(d.actions))
            delete d.actions;
        for (const k of ["title", "subtitle", "text", "trailingText"])
            if (d[k] !== undefined && d[k] !== null)
                d[k] = String(d[k]);
        return d;
    }

    function find(id: string): var {
        return tasks.find(t => t.id === id) ?? null;
    }

    function startTask(id: string, data: var): var {
        const now = Date.now();
        const old = find(id);
        const task = Object.assign({
            title: id
        }, clean(data), {
            id: id,
            started: old?.started ?? now,
            updated: now
        });
        tasks = old ? tasks.map(t => t.id === id ? task : t) : [...tasks, task];
        return task;
    }

    function updateTask(id: string, data: var): var {
        const old = find(id);
        if (!old)
            return startTask(id, data);
        const task = Object.assign({}, old, clean(data), {
            id: id,
            started: old.started,
            updated: Date.now()
        });
        tasks = tasks.map(t => t.id === id ? task : t);
        return task;
    }

    // Ends a task. With a title or subtitle in `data`, a banner follows (defaulting to the task's icon
    // and window, so clicking it goes back to where the task ran).
    function endTask(id: string, data: var): bool {
        const old = find(id);
        if (old) {
            tasks = tasks.filter(t => t.id !== id);
            taskEnded(old);
        }
        const d = clean(data);
        if (d.title || d.subtitle) {
            postBanner(Object.assign({
                key: `ipc-task-${id}`,
                icon: d.status ? undefined : old?.icon,
                appIcon: d.status ? undefined : old?.appIcon,
                image: old?.image,
                window: old?.window,
                colour: old?.colour
            }, d));
        }
        return old !== null;
    }

    function postBanner(data: var): void {
        const d = clean(data);
        if (!d.title && !d.subtitle)
            return;
        if (d.quietIfFocused && d.window && isFocused(d.window))
            return;
        // The island on the focused monitor shows it; without one, fall back to a toast
        if (IslandState.covers("ipc"))
            bannerRequested(d);
        else
            Toaster.toast(d.title ?? "", d.subtitle ?? "", d.icon || (d.status === "error" ? "error" : d.status === "success" ? "check_circle" : "info"));
    }

    function isFocused(address: string): bool {
        return (Hypr.activeToplevel?.address ?? "").replace(/^0x/, "") === address.replace(/^0x/, "");
    }

    function focusWindow(address: string): void {
        const a = address.replace(/^0x/, "");
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${a}" })` : `focuswindow address:0x${a}`);
    }

    function run(command: var): void {
        if (Array.isArray(command) && command.length > 0)
            Quickshell.execDetached(command.map(c => String(c)));
        else if (typeof command === "string" && command.trim())
            Quickshell.execDetached(["sh", "-c", command]);
    }

    // Click on a task or banner: its command, else the window it came from
    function activate(item: var): bool {
        if (item?.command) {
            run(item.command);
            return true;
        }
        if (item?.window) {
            focusWindow(item.window);
            return true;
        }
        return false;
    }

    // Ends tasks whose process exited or whose ttl ran out
    Timer {
        running: root.tasks.some(t => t.pid > 0 || t.ttl > 0)
        repeat: true
        interval: 3000
        onTriggered: {
            const now = Date.now();
            for (const t of root.tasks)
                if (t.ttl > 0 && now - t.updated > t.ttl * 1000)
                    root.endTask(t.id, {});
            const pids = root.tasks.filter(t => t.pid > 0).map(t => String(t.pid));
            if (pids.length > 0 && !pidCheck.running) {
                pidCheck.command = ["sh", "-c", "for p; do [ -d /proc/$p ] || echo $p; done", "sh", ...pids];
                pidCheck.running = true;
            }
        }
    }

    Process {
        id: pidCheck

        stdout: SplitParser {
            onRead: line => {
                const pid = parseInt(line);
                for (const t of root.tasks.filter(t => t.pid === pid))
                    root.endTask(t.id, {});
            }
        }
    }

    IpcHandler {
        target: "island"

        function banner(title: string, subtitle: string, icon: string): void {
            root.postBanner({
                title: title,
                subtitle: subtitle,
                icon: icon
            });
        }

        function post(json: string): string {
            const d = root.parse(json);
            if (!d.title && !d.subtitle)
                return "error: a banner needs a title or subtitle";
            root.postBanner(d);
            return "ok";
        }

        function start(id: string, json: string): string {
            if (!id)
                return "error: missing id";
            root.startTask(id, root.parse(json));
            return "ok";
        }

        function update(id: string, json: string): string {
            if (!id)
                return "error: missing id";
            root.updateTask(id, root.parse(json));
            return "ok";
        }

        function progress(id: string, value: string): string {
            const p = root.parseProgress(value);
            if (p === undefined)
                return `error: invalid progress: ${value}`;
            root.updateTask(id, {
                progress: p
            });
            return "ok";
        }

        function end(id: string, json: string): string {
            return root.endTask(id, root.parse(json)) ? "ok" : "not running";
        }

        function dismiss(id: string): string {
            return root.endTask(id, {}) ? "ok" : "not running";
        }

        function clear(): void {
            for (const t of root.tasks)
                root.endTask(t.id, {});
        }

        function list(): string {
            return JSON.stringify(root.tasks);
        }
    }
}
