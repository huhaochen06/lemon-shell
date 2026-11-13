import QtQuick
import qs.services

// Base type for dynamic island activities. Subclasses live in modules/island/*Activity.qml and are
// instantiated by DynamicIsland.qml (add new ones to its `activities` list).
//
// An activity can be:
//  - live: ongoing (music playing, recording). The highest priority live activity fills the pill's
//    wings with `leading` / `trailing`; up to two more are shown as small `bubble` circles beside it.
//    If `expanded` is set, hovering a wing expands the island into it.
//  - a source of banners: brief messages (track changed, volume changed, notification) posted with
//    post(). Banners go through the island's priority queue.
//
// Components are created in the activity's own context, so they can refer to the activity (and its
// `island`) by id. Banner components get the banner object in a `banner` property if they declare one.
Item {
    id: root

    // Set by DynamicIsland
    required property var island

    property string name
    property bool enabled: true
    // Higher wins, both for the wings and in the banner queue
    property int priority: 0

    // Live presentation
    property bool live: false
    property Component leading
    property Component trailing
    property Component bubble: leading
    // Width of each wing; the pill grows by the wider of the two on both sides so the dock stays put
    property real leadingWidth: island.wingW
    property real trailingWidth: island.wingW

    // Optional hover-to-expand view
    property Component expanded
    property real expandedWidth: 0
    property real expandedHeight: island.bannerH
    readonly property bool expandable: expanded !== null && expandedWidth > 0

    // Post a banner. Options:
    //   key        banners with the same key replace each other (and update in place if showing)
    //   component  the content; its implicit size sets the pill size
    //   priority   defaults to the activity's priority
    //   duration   seconds on screen (hovering holds it)
    //   data       anything the component needs (exposed as banner.data)
    //   requeue    if interrupted by a higher priority banner, show it again afterwards
    //   queueable  if it can't show right away, wait in the queue instead of being dropped
    //   urgent     shows even over an open expanded view (which otherwise holds banners back)
    //   keyboard   the island takes the keyboard while it shows (for a text field)
    //   valid      function; a queued banner is skipped if it returns false by its turn
    function post(options: var): void {
        island.post(Object.assign({
            activity: root,
            priority: root.priority,
            duration: 3,
            requeue: false,
            queueable: true
        }, options));
    }

    function dismiss(key: string): void {
        island.dismiss(key);
    }

    // Post a standard quick banner (IconBanner) described by `data`:
    //   icon, leadingText, image, appIcon, circleColour, iconColour, title, subtitle,
    //   trailingIcon, trailingText, progress (0..1 ring), progressColour, trailingColour,
    //   onClick(), onTrailingClick() (makes the trailing item clickable)
    // Clicking a banner without onClick dismisses it. Global events (battery, network, ...) only show on
    // the focused monitor's island, and nothing shows until the startup grace period is over.
    function quick(key: string, data: var, options: var): void {
        if (!ready || !enabled || !island.isFocusScreen)
            return;
        post(Object.assign({
            key: key,
            component: quickBanner,
            data: data,
            duration: IslandConfig.quickDuration
        }, options ?? {}));
    }

    // Services report their initial state just after startup; activities ignore changes until then
    property bool ready: false

    visible: false

    Timer {
        interval: 2500
        running: true
        onTriggered: root.ready = true
    }

    Component {
        id: quickBanner

        IconBanner {
            id: quickItem

            // Set by the island
            property var banner
            readonly property var d: banner?.data ?? ({})

            island: root.island
            icon: d.icon ?? ""
            leadingText: d.leadingText ?? ""
            image: d.image ?? ""
            appIcon: d.appIcon ?? ""
            circleColour: d.circleColour ?? Colours.palette.m3primaryContainer
            iconColour: d.iconColour ?? Colours.palette.m3onPrimaryContainer
            title: d.title ?? ""
            subtitle: d.subtitle ?? ""
            trailingIcon: d.trailingIcon ?? ""
            trailingText: d.trailingText ?? ""
            progress: d.progress ?? -1
            progressColour: d.progressColour ?? Colours.palette.m3primary
            trailingColour: d.trailingColour ?? Colours.palette.m3onSurfaceVariant
            trailingClickable: typeof d.onTrailingClick === "function"

            onClicked: {
                if (typeof d.onClick === "function")
                    d.onClick();
                if (quickItem.banner)
                    root.dismiss(quickItem.banner.key);
            }
            onTrailingClicked: d.onTrailingClick()
        }
    }
}
