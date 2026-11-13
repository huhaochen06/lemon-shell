pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Config
import Caelestia.State
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import Caelestia

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData
        readonly property alias wallpaperLoader: wallpaper

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // Always on the bottom layer, even for static wallpapers. Switching layers when Wallpaper
        // Engine starts could leave the change uncommitted once the renderer covered this surface,
        // and remapping the window to work around that crashed quickshell. The `order` layer rule
        // keeps this window (tiled dim, clock, visualiser) above linux-wallpaperengine.
        WlrLayershell.layer: WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weActive) ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        ShellState.ComponentRef {
            screen: win.screen
            slot: "background"
            component: win
        }

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled
                opacity: (item && item.weActive) ? 0 : 1

                sourceComponent: Wallpaper {
                    screen: win.modelData
                }
            }

            // Dim the wallpaper while the workspace has tiled windows on it
            Rectangle {
                id: tiledDim

                readonly property bool hasTiled: Hypr.monitorFor(win.modelData)?.activeWorkspace?.toplevels?.values.some(t => !t.lastIpcObject?.floating) ?? false

                anchors.fill: parent
                z: 1
                color: "black"
                opacity: hasTiled && wallpaper.active ? Config.background.wallpaperTiledDim : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Process {
                id: weProc
                property string weDir: wallpaper.item ? wallpaper.item.weDir : ""
                property bool weActive: wallpaper.item ? wallpaper.item.weActive : false

                readonly property string snapshotPath: `${Paths.cache}/wallpaper-snapshots/${Wallpapers.djb2_hash(weDir + ":" + win.modelData.name + ":" + win.modelData.width + "x" + win.modelData.height)}.png`

                onSnapshotPathChanged: {
                    Qt.callLater(() => applySnapshotTimer.restart());
                }
                Component.onCompleted: CUtils.mkdirp(`${Paths.cache}/wallpaper-snapshots`)

                command: {
                    // pdeathsig kills the renderer if the shell dies, instead of leaving it running
                    let cmd = ["setpriv", "--pdeathsig", "KILL", "--", "linux-wallpaperengine", "--screen-root", win.modelData.name, "--layer", "bottom", "--fullscreen-pause-only-active"];
                    if (Wallpapers.weSilent) {
                        cmd.push("--silent");
                    } else {
                        cmd.push("--volume", Math.round(Wallpapers.weVolume * 100).toString());
                    }
                    cmd.push("--screenshot", snapshotPath, "--screenshot-delay", "60");
                    cmd.push(weDir);
                    return cmd;
                }
                running: shouldRun()

                function shouldRun(): bool {
                    // Terminate the renderer to release its GPU resources while gaming.
                    // Pausing playback leaves the process and its VRAM allocations alive.
                    return weActive && weDir !== "" && contentItem.Config.background.wallpaperEnabled && !RuntimeState.gameMode;
                }

                // A new command doesn't apply to an already running process, so restart it. Some
                // scenes ignore SIGTERM, so make sure the old renderer is gone.
                onCommandChanged: {
                    if (running) {
                        const pid = processId;
                        running = false;
                        if (pid > 0)
                            Quickshell.execDetached(["sh", "-c", '[ "$(cat /proc/$1/comm 2>/dev/null)" = linux-wallpaper ] || exit 0; kill "$1"; sleep 2; kill -9 "$1" 2>/dev/null', "sh", String(pid)]);
                        running = Qt.binding(shouldRun);
                    }
                }
            }

            // Hyprpaper owns the static desktop independently of this shell.
            FileView {
                path: weProc.snapshotPath
                watchChanges: true
                printErrors: false
                onFileChanged: applySnapshotTimer.restart()
            }

            Timer {
                id: applySnapshotTimer
                interval: 300
                onTriggered: {
                    if (weProc.weActive && CUtils.fileExists(weProc.snapshotPath)) {
                        if (applySnapshotProc.running) {
                            restart();
                        } else {
                            applySnapshotProc.running = true;
                        }
                    }
                }
            }

            Process {
                id: applySnapshotProc
                command: ["python3", Quickshell.shellPath("scripts/set-wallpaper-snapshot"), win.modelData.name, weProc.snapshotPath]
                onExited: (exitCode, exitStatus) => {
                    if (exitCode !== 0)
                        console.warn("Failed to set Hyprpaper snapshot for", win.modelData.name);
                }
            }

            // Some scenes block graceful shutdown while their surface is hidden.
            Timer {
                interval: 2000
                running: RuntimeState.gameMode && weProc.processId > 0
                onTriggered: weProc.signal(9)
            }

            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
                z: 2
            }
        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: Config.background.desktopClock.enabled

            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness)

            state: Config.background.desktopClock.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y
            }
        }
    }
}
