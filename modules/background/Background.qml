pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
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
        readonly property int surfaceLayer: (contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weActive)) ? WlrLayer.Background : WlrLayer.Bottom

        // A layer change only takes effect on the surface's next commit. With a
        // static Wallpaper Engine desktop nothing may redraw for a long time, leaving
        // this window stuck under linux-wallpaperengine, so force a frame.
        onSurfaceLayerChanged: Qt.callLater(() => behindClock.Window.window?.update())

        // The forced frame above can't help once linux-wallpaperengine's opaque
        // surface covers this one: Hyprland stops sending frame callbacks to
        // occluded surfaces, so a pending background -> bottom layer change may
        // never be committed, hiding the tiled dim, clock and visualiser under the
        // renderer. Remap the window when a renderer surface opens so it is
        // recreated directly on the bottom layer (the `order` layer rule then keeps
        // it above the renderer).
        //
        // Remapping is deferred and debounced: recreating the window while the
        // session is locked (outputs often DPMS-off) or while the async wallpaper
        // Loader is mid-load segfaulted quickshell, killing the lock screen.
        property bool remapPending: false

        function requestRemap(): void {
            remapPending = true;
            remapTimer.restart();
        }

        function tryRemap(): void {
            if (!remapPending || Visibilities.sessionLocked || wallpaper.status === Loader.Loading) {
                if (remapPending && !Visibilities.sessionLocked)
                    remapTimer.restart();
                return;
            }
            remapPending = false;
            if (surfaceLayer !== WlrLayer.Bottom || !visible)
                return;
            visible = false;
            remapShowTimer.restart();
        }

        Timer {
            id: remapTimer
            interval: 1000
            onTriggered: win.tryRemap()
        }

        Timer {
            id: remapShowTimer
            interval: 50
            onTriggered: win.visible = true
        }

        Connections {
            target: Hyprland

            function onRawEvent(event: HyprlandEvent): void {
                if (event.name === "openlayer" && event.data === "linux-wallpaperengine" && win.surfaceLayer === WlrLayer.Bottom)
                    win.requestRemap();
            }
        }

        Connections {
            target: Visibilities

            function onSessionLockedChanged(): void {
                if (!Visibilities.sessionLocked && win.remapPending)
                    remapTimer.restart();
            }
        }

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: surfaceLayer
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
                    let cmd = ["linux-wallpaperengine", "--screen-root", win.modelData.name, "--layer", "bottom", "--fullscreen-pause-only-active"];
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

                // A new command doesn't apply to an already running process, so restart it
                onCommandChanged: {
                    if (running) {
                        running = false;
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
