pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.utils

// Browser downloads in progress: the partial files browsers write into the downloads folder
// (Firefox: <name>.part, Chromium: <name>.crdownload). Their size is polled while any exist, for the
// speed; browsers don't put the total size anywhere a file watcher can see, so there is no percentage.
// Shown by DownloadsActivity.
Singleton {
    id: root

    readonly property bool active: IslandConfig.downloads.enabled
    readonly property string dir: Quickshell.env("XDG_DOWNLOAD_DIR") || `${Paths.home}/Downloads`
    readonly property var suffixes: [".part", ".crdownload"]

    // In progress, oldest first: [{ file, name, size, speed, started }]. Only ones that have been there
    // for a moment, so small downloads that finish straight away don't flash up.
    property var downloads: []
    // Every partial file seen, by file name: { name, size, speed, started, at }
    property var seen: ({})

    // A partial file went away and its finished file is there
    signal finished(string name, string path)

    function finalName(file: string): string {
        for (const s of suffixes)
            if (file.endsWith(s))
                return file.slice(0, -s.length);
        return file;
    }

    function update(text: string): void {
        const now = Date.now();
        const next = {};
        for (const line of text.split("\n")) {
            const [size, file] = line.split("\t");
            if (!file)
                continue;
            const bytes = Number(size) || 0;
            const old = seen[file];
            let speed = 0;
            if (old && now > old.at) {
                const instant = Math.max(0, (bytes - old.size) * 1000 / (now - old.at));
                // Smoothed, so the number doesn't jump about every poll
                speed = old.speed > 0 ? old.speed * 0.6 + instant * 0.4 : instant;
            }
            next[file] = {
                file: file,
                name: finalName(file),
                size: bytes,
                speed: speed,
                started: old?.started ?? now,
                at: now
            };
        }

        // Gone: finished (if the real file is there) or cancelled
        const gone = Object.keys(seen).filter(f => !(f in next)).map(f => `${dir}/${seen[f].name}`);
        if (gone.length > 0 && !finishCheck.running) {
            finishCheck.command = ["sh", "-c", "for f; do [ -s \"$f\" ] && printf '%s\\n' \"$f\"; done; true", "sh", ...gone];
            finishCheck.running = true;
        }

        seen = next;
        downloads = Object.values(next).filter(d => now - d.started >= 1500).sort((a, b) => a.started - b.started);
    }

    function scan(): void {
        if (!scanner.running)
            scanner.running = true;
    }

    FolderListModel {
        id: folder

        folder: root.active ? `file://${root.dir}` : ""
        nameFilters: root.suffixes.map(s => `*${s}`)
        showDirs: false
        showHidden: true
        onCountChanged: root.scan()
    }

    Process {
        id: scanner

        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "(", "-name", "*.part", "-o", "-name", "*.crdownload", ")", "-printf", "%s\\t%f\\n"]
        stdout: StdioCollector {
            onStreamFinished: root.update(text)
        }
    }

    Process {
        id: finishCheck

        stdout: SplitParser {
            onRead: path => root.finished(path.split("/").pop(), path)
        }
    }

    Timer {
        running: root.active && Object.keys(root.seen).length > 0
        repeat: true
        interval: 1000
        onTriggered: root.scan()
    }
}
