import QtQuick

// A banner that opens up on hover. It holds two views, each laid out at its own final size so nothing
// in them reflows while the pill springs between the two:
//   compact  compactWidth x island.bannerH
//   full     fullWidth wide, as tall as it wants (its implicitHeight)
// Opening blurs the compact view out first, then blurs the full view in (and the reverse on closing),
// like the island's expanded view. Make it the root of a banner component.
//
// Hover is the island's own (the pill's HoverHandler), so buttons inside don't steal it: the banner fills
// the pill, so hovering the pill is hovering the banner. Opens after the island's hover delay, closes a
// moment after the pointer leaves. The island keeps a banner up while it's hovered.
Item {
    id: root

    required property var island
    // Whether there's anything more to show
    property bool canOpen: true
    property Component compact
    property Component full
    property real compactWidth
    property real fullWidth
    readonly property real fullHeight: fullLoader.item?.implicitHeight ?? island.bannerH
    // The widths the views are laid out at: a banner is never narrower than the pill it grows from (the
    // island's baseWidth), so a view narrower than that stretches to it rather than being centred in it
    // with empty space at the sides. baseWidth doesn't change when the banner opens, so neither view
    // resizes during the transition.
    readonly property real compactW: Math.min(island.maxWidth, Math.max(compactWidth, island.baseWidth))
    readonly property real fullW: Math.min(island.maxWidth, Math.max(fullWidth, island.baseWidth))

    property bool open: false
    // Set on the first open, so the compact view appears straight away when the banner shows
    property bool wasOpen: false

    readonly property bool hovered: island.islandHovered
    readonly property int outDuration: 140

    function hoverChanged(): void {
        if (hovered && canOpen) {
            closeTimer.stop();
            if (!open)
                openTimer.restart();
        } else {
            openTimer.stop();
            if (open)
                closeTimer.restart();
        }
    }

    implicitWidth: open ? fullW : compactW
    implicitHeight: open ? fullHeight : island.bannerH

    onHoveredChanged: hoverChanged()
    onCanOpenChanged: {
        if (!canOpen)
            open = false;
        hoverChanged();
    }
    onOpenChanged: {
        if (open)
            wasOpen = true;
    }
    // Shown under a pointer that's already resting on the island
    Component.onCompleted: hoverChanged()

    Timer {
        id: openTimer

        interval: IslandConfig.hoverDelay
        onTriggered: root.open = root.canOpen && root.hovered
    }

    // A little slack: the pill shrinking or growing under a still pointer can briefly unhover it
    Timer {
        id: closeTimer

        interval: 150
        onTriggered: {
            if (!root.hovered)
                root.open = false;
        }
    }

    BlurFade {
        id: compactView

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.island.atBottom ? parent.height - height : 0
        width: root.compactW
        height: root.island.bannerH
        transformOrigin: root.island.atBottom ? Item.Bottom : Item.Top

        shown: !root.open
        // Waits for the full view to go first
        inDelay: root.wasOpen ? root.outDuration : 0
        inDuration: root.wasOpen ? 300 : 0
        outDuration: root.outDuration
        hiddenScale: 0.92

        Loader {
            anchors.fill: parent
            sourceComponent: root.compact
        }
    }

    BlurFade {
        id: fullView

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.island.atBottom ? parent.height - height : 0
        width: root.fullW
        height: root.fullHeight
        transformOrigin: root.island.atBottom ? Item.Bottom : Item.Top

        shown: root.open
        // Waits for the compact view to go first
        inDelay: root.outDuration
        inDuration: 340
        outDuration: root.outDuration
        hiddenScale: 0.92

        // Loaded (but hidden) whenever it can open, so its height is known before it does
        Loader {
            id: fullLoader

            width: parent.width
            active: root.canOpen
            sourceComponent: root.full
        }
    }
}
