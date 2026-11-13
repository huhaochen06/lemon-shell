pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Screenshots: takes over caelestia screenshot's "Screenshot taken / copied / saved" notifications with
// a banner (thumbnail | what happened | edit | save or open folder). Hover it for a big preview; click it
// to open the image. NotificationActivity hands these notifications over (see claims()).
// Region screenshots open straight in the editor by default and don't notify; set the CLI's
// screenshot.regionAction to "notify" or "copy" (~/.config/caelestia/cli.json) to get a banner for them.
Activity {
    id: root

    name: "screenshots"
    enabled: IslandConfig.screenshots.enabled
    priority: IslandConfig.screenshots.priority

    // Whether this island shows the notification instead of the notifications activity
    function claims(n: var): bool {
        return enabled && island.available && island.isFocusScreen && n.appName === "caelestia-cli" && /^Screenshot (taken|copied|saved)/.test(n.summary ?? "") && imagePath(n) !== "";
    }

    function imagePath(n: var): string {
        // Quickshell can consume the image hint and expose it through its icon image provider.
        // Try the resolved image too when a hint is absent or isn't a local file.
        for (const candidate of [n.hints?.["image-path"], n.hints?.image_path, n.image]) {
            let path = String(candidate ?? "");
            let encoded = false;
            if (path.startsWith("image://icon/")) {
                path = path.substring("image://icon/".length);
                encoded = true;
            }
            if (/^file:\/\/(localhost)?\//.test(path)) {
                path = path.replace(/^file:\/\/(localhost)?/, "");
                encoded = true;
            }
            if (encoded) {
                try {
                    path = decodeURIComponent(path);
                } catch (_) {
                    // A literal percent sign can occur in an unescaped provider path.
                }
            }
            if (path.startsWith("/"))
                return path;
        }
        return "";
    }

    function handle(n: var): bool {
        // Do not disturb / an open sidebar: leave it in the list, like other notifications
        if (n.closed || !n.popup)
            return false;
        const path = imagePath(n);
        if (!path)
            return false;
        n.popup = false;
        post({
            key: "screenshot",
            component: shotBanner,
            data: {
                notif: n,
                path: path,
                saved: n.summary.startsWith("Screenshot saved")
            },
            duration: IslandConfig.screenshots.duration
        });
        return true;
    }

    function action(n: var, id: string): var {
        return (n?.actions ?? []).find(a => a.identifier === id) ?? null;
    }

    function edit(d: var): void {
        const a = action(d.notif, "open");
        if (a)
            a.invoke();
        else
            Quickshell.execDetached(["caelestia", "screenshot", "--file", d.path, "--edit"]);
    }

    // Saving notifies again ("Screenshot saved"), which replaces this banner
    function save(d: var): void {
        const a = action(d.notif, "save");
        if (a)
            a.invoke();
        else
            Quickshell.execDetached(["caelestia", "screenshot", "--file", d.path, "--save"]);
    }

    function folder(path: string): string {
        return path.substring(0, path.lastIndexOf("/"));
    }

    Component {
        id: shotBanner

        // thumbnail | title / subtitle | edit | save (or open folder) slot; open: the same, with the
        // whole screenshot below
        ExpandableBanner {
            id: bannerItem

            // Set by the island
            property var banner
            readonly property var d: banner?.data ?? ({})
            readonly property string source: d.path ? `file://${d.path}` : ""
            readonly property real slot: root.island.bannerH
            readonly property string title: d.notif?.summary || qsTr("Screenshot")
            readonly property string subtitle: d.saved ? qsTr("Saved to %1").arg(root.folder(d.path).replace(Paths.home, "~")) : qsTr("Copied to clipboard")

            island: root.island
            compactWidth: Math.min(440, slot * 3 + Tokens.spacing.small * 3 + measure.naturalWidth)
            fullWidth: Math.min(440, root.island.maxWidth)
            compact: header
            // Padded evenly so the buttons and the preview's corners are concentric with the pill's
            full: Component {
                Item {
                    readonly property real inset: root.island.panelPadding
                    readonly property real previewW: width - inset * 2
                    readonly property real aspect: preview.implicitWidth > 0 ? preview.implicitHeight / preview.implicitWidth : 9 / 16

                    implicitHeight: inset + root.island.coverSize + Tokens.spacing.medium + previewBox.height + inset

                    Loader {
                        x: root.island.panelShift
                        y: root.island.panelShift
                        width: parent.width - x * 2
                        height: bannerItem.slot
                        sourceComponent: header
                    }

                    ClipRect {
                        id: previewBox

                        x: parent.inset
                        y: parent.inset + root.island.coverSize + Tokens.spacing.medium
                        width: parent.previewW
                        height: Math.round(Math.min(280, parent.previewW * parent.aspect))
                        radius: root.island.panelInnerRadius
                        color: Colours.palette.m3surfaceContainerHigh

                        BlurImage {
                            id: preview

                            anchors.fill: parent
                            source: bannerItem.source
                            sourceSize.width: Math.round(parent.width * 2)
                            // Fills the box: it has the image's shape unless the height cap kicks in
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }
            }

            // Sizes the compact view to its text
            InkText {
                id: measure

                visible: false
                title: bannerItem.title
                subtitle: bannerItem.subtitle
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: {
                    Quickshell.execDetached(["xdg-open", bannerItem.d.path]);
                    if (bannerItem.banner)
                        root.dismiss(bannerItem.banner.key);
                }
            }

            Component {
                id: header

                RowLayout {
                    spacing: Tokens.spacing.small

                    IslandSlot {
                        size: bannerItem.slot

                        ClipRect {
                            anchors.centerIn: parent
                            implicitWidth: root.island.coverSize
                            implicitHeight: root.island.coverSize
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3secondaryContainer

                            BlurImage {
                                anchors.fill: parent
                                source: bannerItem.source
                                sourceSize.width: root.island.coverSize * 3
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                    }

                    InkText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: root.island.coverSize
                        title: bannerItem.title
                        subtitle: bannerItem.subtitle
                    }

                    IslandButton {
                        Layout.alignment: Qt.AlignVCenter
                        island: root.island
                        icon: "edit"
                        onClicked: {
                            root.edit(bannerItem.d);
                            if (bannerItem.banner)
                                root.dismiss(bannerItem.banner.key);
                        }
                    }

                    IslandSlot {
                        size: bannerItem.slot

                        IslandButton {
                            anchors.centerIn: parent
                            island: root.island
                            icon: bannerItem.d.saved ? "folder_open" : "save"
                            variant: bannerItem.d.saved ? "secondary" : "primary"
                            onClicked: {
                                if (bannerItem.d.saved) {
                                    Quickshell.execDetached(["xdg-open", root.folder(bannerItem.d.path)]);
                                    if (bannerItem.banner)
                                        root.dismiss(bannerItem.banner.key);
                                } else {
                                    root.save(bannerItem.d);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
