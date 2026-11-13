import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Standard banner layout for quick activities:
//   [icon in a circle] [title / subtitle] [trailing: icon, text or a progress ring with text]
// The circle can show an image (cropped to fill it) or an app icon instead of the symbol.
// The circle and the trailing item sit in square slots as tall as the pill, so they're concentric with
// its rounded ends. Without a trailing item the text ends with the same padding as the circle has.
Item {
    id: root

    required property var island

    property string icon
    // Shown in the circle instead of the icon (e.g. a keyboard layout code)
    property string leadingText
    // Artwork in the circle instead: an image file / URL, or an icon theme name or path
    property string image
    property string appIcon
    property color circleColour: Colours.palette.m3primaryContainer
    property color iconColour: Colours.palette.m3onPrimaryContainer

    property string title
    property string subtitle

    property string trailingIcon
    property string trailingText
    // 0..1 draws a ring around the trailing text; negative hides it
    property real progress: -1
    property color progressColour: Colours.palette.m3primary
    property color trailingColour: Colours.palette.m3onSurfaceVariant
    property bool trailingClickable

    signal clicked
    signal trailingClicked

    readonly property real slot: island.bannerH
    readonly property bool hasTrailing: trailingIcon.length > 0 || trailingText.length > 0 || progress >= 0
    // Padding between the text and the end when there's no trailing slot: same as around the circle
    readonly property real endPadding: Math.round((slot - island.coverSize) / 2) + Tokens.spacing.small

    implicitWidth: Math.min(420, slot + Tokens.spacing.small + text.naturalWidth + (hasTrailing ? Tokens.spacing.small + slot : endPadding))
    implicitHeight: slot

    TapHandler {
        cursorShape: Qt.PointingHandCursor
        // Both handlers see a tap on the trailing item; leave those to it (e.g. a toggle's switch
        // shouldn't also dismiss the banner)
        onTapped: eventPoint => {
            if (root.trailingClickable && trailingSlot.visible && trailingSlot.contains(trailingSlot.mapFromItem(root, eventPoint.position)))
                return;
            root.clicked();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: root.hasTrailing ? 0 : root.endPadding
        spacing: Tokens.spacing.small

        IslandSlot {
            size: root.slot

            ClipRect {
                anchors.centerIn: parent
                implicitWidth: root.island.coverSize
                implicitHeight: root.island.coverSize
                radius: Tokens.rounding.full
                color: root.circleColour

                BlurImage {
                    id: artwork

                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: root.image ? (root.image.includes("://") ? root.image : Qt.resolvedUrl(`file://${root.image}`)) : ""
                    sourceSize.width: root.island.coverSize * 2
                    sourceSize.height: root.island.coverSize * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                IconImage {
                    id: appIconImage

                    anchors.centerIn: parent
                    visible: !artwork.visible && root.appIcon.length > 0
                    implicitSize: Math.round(root.island.coverSize * 0.62)
                    source: root.appIcon ? (root.appIcon.startsWith("/") ? `file://${root.appIcon}` : Quickshell.iconPath(root.appIcon, "application-x-executable")) : ""
                    asynchronous: true
                }

                IslandIcon {
                    anchors.fill: parent
                    visible: root.leadingText.length === 0 && !artwork.visible && !appIconImage.visible
                    text: root.icon
                    animate: true
                    fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                    color: root.iconColour
                }

                BlurText {
                    anchors.centerIn: parent
                    visible: root.leadingText.length > 0 && !artwork.visible
                    text: root.leadingText
                    font: Tokens.font.label.medium
                    color: root.iconColour
                }
            }
        }

        InkText {
            id: text

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: root.island.coverSize
            title: root.title
            subtitle: root.subtitle
        }

        IslandSlot {
            id: trailingSlot

            visible: root.hasTrailing
            size: root.slot

            CircularProgress {
                anchors.centerIn: parent
                visible: root.progress >= 0
                implicitSize: root.island.coverSize
                value: Math.max(0, root.progress)
                strokeWidth: 3
                padding: 0
                fgColour: root.progressColour
                bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.12)
            }

            IslandIcon {
                anchors.fill: parent
                visible: root.trailingText.length === 0 && root.trailingIcon.length > 0
                text: root.trailingIcon
                fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.6)).build()
                color: root.trailingColour
            }

            BlurText {
                anchors.centerIn: parent
                visible: root.trailingText.length > 0
                text: root.trailingText
                font: root.progress >= 0 ? Tokens.font.label.small : Tokens.font.label.medium
                color: root.trailingColour
            }

            TapHandler {
                enabled: root.trailingClickable
                cursorShape: Qt.PointingHandCursor
                onTapped: root.trailingClicked()
            }
        }
    }
}
