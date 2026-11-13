pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.services

// Notifications: posts a banner (icon | summary / body | dismiss) for each new notification popup.
// With "replace popups" on, the island takes the popup over so it doesn't also show in the corner.
// Do not disturb and an open sidebar already suppress popups, so they suppress these banners too.
// Hovering a banner opens it up (if it has more to show): the whole body, and the actions as buttons.
Activity {
    id: root

    // Notifications from before the shell started are restored from disk; only newer ones are new
    property real lastSeen: Date.now()
    property int counter: 0

    function check(): void {
        let newest = lastSeen;
        // New notifications are prepended; walk until we reach ones we've seen
        const fresh = [];
        for (const n of Notifs.list) {
            const t = n.time.getTime();
            if (t <= lastSeen)
                break;
            fresh.push(n);
            newest = Math.max(newest, t);
        }
        lastSeen = newest;

        // Oldest first so they queue in arrival order
        for (let i = fresh.length - 1; i >= 0; i--)
            handle(fresh[i]);
    }

    function handle(n: var): void {
        // Quick Share and AirDrop requests get their own banner with accept / decline (FileTransferActivity)
        if ((n.appName === "Quick Share" || n.appName === "AirDrop") && island.handlesTransfers) {
            n.popup = false;
            return;
        }
        // caelestia screenshot's notifications get the screenshot banner (ScreenshotActivity)
        if (island.screenshotHandler.claims(n) && island.screenshotHandler.handle(n))
            return;
        // popup is false while do not disturb is on or the sidebar is open
        if (!enabled || n.closed || !n.popup)
            return;
        // Show on the focused monitor only, and only where the island can show it; otherwise leave
        // the normal popup alone
        if (!island.available || !island.isFocusScreen)
            return;

        if (IslandConfig.notifications.replacePopups)
            n.popup = false;

        const critical = n.urgency === NotificationUrgency.Critical;
        const low = n.urgency === NotificationUrgency.Low;
        post({
            key: `notif-${++counter}`,
            component: notifBanner,
            data: n,
            priority: priority + (critical ? 30 : low ? -20 : 0),
            duration: IslandConfig.notifications.duration * (critical ? 2 : 1),
            requeue: true,
            valid: () => !n.closed
        });
    }

    name: "notifications"
    enabled: IslandConfig.notifications.enabled
    priority: IslandConfig.notifications.priority

    Connections {
        target: Notifs

        function onListChanged(): void {
            root.check();
        }
    }

    Component {
        id: notifBanner

        // icon slot | summary / body | dismiss slot; open: summary / app, then the whole body and the
        // actions below
        ExpandableBanner {
            id: bannerItem

            // Set by the island
            property var banner
            readonly property var notif: banner?.data ?? null
            readonly property real slot: root.island.bannerH
            readonly property string bodyText: (notif?.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
            readonly property var actions: notif?.actions ?? []
            readonly property string title: notif?.summary || notif?.appName || qsTr("Notification")
            readonly property string compactSubtitle: IslandConfig.notifications.showBody ? (bodyText || notif?.appName || "") : (notif?.appName ?? "")

            island: root.island
            compactWidth: Math.min(420, slot * 2 + Tokens.spacing.small * 2 + measure.naturalWidth)
            // As wide as its widest part (header, the body's longest wrapped line, the action pills), so
            // there's no empty space beside it; never narrower than the compact view
            fullWidth: {
                const maxW = Math.min(440, root.island.maxWidth);
                const inset = root.island.panelPadding;
                const header = slot * 2 + Tokens.spacing.small * 2 + openMeasure.naturalWidth + root.island.panelShift * 2;
                const body = bodyText ? bodyMeasure.contentWidth + inset * 2 : 0;
                const buttons = actions.length > 0 ? actionsMeasure.implicitWidth + inset * 2 : 0;
                return Math.ceil(Math.min(maxW, Math.max(compactWidth, header, body, buttons)));
            }
            // Worth opening: the body doesn't fit on its line, or there are buttons to show
            canOpen: IslandConfig.notifications.expandOnHover && IslandConfig.notifications.showBody && (actions.length > 0 || bodyMetrics.advanceWidth > compactWidth - slot * 2 - Tokens.spacing.small * 2)
            compact: header
            // Padded evenly so the dismiss button and the action pills are concentric with the pill's corners
            full: Component {
                Item {
                    readonly property real inset: root.island.panelPadding

                    implicitHeight: inset + root.island.coverSize + (fullBody.visible ? Tokens.spacing.medium + fullBody.height : 0) + (actionRow.visible ? Tokens.spacing.medium + actionRow.height : 0) + inset

                    Loader {
                        // The header below reads this
                        readonly property bool full: true

                        x: root.island.panelShift
                        y: root.island.panelShift
                        width: parent.width - x * 2
                        height: bannerItem.slot
                        sourceComponent: header
                    }

                    BlurText {
                        id: fullBody

                        x: parent.inset
                        y: parent.inset + root.island.coverSize + Tokens.spacing.medium
                        width: parent.width - parent.inset * 2
                        visible: bannerItem.bodyText.length > 0
                        text: bannerItem.bodyText
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                        maximumLineCount: 8
                        elide: Text.ElideRight
                    }

                    Flow {
                        id: actionRow

                        x: parent.inset
                        y: (fullBody.visible ? fullBody.y + fullBody.height : parent.inset + root.island.coverSize) + Tokens.spacing.medium
                        width: parent.width - parent.inset * 2
                        visible: bannerItem.actions.length > 0
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: bannerItem.actions

                            StyledRect {
                                id: actionButton

                                required property var modelData

                                implicitWidth: actionLabel.implicitWidth + Tokens.padding.large * 2
                                implicitHeight: root.island.coverSize
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondaryContainer

                                StateLayer {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3onSecondaryContainer
                                    onClicked: {
                                        actionButton.modelData.invoke();
                                        if (bannerItem.banner)
                                            root.dismiss(bannerItem.banner.key);
                                    }
                                }

                                BlurText {
                                    id: actionLabel

                                    anchors.centerIn: parent
                                    text: actionButton.modelData.text || actionButton.modelData.identifier
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }
                    }
                }
            }

            TextMetrics {
                id: bodyMetrics

                font: Tokens.font.label.small
                text: bannerItem.bodyText
            }

            // Sizes the compact view to its text
            InkText {
                id: measure

                visible: false
                title: bannerItem.title
                subtitle: bannerItem.compactSubtitle
            }

            // Size the open view: its header text, the body wrapped at the widest it may be, the actions
            InkText {
                id: openMeasure

                visible: false
                title: bannerItem.title
                subtitle: bannerItem.notif?.appName ?? ""
            }

            BlurText {
                id: bodyMeasure

                visible: false
                width: Math.min(440, root.island.maxWidth) - root.island.panelPadding * 2
                text: bannerItem.bodyText
                font: Tokens.font.label.medium
                wrapMode: Text.Wrap
                maximumLineCount: 8
            }

            Row {
                id: actionsMeasure

                visible: false
                spacing: Tokens.spacing.small

                Repeater {
                    model: bannerItem.actions

                    BlurText {
                        required property var modelData

                        width: implicitWidth + Tokens.padding.large * 2
                        text: modelData.text || modelData.identifier
                        font: Tokens.font.label.medium
                    }
                }
            }

            // Closed elsewhere (sidebar, another client): stop showing it
            Connections {
                target: bannerItem.notif

                function onClosedChanged(): void {
                    if (bannerItem.notif?.closed && bannerItem.banner)
                        root.dismiss(bannerItem.banner.key);
                }
            }

            // Click: run the default action if there is exactly one (like the popups), else open the sidebar
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: {
                    const actions = bannerItem.notif?.actions ?? [];
                    if (actions.length === 1)
                        actions[0].invoke();
                    else
                        root.island.screenState.sidebar = true;
                    if (bannerItem.banner)
                        root.dismiss(bannerItem.banner.key);
                }
            }

            // icon | summary / body (or the app, when the body is shown below) | dismiss
            Component {
                id: header

                RowLayout {
                    // In the open view (its loader says so) the body is below, so show where it's from instead
                    readonly property bool full: parent?.full === true

                    spacing: Tokens.spacing.small

                    IslandSlot {
                        size: root.island.bannerH

                        ClipRect {
                            anchors.centerIn: parent
                            implicitWidth: root.island.coverSize
                            implicitHeight: root.island.coverSize
                            radius: Tokens.rounding.full
                            color: bannerItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

                            Image {
                                anchors.fill: parent
                                visible: status === Image.Ready
                                source: bannerItem.notif?.image ? Qt.resolvedUrl(bannerItem.notif.image) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            IconImage {
                                anchors.centerIn: parent
                                visible: !(bannerItem.notif?.image) && (bannerItem.notif?.appIcon ?? "").length > 0
                                implicitSize: Math.round(root.island.coverSize * 0.6)
                                source: visible ? Quickshell.iconPath(bannerItem.notif.appIcon, "image-missing") : ""
                                asynchronous: true
                            }

                            IslandIcon {
                                anchors.fill: parent
                                visible: !(bannerItem.notif?.image) && !(bannerItem.notif?.appIcon)
                                text: bannerItem.notif?.urgency === NotificationUrgency.Critical ? "priority_high" : "notifications"
                                fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                                color: bannerItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }

                    InkText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: root.island.coverSize
                        title: bannerItem.title
                        subtitle: parent.full && bannerItem.bodyText ? (bannerItem.notif?.appName ?? "") : bannerItem.compactSubtitle
                    }

                    IslandSlot {
                        size: root.island.bannerH

                        StyledRect {
                            anchors.centerIn: parent
                            implicitWidth: Math.round(root.island.coverSize * 0.8)
                            implicitHeight: implicitWidth
                            radius: Tokens.rounding.full
                            color: "transparent"

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3onSurface
                                onClicked: {
                                    bannerItem.notif?.close();
                                    if (bannerItem.banner)
                                        root.dismiss(bannerItem.banner.key);
                                }
                            }

                            IslandIcon {
                                anchors.fill: parent
                                text: "close"
                                fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.5)).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }
}
