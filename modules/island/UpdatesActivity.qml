pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Package updates (UpdateChecker): a banner when new updates show up (icon | count / names | update).
// Hover it to see the packages; the button (or a click) opens a terminal running the update, which is a
// live task in the island until it's done.
Activity {
    id: root

    name: "updates"
    enabled: IslandConfig.updates.enabled
    priority: IslandConfig.updates.priority

    function summary(list: var): string {
        const names = list.slice(0, 3).map(p => p.name);
        const more = list.length - names.length;
        return more > 0 ? qsTr("%1 and %2 more").arg(names.join(", ")).arg(more) : names.join(", ");
    }

    function announce(): void {
        if (!ready || !enabled || !island.isFocusScreen || UpdateChecker.count === 0)
            return;
        post({
            key: "updates",
            component: updatesBanner,
            duration: IslandConfig.quickDuration * 2.5
        });
    }

    Connections {
        target: UpdateChecker

        function onChecked(fresh: var): void {
            if (fresh.length > 0)
                root.announce();
        }

        function onShowRequested(): void {
            root.announce();
        }
    }

    Component {
        id: updatesBanner

        // icon | count / names | update slot; open: the same, with the packages below
        ExpandableBanner {
            id: bannerItem

            // Set by the island
            property var banner
            readonly property real slot: root.island.bannerH
            readonly property var packages: UpdateChecker.packages
            readonly property int shownRows: Math.min(8, packages.length)
            readonly property real rowH: Math.ceil(lineMetrics.height) + 2
            readonly property string title: packages.length === 1 ? qsTr("1 update available") : qsTr("%1 updates available").arg(packages.length)
            readonly property string subtitle: root.summary(packages)

            island: root.island
            compactWidth: Math.min(420, slot * 2 + Tokens.spacing.small * 2 + measure.naturalWidth)
            fullWidth: Math.min(420, root.island.maxWidth)
            compact: header
            // Padded evenly so the update button is concentric with the pill's corner
            full: Component {
                Item {
                    readonly property real inset: root.island.panelPadding

                    implicitHeight: inset + root.island.coverSize + Tokens.spacing.medium + list.height + inset

                    Loader {
                        x: root.island.panelShift
                        y: root.island.panelShift
                        width: parent.width - x * 2
                        height: bannerItem.slot
                        sourceComponent: header
                    }

                    // Name on the left, the new version on the right
                    Column {
                        id: list

                        x: parent.inset
                        y: parent.inset + root.island.coverSize + Tokens.spacing.medium
                        width: parent.width - parent.inset * 2

                        Repeater {
                            model: bannerItem.packages.slice(0, bannerItem.shownRows)

                            Item {
                                id: pkg

                                required property var modelData

                                width: parent.width
                                height: bannerItem.rowH

                                BlurText {
                                    anchors.left: parent.left
                                    anchors.right: version.left
                                    anchors.rightMargin: Tokens.spacing.medium
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pkg.modelData.aur ? `${pkg.modelData.name}  ·  AUR` : pkg.modelData.name
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                BlurText {
                                    id: version

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width * 0.5)
                                    text: `${pkg.modelData.from} → ${pkg.modelData.to}`
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    elide: Text.ElideLeft
                                }
                            }
                        }

                        BlurText {
                            visible: bannerItem.packages.length > bannerItem.shownRows
                            height: bannerItem.rowH
                            verticalAlignment: Text.AlignVCenter
                            text: qsTr("and %1 more").arg(bannerItem.packages.length - bannerItem.shownRows)
                            font: Tokens.font.label.small
                            color: Colours.palette.m3outline
                        }
                    }
                }
            }

            FontMetrics {
                id: lineMetrics

                font: Tokens.font.label.small
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
                    UpdateChecker.runUpdate();
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

                        StyledRect {
                            anchors.centerIn: parent
                            implicitWidth: root.island.coverSize
                            implicitHeight: root.island.coverSize
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3secondaryContainer

                            IslandIcon {
                                anchors.fill: parent
                                text: "system_update"
                                fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                                color: Colours.palette.m3onSecondaryContainer
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

                    IslandSlot {
                        size: bannerItem.slot

                        IslandButton {
                            anchors.centerIn: parent
                            island: root.island
                            icon: "download"
                            variant: "primary"
                            onClicked: {
                                UpdateChecker.runUpdate();
                                if (bannerItem.banner)
                                    root.dismiss(bannerItem.banner.key);
                            }
                        }
                    }
                }
            }
        }
    }
}
