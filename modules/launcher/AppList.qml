pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

StyledListView {
    id: root

    required property SearchBar search
    required property ScreenState screenState

    property string displayText

    readonly property string requestedState: stateForText(search.text)
    readonly property string displayState: stateForText(displayText)

    function syncDisplayText(): void {
        if (screenState.launcher && requestedState === displayState)
            displayText = search.text;
    }

    function stateForText(text: string): string {
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            if (text === `${prefix}timer` || text.startsWith(`${prefix}timer `))
                return "timer";
            const actionPrefixes = ["calc", "scheme", "variant", "emoji", "clipboard", "windows"];
            for (const action of actionPrefixes)
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    // ">timer 25m tea": start a 25 minute timer called "tea"; ">timer stopwatch"; controls for a running one.
    // Shown in the dynamic island (services/Timers.qml, modules/island/TimerActivity.qml).
    function timerResults(query: string): var {
        const item = (name, desc, icon, action) => ({
                name: name,
                desc: desc,
                icon: icon,
                onClicked: list => {
                    list.screenState.launcher = false;
                    action();
                }
            });
        const results = [];

        // Longest leading part that parses as a duration; the rest is the label
        const parts = query.split(/\s+/).filter(p => p);
        for (let i = parts.length; i > 0; i--) {
            const seconds = Timers.parseDuration(parts.slice(0, i).join(" "));
            if (seconds > 0) {
                const label = parts.slice(i).join(" ");
                results.push(item(label ? qsTr("Start %1 timer: %2").arg(Timers.describe(seconds)).arg(label) : qsTr("Start %1 timer").arg(Timers.describe(seconds)), qsTr("Counts down in the dynamic island"), "timer", () => Timers.startTimer(seconds, label)));
                break;
            }
        }

        if (Timers.running) {
            results.push(item(Timers.paused ? qsTr("Resume %1").arg(Timers.mode) : qsTr("Pause %1").arg(Timers.mode), Timers.timeStr, Timers.paused ? "play_arrow" : "pause", () => Timers.togglePause()));
            if (Timers.mode === "timer")
                results.push(item(qsTr("Add a minute"), Timers.timeStr, "more_time", () => Timers.addSeconds(60)));
            results.push(item(qsTr("Stop %1").arg(Timers.mode), Timers.timeStr, "stop", () => Timers.stop()));
        }

        if (!query || "stopwatch".startsWith(parts[0]?.toLowerCase() ?? ""))
            results.push(item(qsTr("Start stopwatch"), qsTr("Counts up in the dynamic island"), "timer_play", () => Timers.startStopwatch(parts.slice(1).join(" "))));

        if (!query)
            for (const preset of [60, 300, 600, 1500])
                results.push(item(qsTr("Start %1 timer").arg(Timers.describe(preset)), qsTr("Or type a length, e.g. %1timer 1h30m").arg(GlobalConfig.launcher.actionPrefix), "timer", () => Timers.startTimer(preset, "")));

        return results;
    }

    function resultsForText(text: string): var {
        switch (stateForText(text)) {
        case "actions":
            return Actions.query(text);
        case "calc":
            return [0];
        case "scheme":
            return Schemes.query(text);
        case "variant":
            return M3Variants.query(text);
        case "emoji": {
            const prefix = GlobalConfig.launcher.actionPrefix;
            const queryText = text.slice((prefix + "emoji ").length).toLowerCase();
            if (!queryText)
                return Emojis.getSortedItems();
            return Emojis.items.filter(function (item) {
                return item.name.toLowerCase().includes(queryText);
            });
        }
        case "clipboard": {
            const prefix = GlobalConfig.launcher.actionPrefix;
            const queryText = text.slice((prefix + "clipboard ").length).toLowerCase();
            if (!queryText)
                return Clipboard.getSortedItems();
            return Clipboard.items.filter(function (item) {
                return item.preview.toLowerCase().includes(queryText);
            });
        }
        case "windows":
            return Windows.items;
        case "timer":
            return root.timerResults(text.slice((GlobalConfig.launcher.actionPrefix + "timer").length).trim());
        default:
            return Apps.search(text);
        }
    }

    model: ScriptModel {
        values: root.resultsForText(root.displayText)
        onValuesChanged: root.currentIndex = 0
    }

    spacing: Tokens.spacing.small
    orientation: Qt.Vertical
    implicitHeight: Math.max(0, (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing)

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {}
        }
    }

    state: screenState.launcher ? requestedState : displayState

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
        if (state === "emoji")
            Emojis.reload();
        if (state === "clipboard")
            Clipboard.reload();
            
        if (state !== "scheme" && state !== "variant") {
            Colours.showPreview = false;
        }
    }

    onCurrentItemChanged: {
        if (state === "scheme" || state === "variant") {
            if (currentItem && currentItem.modelData)
                previewTimer.restart();
        }
    }

    Component.onDestruction: {
        Colours.showPreview = false;
    }

    Timer {
        id: previewTimer
        interval: 100
        onTriggered: {
            if (!root.currentItem || !root.currentItem.modelData) return;
            if (root.state === "scheme") {
                const schemeData = root.currentItem.modelData;
                Colours.load(JSON.stringify({ name: schemeData.name, flavour: schemeData.flavour, variant: Colours.variant, mode: Colours.light ? "light" : "dark", colours: schemeData.colours }), true);
                Colours.showPreview = true;
            } else if (root.state === "variant") {
                const variantData = root.currentItem.modelData;
                M3Variants.previewVariant(variantData.variant);
            }
        }
    }

    Component.onCompleted: displayText = search.text

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                root.delegate: calcItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                root.delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                root.delegate: variantItem
            }
        },
        State {
            name: "emoji"

            PropertyChanges {
                root.delegate: emojiItem
            }
        },
        State {
            name: "clipboard"

            PropertyChanges {
                root.delegate: clipItem
            }
        },
        State {
            name: "windows"

            PropertyChanges {
                root.delegate: windowsItem
            }
        },
        State {
            name: "timer"

            PropertyChanges {
                root.delegate: actionItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
            }
            PropertyAction {
                target: root
                property: "delegate"
                value: null
            }
            ScriptAction {
                script: root.displayText = root.search.text
            }
            PropertyAction {
                target: root
                property: "delegate"
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
            }
            PropertyAction {
                targets: [root.add, root.remove]
                property: "enabled"
                value: true
            }
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: !root.state

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 1
            to: 0
        }
    }

    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            type: Anim.StandardSmall
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            screenState: root.screenState
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }

    Component {
        id: emojiItem

        EmojiItem {
            list: root
        }
    }

    Component {
        id: clipItem

        ClipItem {
            list: root
        }
    }

    Component {
        id: windowsItem

        WindowSwitcherItem {
            list: root
        }
    }

    Connections {
        function onTextChanged() {
            root.syncDisplayText();
        }

        target: root.search
    }

    Connections {
        function onLauncherChanged() {
            root.syncDisplayText();
        }

        target: root.screenState
    }
}
