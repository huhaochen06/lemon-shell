import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Round icon button for expanded views and banners, as big as the artwork (island.coverSize)
StyledRect {
    id: root

    required property var island
    property string icon
    // "secondary" (default), "primary", "danger" or "plain" (no background)
    property string variant: "secondary"
    // Plain buttons can show an on/off state
    property bool active

    signal clicked

    readonly property color bg: variant === "danger" ? Colours.palette.m3errorContainer : variant === "primary" ? Colours.palette.m3primary : variant === "plain" ? "transparent" : active ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer
    readonly property color fg: variant === "danger" ? Colours.palette.m3onErrorContainer : variant === "primary" ? Colours.palette.m3onPrimary : variant === "plain" ? Colours.palette.m3onSurfaceVariant : active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer

    implicitWidth: island.coverSize
    implicitHeight: island.coverSize
    radius: Tokens.rounding.full
    color: bg

    StateLayer {
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: root.fg
        onClicked: root.clicked()
    }

    IslandIcon {
        anchors.fill: parent
        text: root.icon
        animate: true
        fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
        color: root.fg
    }
}
