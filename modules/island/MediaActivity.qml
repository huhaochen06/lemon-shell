pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.widgets
import qs.services
import qs.modules.dashboard as Dashboard

// Media: live while something plays (cover art | dock | visualiser), expands into the dashboard media
// view, and posts a banner when the track changes.
Activity {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property bool playing: player?.isPlaying ?? false
    // Stays true for a grace period after pausing so track changes don't make the island flicker
    property bool mediaActive: playing

    // Identifies the current track; a change posts the banner
    readonly property string trackKey: player ? `${player.trackTitle}\n${player.trackArtist}` : ""
    property string lastBannerKey

    name: "media"
    enabled: IslandConfig.media.enabled
    priority: IslandConfig.media.priority
    live: enabled && mediaActive && player !== null

    leading: Component {
        CoverArt {
            implicitWidth: root.island.compactSize
            implicitHeight: root.island.compactSize
        }
    }

    trailing: Component {
        Visualiser {
            size: root.island.compactSize
            playing: root.playing
        }
    }

    expanded: Component {
        Dashboard.Media {
            screenState: root.island.screenState
        }
    }
    expandedWidth: Math.min(Tokens.sizes.dashboard.mediaTabWidth, island.width - island.margin * 2)
    expandedHeight: Tokens.sizes.dashboard.mediaTabHeight

    onPlayingChanged: {
        if (playing) {
            idleTimer.stop();
            mediaActive = true;
        } else {
            idleTimer.restart();
        }
    }

    // Show the first track too when media becomes live, but not again for the same track
    onLiveChanged: if (live)
        bannerDebounce.restart()
    onTrackKeyChanged: bannerDebounce.restart()

    ServiceRef {
        service: root.live ? Audio.cava : null
    }

    Timer {
        id: idleTimer

        interval: IslandConfig.media.keepAfterPause * 1000
        onTriggered: {
            if (root.playing)
                return;
            // Don't pull the expanded view away from under the cursor
            if (root.island.primary === root && (root.island.mode === "peek" || root.island.mode === "expanded"))
                restart();
            else
                root.mediaActive = false;
        }
    }

    // Metadata usually arrives in pieces (title, then artist, ...), so wait for it to settle
    Timer {
        id: bannerDebounce

        interval: 200
        onTriggered: {
            if (!root.live || !IslandConfig.media.trackBanner || root.trackKey === root.lastBannerKey)
                return;
            root.lastBannerKey = root.trackKey;
            root.post({
                key: "media-track",
                component: trackBanner,
                duration: IslandConfig.media.bannerDuration,
                // A stale track banner isn't worth showing later
                queueable: false
            });
        }
    }

    Component {
        id: trackBanner

        // cover slot | title / artist | visualiser slot
        Item {
            readonly property real slot: root.island.bannerH

            implicitWidth: slot * 2 + Tokens.spacing.small * 2 + text.naturalWidth
            implicitHeight: slot

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: root.island.expandActivity(root)
            }

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                IslandSlot {
                    size: root.island.bannerH

                    CoverArt {
                        anchors.centerIn: parent
                        implicitWidth: root.island.coverSize
                        implicitHeight: root.island.coverSize
                    }
                }

                InkText {
                    id: text

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: root.player?.trackTitle || qsTr("Unknown title")
                    subtitle: root.player?.trackArtist ?? ""
                }

                IslandSlot {
                    size: root.island.bannerH

                    Visualiser {
                        anchors.centerIn: parent
                        size: root.island.coverSize
                        playing: root.playing
                    }
                }
            }
        }
    }
}
