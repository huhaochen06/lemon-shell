pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Scripts: live activities and banners sent over IPC (services/IslandTasks.qml, scripts/island).
// Live while a task runs: icon | dock | progress ring, spinner, text or the elapsed time. The newest
// (or highest priority) task takes the wings, with a badge counting the others; the expanded view
// lists them all with their buttons. Hover a row's trailing slot to dismiss it.
Activity {
    id: root

    readonly property var tasks: IslandTasks.tasks
    // Gets the wings: highest priority, then the newest
    readonly property var task: tasks.length === 0 ? null : tasks.slice().sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0) || b.started - a.started)[0]
    property real now: Date.now()
    // What the wings show: see trailingKind()
    readonly property string kind: trailingKind(task)
    // For measuring rows: the widest digit, so the width doesn't change every second as the time ticks
    readonly property string widestDigit: {
        let widest = "0";
        for (let d = 1; d <= 9; d++)
            if (subtitleMetrics.advanceWidth(`${d}`) > subtitleMetrics.advanceWidth(widest))
                widest = `${d}`;
        return widest;
    }
    readonly property string trailingString: kind === "text" ? task.text : kind === "elapsed" ? elapsed(task) : ""

    // Rows the expanded view shows before it scrolls
    readonly property int visibleRows: Math.max(1, Math.min(4, tasks.length))
    property int counter: 0

    // What the trailing wing shows for a task
    function trailingKind(t: var): string {
        if (!t)
            return "";
        if (t.text)
            return "text";
        if (t.progress !== undefined)
            return t.progress < 0 ? "spinner" : "progress";
        return "elapsed";
    }

    function rowSubtitle(t: var): string {
        const parts = [];
        if (t?.subtitle)
            parts.push(t.subtitle);
        if (t?.text)
            parts.push(t.text);
        else if (trailingKind(t) === "progress")
            parts.push(`${Math.round(t.progress * 100)}%`);
        parts.push(elapsed(t));
        return parts.join(" · ");
    }

    // A row's natural width: padding | icon | text | buttons (actions, then the indicator or close) | padding
    function rowWidth(t: var): real {
        const text = Math.max(titleMetrics.advanceWidth(t?.title ?? ""), subtitleMetrics.advanceWidth(rowSubtitle(t).replace(/[0-9]/g, widestDigit)));
        const buttons = Math.min(2, (t?.actions ?? []).length) + 1;
        const gap = Tokens.spacing.small;
        return island.slotPadding * 2 + island.coverSize + gap + Math.ceil(text) + buttons * (gap + island.coverSize);
    }

    function elapsed(t: var): string {
        const s = Math.max(0, Math.floor((now - (t?.started ?? now)) / 1000));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const sec = `${s % 60}`.padStart(2, "0");
        return h > 0 ? `${h}:${`${m}`.padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    function accent(name: string): color {
        switch (name) {
        case "secondary":
            return Colours.palette.m3secondary;
        case "tertiary":
            return Colours.palette.m3tertiary;
        case "error":
            return Colours.palette.m3error;
        default:
            return Colours.palette.m3primary;
        }
    }

    function container(name: string): color {
        switch (name) {
        case "secondary":
            return Colours.palette.m3secondaryContainer;
        case "tertiary":
            return Colours.palette.m3tertiaryContainer;
        case "error":
            return Colours.palette.m3errorContainer;
        default:
            return Colours.palette.m3primaryContainer;
        }
    }

    function onContainer(name: string): color {
        switch (name) {
        case "secondary":
            return Colours.palette.m3onSecondaryContainer;
        case "tertiary":
            return Colours.palette.m3onTertiaryContainer;
        case "error":
            return Colours.palette.m3onErrorContainer;
        default:
            return Colours.palette.m3onPrimaryContainer;
        }
    }

    name: "ipc"
    enabled: IslandConfig.ipc.enabled
    priority: task?.priority ?? IslandConfig.ipc.priority
    live: enabled && task !== null

    Timer {
        running: root.live
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    leading: Component {
        Item {
            implicitWidth: root.island.compactSize
            implicitHeight: root.island.compactSize

            TaskIcon {
                anchors.fill: parent
                task: root.task
                size: root.island.compactSize
                plain: true
            }

            // The other tasks
            StyledRect {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -3
                visible: root.tasks.length > 1
                implicitWidth: Math.max(implicitHeight, countText.implicitWidth + 6)
                implicitHeight: Math.round(root.island.compactSize * 0.55)
                radius: Tokens.rounding.full
                color: Colours.palette.m3tertiary

                BlurText {
                    id: countText

                    anchors.centerIn: parent
                    text: root.tasks.length
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onTertiary
                }
            }
        }
    }

    // Text and the elapsed time get room for the digits, with the same padding as the other wing
    trailingWidth: kind === "text" || kind === "elapsed" ? Math.max(island.wingW, trailingMetrics.implicitWidth + Math.round((island.rowH - island.compactSize * 0.6) / 2) * 2) : island.wingW
    trailing: Component {
        Item {
            implicitWidth: root.kind === "text" || root.kind === "elapsed" ? clock.implicitWidth : root.island.compactSize
            implicitHeight: root.kind === "text" || root.kind === "elapsed" ? clock.implicitHeight : root.island.compactSize

            ClockText {
                id: clock

                anchors.centerIn: parent
                visible: root.kind === "text" || root.kind === "elapsed"
                text: root.trailingString
            }

            Indicator {
                anchors.centerIn: parent
                visible: root.kind === "progress" || root.kind === "spinner"
                task: root.task
                size: root.island.compactSize
                strokeWidth: 2
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

    ClockText {
        id: trailingMetrics

        visible: false
        text: root.trailingString
    }

    // One row per task: icon | title / subtitle · elapsed | actions | indicator (hover: dismiss)
    // Two rows or more get the full corner radius: inset the rows so their artwork and buttons stay
    // concentric with it (one row is a plain pill, which its end padding already fits)
    readonly property real listInset: visibleRows > 1 ? island.panelShift : 0
    // As wide as the widest row, so there's no empty space in the middle; never narrower than the pill
    // it grows from (it's centred in that, which would leave space at the sides)
    expandedWidth: {
        const widest = Math.max(0, ...tasks.map(t => rowWidth(t)));
        return Math.ceil(Math.min(420, island.width - island.margin * 2, Math.max(island.baseWidth, widest + listInset * 2)));
    }
    expandedHeight: visibleRows * island.bannerH + listInset * 2
    expanded: Component {
        Item {
            ListView {
                anchors.fill: parent
                anchors.margins: root.listInset
                interactive: root.tasks.length > root.visibleRows
                clip: interactive
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: root.tasks.slice().reverse()
                    objectProp: "id"
                }

                delegate: TaskRow {}
            }
        }
    }

    component TaskRow: Item {
        id: row

        required property var modelData
        readonly property var t: modelData
        readonly property bool clickable: !!(t?.command || t?.window)

        width: ListView.view?.width ?? 0
        height: root.island.bannerH

        TapHandler {
            enabled: row.clickable
            cursorShape: Qt.PointingHandCursor
            onTapped: {
                IslandTasks.activate(row.t);
                root.island.collapse();
            }
        }

        // Inset like the slots of a one-row banner, so the end items are concentric with the pill's ends,
        // and the same small gap between everything
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.island.slotPadding
            anchors.rightMargin: root.island.slotPadding
            spacing: Tokens.spacing.small

            TaskIcon {
                Layout.alignment: Qt.AlignVCenter
                task: row.t
                size: root.island.coverSize
            }

            InkText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: root.island.coverSize
                title: row.t?.title ?? ""
                subtitle: root.rowSubtitle(row.t)
            }

            Repeater {
                model: (row.t?.actions ?? []).slice(0, 2)

                IslandButton {
                    required property var modelData

                    Layout.alignment: Qt.AlignVCenter
                    island: root.island
                    icon: modelData?.icon || "play_arrow"
                    variant: modelData?.variant || "secondary"
                    onClicked: IslandTasks.run(modelData?.command)
                }
            }

            // The indicator; hovered (or without one), a button to dismiss the task
            Item {
                id: endItem

                readonly property bool hasIndicator: root.trailingKind(row.t) === "progress" || root.trailingKind(row.t) === "spinner"
                readonly property bool showClose: !hasIndicator || closeHover.hovered

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.island.coverSize
                implicitHeight: root.island.coverSize

                HoverHandler {
                    id: closeHover
                }

                Indicator {
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: endItem.showClose ? 0 : 1
                    task: row.t
                    size: root.island.coverSize
                    strokeWidth: 3

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                IslandButton {
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: endItem.showClose ? 1 : 0
                    island: root.island
                    icon: "close"
                    onClicked: IslandTasks.endTask(row.t.id, {})

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }
        }
    }

    // A task's artwork: an image, an app icon, or its symbol (in a coloured circle unless plain)
    component TaskIcon: Item {
        id: icon

        required property var task
        required property real size
        property bool plain
        readonly property string colourName: task?.colour ?? ""

        implicitWidth: size
        implicitHeight: size

        ClipRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: icon.plain && !artwork.visible ? "transparent" : root.container(icon.colourName)

            Image {
                id: artwork

                anchors.fill: parent
                visible: status === Image.Ready
                source: icon.task?.image ? (icon.task.image.includes("://") ? icon.task.image : `file://${icon.task.image}`) : ""
                sourceSize.width: icon.size * 2
                sourceSize.height: icon.size * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            IconImage {
                id: appIcon

                anchors.centerIn: parent
                visible: !artwork.visible && !!icon.task?.appIcon
                implicitSize: Math.round(icon.size * (icon.plain ? 0.9 : 0.62))
                source: visible ? (icon.task.appIcon.startsWith("/") ? `file://${icon.task.appIcon}` : Quickshell.iconPath(icon.task.appIcon, "application-x-executable")) : ""
                asynchronous: true
            }

            IslandIcon {
                anchors.fill: parent
                visible: !artwork.visible && !appIcon.visible
                text: icon.task?.icon || "terminal"
                fontStyle: Tokens.font.icon.size(Math.max(1, Math.round(icon.size * (icon.plain ? 0.8 : 0.55)))).build()
                color: icon.plain ? root.accent(icon.colourName) : root.onContainer(icon.colourName)
            }
        }
    }

    // A ring for tasks with progress, a spinner for indeterminate ones
    component Indicator: Item {
        id: ind

        required property var task
        required property real size
        required property real strokeWidth
        readonly property string kind: root.trailingKind(task)

        implicitWidth: size
        implicitHeight: size

        CircularProgress {
            anchors.fill: parent
            visible: ind.kind === "progress"
            implicitSize: ind.size
            value: Math.max(0, ind.task?.progress ?? 0)
            strokeWidth: ind.strokeWidth
            padding: 0
            fgColour: root.accent(ind.task?.colour ?? "")
            bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.12)
        }

        CircularIndicator {
            anchors.fill: parent
            visible: ind.kind === "spinner"
            implicitSize: ind.size
            strokeWidth: ind.strokeWidth
            running: visible
            // Indeterminate: just the moving arc (a track behind it looks like a broken ring)
            bgColour: "transparent"
        }
    }

    Connections {
        target: IslandTasks

        function onBannerRequested(d: var): void {
            const status = d.status ?? "";
            const colour = status === "error" ? "error" : (d.colour ?? "");
            root.quick(d.key || `ipc-${++root.counter}`, {
                icon: d.icon || (status === "error" ? "error" : status === "success" ? "check" : "info"),
                image: d.image ?? "",
                appIcon: d.appIcon ?? "",
                circleColour: root.container(colour),
                iconColour: root.onContainer(colour),
                title: d.title ?? "",
                subtitle: d.subtitle ?? "",
                trailingIcon: d.trailingIcon ?? "",
                trailingText: d.trailingText ?? "",
                progress: d.progress ?? -1,
                progressColour: root.accent(colour),
                onClick: d.command || d.window ? () => IslandTasks.activate(d) : undefined
            }, {
                priority: (d.priority ?? IslandConfig.ipc.priority) + (d.urgent ? 30 : 0),
                duration: Number(d.duration) > 0 ? Number(d.duration) : IslandConfig.ipc.duration,
                requeue: !!d.urgent
            });
        }
    }
}
