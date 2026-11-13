pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Browser downloads (DownloadWatcher): live while one is in progress (download | dock | spinner, with a
// badge counting them), expands into each file's size and speed. A banner shows when one finishes:
// click it to open the file, or the folder button for the downloads folder.
Activity {
    id: root

    readonly property var downloads: DownloadWatcher.downloads
    // Rows the expanded view shows before it scrolls
    readonly property int visibleRows: Math.max(1, Math.min(4, downloads.length))

    function size(bytes: real): string {
        if (!(bytes > 0))
            return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${bytes.toFixed(bytes >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
    }

    function rowSubtitle(d: var): string {
        return d.speed > 0 ? `${size(d.size)} · ${size(d.speed)}/s` : size(d.size);
    }

    // slot | name / size · speed | slot. Digits are measured as 0s plus some slack, so the width doesn't
    // twitch as the numbers change
    function rowWidth(d: var): real {
        const text = Math.max(titleMetrics.advanceWidth(d.name), subtitleMetrics.advanceWidth(rowSubtitle(d).replace(/[0-9]/g, "0")) + Tokens.spacing.small);
        return island.bannerH * 2 + Tokens.spacing.small * 2 + Math.ceil(text);
    }

    function isImage(name: string): bool {
        return /\.(png|jpe?g|webp|gif|bmp|avif)$/i.test(name);
    }

    name: "downloads"
    enabled: IslandConfig.downloads.enabled
    priority: IslandConfig.downloads.priority
    live: enabled && downloads.length > 0

    leading: Component {
        Item {
            implicitWidth: root.island.compactSize
            implicitHeight: root.island.compactSize

            IslandIcon {
                anchors.fill: parent
                text: "download"
                fontStyle: Tokens.font.icon.size(Math.round(root.island.compactSize * 0.8)).build()
                color: Colours.palette.m3primary
            }

            StyledRect {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -3
                visible: root.downloads.length > 1
                implicitWidth: Math.max(implicitHeight, countText.implicitWidth + 6)
                implicitHeight: Math.round(root.island.compactSize * 0.55)
                radius: Tokens.rounding.full
                color: Colours.palette.m3tertiary

                BlurText {
                    id: countText

                    anchors.centerIn: parent
                    text: root.downloads.length
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onTertiary
                }
            }
        }
    }

    trailing: Component {
        CircularIndicator {
            implicitSize: root.island.compactSize
            strokeWidth: 2
            running: true
            bgColour: "transparent"
        }
    }

    // One row per download: icon | name / size · speed | spinner
    // Two rows or more get the full corner radius: inset the rows so their artwork and buttons stay
    // concentric with it (one row is a plain pill, which its slots already fit)
    readonly property real listInset: visibleRows > 1 ? island.panelShift : 0
    // As wide as the widest row, so there's no empty space in the middle; never narrower than the pill
    // it grows from (it's centred in that, which would leave space at the sides)
    expandedWidth: {
        const widest = Math.max(0, ...downloads.map(d => rowWidth(d)));
        return Math.ceil(Math.min(420, island.width - island.margin * 2, Math.max(island.baseWidth, widest + listInset * 2)));
    }
    expandedHeight: visibleRows * island.bannerH + listInset * 2
    expanded: Component {
        Item {
            ListView {
                anchors.fill: parent
                anchors.margins: root.listInset
                interactive: root.downloads.length > root.visibleRows
                clip: interactive
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: root.downloads
                    objectProp: "file"
                }

                delegate: Item {
                    id: row

                    required property var modelData

                    width: ListView.view?.width ?? 0
                    height: root.island.bannerH

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: Quickshell.execDetached(["xdg-open", DownloadWatcher.dir])
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.small

                        IslandSlot {
                            size: root.island.bannerH

                            StyledRect {
                                anchors.centerIn: parent
                                implicitWidth: root.island.coverSize
                                implicitHeight: root.island.coverSize
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primaryContainer

                                IslandIcon {
                                    anchors.fill: parent
                                    text: "download"
                                    fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                                    color: Colours.palette.m3onPrimaryContainer
                                }
                            }
                        }

                        InkText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: root.island.coverSize
                            title: row.modelData.name
                            subtitle: root.rowSubtitle(row.modelData)
                        }

                        IslandSlot {
                            size: root.island.bannerH

                            CircularIndicator {
                                anchors.centerIn: parent
                                implicitSize: root.island.coverSize
                                strokeWidth: 3
                                running: true
                                bgColour: "transparent"
                            }
                        }
                    }
                }
            }
        }
    }

    FontMetrics {
        id: titleMetrics

        font: Tokens.font.label.medium
    }

    FontMetrics {
        id: subtitleMetrics

        font: Tokens.font.label.small
    }

    Connections {
        target: DownloadWatcher

        function onFinished(name: string, path: string): void {
            if (!IslandConfig.downloads.finishedBanner)
                return;
            root.quick(`download-${name}`, {
                icon: "download_done",
                image: root.isImage(name) ? path : "",
                title: qsTr("Downloaded"),
                subtitle: name,
                trailingIcon: "folder_open",
                onClick: () => Quickshell.execDetached(["xdg-open", path]),
                onTrailingClick: () => Quickshell.execDetached(["xdg-open", DownloadWatcher.dir])
            }, {
                duration: IslandConfig.quickDuration * 1.5
            });
        }
    }
}
