pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.services
import qs.utils
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Wallpaper Engine")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            SliderRow {
                first: true
                icon: "volume_up"
                label: qsTr("Volume")
                valueLabel: Math.round(Wallpapers.weVolume * 100) + "%"
                value: Wallpapers.weVolume
                onMoved: v => Wallpapers.weVolume = v
            }

            ToggleRow {
                last: true
                text: qsTr("Mute")
                checked: Wallpapers.weSilent
                onToggled: Wallpapers.weSilent = checked
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            StyledText {
                text: qsTr("Playlist")
                font: Tokens.font.title.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Choose wallpapers below, then start automatic rotation. Your playlist is saved.")
                wrapMode: Text.WordWrap
                font: Tokens.font.body.small
            }

            ToggleRow {
                first: true
                text: qsTr("Automatic rotation")
                subtext: qsTr("%1 available wallpapers selected").arg(Wallpapers.availablePlaylist.length)
                checked: Wallpapers.wePlaylistEnabled
                enabled: Wallpapers.availablePlaylist.length > 0 || checked
                onToggled: {
                    if (checked) Wallpapers.startPlaylist();
                    else Wallpapers.wePlaylistEnabled = false;
                }
            }

            ToggleRow {
                last: true
                text: qsTr("Shuffle")
                subtext: qsTr("Avoid playing the same wallpaper twice in a row")
                checked: Wallpapers.wePlaylistShuffle
                onToggled: Wallpapers.wePlaylistShuffle = checked
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Change every (minutes)")
                    font: Tokens.font.body.small
                }

                StyledSpinBox {
                    from: 1
                    to: 1440
                    stepSize: 1
                    value: Wallpapers.wePlaylistMinutes
                    onValueModified: Wallpapers.wePlaylistMinutes = Math.round(value)
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                TextButton {
                    text: qsTr("Next wallpaper")
                    disabled: !Wallpapers.availablePlaylist.length
                    onClicked: Wallpapers.nextPlaylistWallpaper()
                }
                TextButton {
                    text: qsTr("Select all")
                    onClicked: Wallpapers.wePlaylist = Wallpapers.list
                        .filter(w => Wallpapers.getCategoryFor(w) === "Wallpaper Engine")
                        .map(w => w.path).sort()
                }
                TextButton {
                    text: qsTr("Clear playlist")
                    disabled: !Wallpapers.wePlaylist.length
                    onClicked: {
                        Wallpapers.wePlaylistEnabled = false;
                        Wallpapers.wePlaylist = [];
                    }
                }
            }
        }

        GridLayout {
            id: wallpaperGrid

            Layout.fillWidth: true
            columns: Math.max(1, Math.min(Config.nexus.wallpapersPerRow, Math.floor((width + columnSpacing) / (180 + columnSpacing))))
            uniformCellWidths: true
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: {
                    let walls = Wallpapers.list.filter(w => Wallpapers.getCategoryFor(w) === "Wallpaper Engine");
                    
                    walls.sort((a, b) => a.name.localeCompare(b.name));
                    return walls;
                }

                ColumnLayout {
                    id: entry
                    required property FileSystemEntry modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    opacity: modelData ? 1 : 0
                    enabled: !!modelData
                    spacing: Tokens.spacing.extraSmall

                    WallItem {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1

                        source: entry.modelData ? Wallpapers.getThumbnailPath(entry.modelData.path) : ""
                        realPath: entry.modelData ? entry.modelData.path : ""
                        text: {
                            if (!entry.modelData) return "";
                            let content = CUtils.readFile(entry.modelData.path);
                            try {
                                let json = JSON.parse(content);
                                if (json.title) return json.title;
                            } catch (e) {}
                            return entry.modelData.parentDir.split('/').pop();
                        }
                        onClicked: {
                            Wallpapers.setWallpaper(entry.modelData.path);
                        }
                    }

                    ToggleRow {
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        first: true
                        last: true
                        text: qsTr("In playlist")
                        checked: !!entry.modelData && Wallpapers.wePlaylist.includes(entry.modelData.path)
                        onToggled: {
                            if (entry.modelData) Wallpapers.togglePlaylistPath(entry.modelData.path);
                        }
                    }
                }
            }
        }
    }
}
