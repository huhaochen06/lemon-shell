pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.controls
import qs.services
import qs.utils

// The dock's app row: pinned apps + running windows, drag to reorder, right click for the context menu.
// Lives in the centre of the dynamic island (DynamicIsland.qml), which draws the pill around it.
// Membership changes animate individual delegates; the row fades only when the whole dock is hidden.
BlurFade {
    id: root

    required property var popouts // BarPopouts.Wrapper
    required property real itemSize
    property bool presented: true
    readonly property bool recolourIcons: Config.bar.dock.recolourIcons ?? false

    readonly property bool hasApps: modelDataArray.length > 0
    readonly property int spacing: Tokens.spacing.small
    readonly property int targetCount: modelDataArray.length
    readonly property real targetWidth: targetCount * itemSize + Math.max(0, targetCount - 1) * spacing

    property var launchingApps: ({})
    property var modelDataArray: []
    property var currentOrder: []

    signal contextMenuOpened

    implicitWidth: targetWidth
    implicitHeight: itemSize
    shown: presented && hasApps
    enabled: presented
    hiddenScale: 0.98
    inDelay: 90
    inDuration: 280
    outDuration: 180

    onModelDataArrayChanged: currentOrder = [...modelDataArray]

    Behavior on width {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    ListModel {
        id: dockModel
    }

    function saveNewOrder(): void {
        const newArr = [];
        const newFavs = [];

        for (let i = 0; i < root.currentOrder.length; ++i) {
            const mData = root.currentOrder[i];
            if (!mData)
                continue;
            if (mData.isPinned)
                newFavs.push(mData.id);
            newArr.push(mData);
        }

        // Only update if arrays are different length or different order
        const currentFavs = GlobalConfig.launcher.favouriteApps || [];
        let changed = currentFavs.length !== newFavs.length;
        if (!changed) {
            for (let i = 0; i < newFavs.length; i++) {
                if (currentFavs[i] !== newFavs[i]) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed)
            GlobalConfig.launcher.favouriteApps = newFavs;

        root.modelDataArray = newArr;
    }

    function rebuildModel(): void {
        const apps = [];
        const pinnedIds = GlobalConfig.launcher.favouriteApps || [];

        for (const pid of pinnedIds) {
            for (const entry of DesktopEntries.applications.values) {
                if (Strings.testRegexList([pid], entry.id)) {
                    if (!apps.some(a => a.id === entry.id)) {
                        apps.push({
                            id: entry.id,
                            isPinned: true,
                            entry: entry,
                            toplevels: [],
                            appClass: entry.id.replace(".desktop", ""),
                            iconName: entry.id
                        });
                    }
                }
            }
        }

        for (const toplevel of Hyprland.toplevels.values) {
            const ipc = toplevel.lastIpcObject;
            if (!ipc)
                continue;
            const appClass = ipc.class || ipc.initialClass;
            if (!appClass)
                continue;

            let found = false;
            for (const app of apps) {
                const isToplevelSteamGame = appClass.toLowerCase().startsWith("steam_app_");

                if (isToplevelSteamGame) {
                    if (app.appClass.toLowerCase() === appClass.toLowerCase()) {
                        app.toplevels.push(toplevel);
                        found = true;
                        break;
                    }
                } else {
                    const isAppSteamGame = app.id.toLowerCase().startsWith("steam_app_") || app.appClass.toLowerCase().startsWith("steam_app_");
                    if (isAppSteamGame)
                        continue;

                    const baseId = app.id.toLowerCase().replace(".desktop", "");
                    if (app.appClass.toLowerCase() === appClass.toLowerCase() || app.id.toLowerCase().includes(appClass.toLowerCase()) || appClass.toLowerCase().includes(baseId)) {
                        app.toplevels.push(toplevel);
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                const isToplevelSteamGame = appClass.toLowerCase().startsWith("steam_app_");
                let entry = null;
                let iconName = appClass;

                if (isToplevelSteamGame) {
                    const appId = appClass.substring(10);
                    iconName = `steam_icon_${appId}`;
                    entry = DesktopEntries.applications.values.find(e => e.id.toLowerCase() === `steam_app_${appId}.desktop` || e.id.toLowerCase() === `steam-${appId}.desktop`) || null;
                } else {
                    entry = DesktopEntries.heuristicLookup(appClass) || null;
                    if (!entry) {
                        entry = DesktopEntries.applications.values.find(e => {
                            const eBase = e.id.toLowerCase().replace(".desktop", "");
                            return e.id.toLowerCase().includes(appClass.toLowerCase()) || appClass.toLowerCase().includes(eBase);
                        }) || null;
                    }
                    iconName = entry ? entry.id : appClass;
                }

                apps.push({
                    id: appClass,
                    isPinned: false,
                    entry: entry,
                    toplevels: [toplevel],
                    appClass: appClass,
                    iconName: iconName
                });
            }
        }

        // Keep running apps in their existing order when focus or compositor order changes.
        const previousIds = root.currentOrder.map(app => app.id);
        const pinned = apps.filter(app => app.isPinned);
        const running = apps.filter(app => !app.isPinned);
        running.sort((a, b) => {
            const ai = previousIds.indexOf(a.id);
            const bi = previousIds.indexOf(b.id);
            return (ai < 0 ? previousIds.length : ai) - (bi < 0 ? previousIds.length : bi);
        });
        apps.splice(0, apps.length, ...pinned, ...running);

        let newLaunching = Object.assign({}, root.launchingApps);
        let launchingChanged = false;

        for (const app of apps) {
            if (app.toplevels.length > 0) {
                if (newLaunching[app.appClass]) {
                    delete newLaunching[app.appClass];
                    launchingChanged = true;
                }
                if (newLaunching[app.id]) {
                    delete newLaunching[app.id];
                    launchingChanged = true;
                }
            }
        }

        if (launchingChanged)
            root.launchingApps = newLaunching;

        applyModel(apps);
    }

    function applyModel(apps: var): void {
        // Surviving delegates keep their identity. Removed delegates retain their last data until faded.
        root.modelDataArray = apps;
        for (let i = dockModel.count - 1; i >= 0; i--) {
            if (!apps.some(a => a.id === dockModel.get(i).appId))
                dockModel.remove(i);
        }

        for (let i = 0; i < apps.length; i++) {
            let found = false;
            for (let j = 0; j < dockModel.count; j++) {
                if (dockModel.get(j).appId === apps[i].id) {
                    found = true;
                    break;
                }
            }
            if (!found)
                dockModel.append({
                    appId: apps[i].id
                });
        }

        for (let i = 0; i < apps.length; i++) {
            const currentId = apps[i].id;
            if (dockModel.get(i).appId !== currentId) {
                let foundIdx = -1;
                for (let j = i + 1; j < dockModel.count; j++) {
                    if (dockModel.get(j).appId === currentId) {
                        foundIdx = j;
                        break;
                    }
                }
                if (foundIdx !== -1)
                    dockModel.move(foundIdx, i, 1);
            }
        }
    }

    property var _appsValues: DesktopEntries.applications.values
    on_AppsValuesChanged: rebuildModel()

    property var _toplevels: Hyprland.toplevels.values
    on_ToplevelsChanged: {
        rebuildModel();
        delayedRebuildTimer.restart();
    }

    property var activeTop: Hyprland.activeToplevel
    onActiveTopChanged: {
        rebuildModel();
        delayedRebuildTimer.restart();
    }

    Timer {
        id: delayedRebuildTimer

        interval: 100
        onTriggered: root.rebuildModel()
    }

    Connections {
        target: GlobalConfig.launcher

        function onFavouriteAppsChanged(): void {
            root.rebuildModel();
        }
    }

    Component.onCompleted: rebuildModel()

    ListView {
        id: listView

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: contentWidth
        height: root.itemSize
        orientation: ListView.Horizontal
        spacing: root.spacing
        interactive: false

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        addDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        model: DelegateModel {
            model: dockModel
            delegate: dockDelegate
        }
    }

    Component {
        id: dockDelegate

        BlurFade {
            id: delegateContainer

            required property int index
            required property string appId
            readonly property var currentData: root.modelDataArray.find(app => app.id === appId)
            property var modelData: null
            property bool removing: false

            width: root.itemSize
            height: root.itemSize
            implicitWidth: width
            implicitHeight: height
            shown: !removing
            hiddenScale: 0.95
            inDuration: 220
            outDuration: 180

            onCurrentDataChanged: {
                if (currentData && !removing)
                    modelData = currentData;
            }
            Component.onCompleted: {
                if (currentData && !removing)
                    modelData = currentData;
            }
            ListView.onRemove: {
                ListView.delayRemove = progress > 0;
                removing = true;
            }
            onProgressChanged: {
                if (removing && progress === 0)
                    ListView.delayRemove = false;
            }

            DropArea {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                onEntered: drag => {
                    const from = drag.source.delegateIndex;
                    const to = delegateContainer.index;
                    if (from !== undefined && to !== undefined && from !== to) {
                        dockModel.move(from, to, 1);
                        const movedItem = root.currentOrder.splice(from, 1)[0];
                        root.currentOrder.splice(to, 0, movedItem);
                    }
                }
                onDropped: root.saveNewOrder()
            }

            Item {
                id: delegateItem

                readonly property var modelData: delegateContainer.modelData
                property int delegateIndex: delegateContainer.index

                property bool isActive: {
                    const activeTop = Hyprland.activeToplevel;
                    if (!activeTop)
                        return false;

                    if (activeTop.lastIpcObject && modelData?.appClass) {
                        const activeClass = (activeTop.lastIpcObject.class || activeTop.lastIpcObject.initialClass || "").toLowerCase();
                        const appId = modelData.appClass.toLowerCase();
                        if (activeClass && (activeClass === appId || activeClass.includes(appId) || appId.includes(activeClass)))
                            return true;
                    }

                    for (const top of modelData?.toplevels || []) {
                        if (top.address && top.address === activeTop.address)
                            return true;
                    }
                    return false;
                }

                width: delegateContainer.width
                height: delegateContainer.height
                scale: dragArea.pressed && dragArea.pressedButtons === Qt.LeftButton && !dragArea.held ? 0.94 : 1

                Drag.active: dragArea.held
                Drag.source: delegateItem
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                states: State {
                    name: "dragging"
                    when: dragArea.held

                    ParentChange {
                        target: delegateItem
                        parent: listView
                    }
                    PropertyChanges {
                        target: delegateItem
                        opacity: 0.8
                        z: 999
                    }
                }

                transitions: Transition {
                    from: "dragging"

                    ParentAnimation {
                        target: delegateItem
                        via: listView

                        NumberAnimation {
                            properties: "x,y"
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                    NumberAnimation {
                        property: "opacity"
                        duration: 160
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    id: dragArea

                    readonly property bool held: drag.active

                    anchors.fill: parent
                    drag.target: delegateItem
                    drag.axis: Drag.XAxis
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: mouse => {
                        const data = delegateItem.modelData;
                        if (mouse.button === Qt.LeftButton) {
                            if (data?.toplevels.length > 0) {
                                const addr = data.toplevels[0].address;
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${addr}" })` : `focuswindow address:0x${addr}`);
                            } else if (data?.entry) {
                                launchPulse.restart();
                                const newLaunching = Object.assign({}, root.launchingApps);
                                newLaunching[data.appClass || data.id] = true;
                                root.launchingApps = newLaunching;

                                const subCmd = data.entry.runInTerminal ? [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...data.entry.command] : data.entry.command;
                                Quickshell.execDetached({
                                    command: subCmd,
                                    workingDirectory: data.entry.workingDirectory
                                });
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            root.contextMenuOpened();
                            root.popouts.currentName = "dockcontext";
                            root.popouts.currentCenter = delegateItem.mapToItem(null, delegateItem.width / 2, 0).x;
                            root.popouts.dockModel = data;
                            root.popouts.hasCurrent = true;
                        }
                    }

                    onCanceled: root.saveNewOrder()
                    onReleased: root.saveNewOrder()
                }

                Item {
                    id: artwork

                    anchors.centerIn: parent
                    width: Math.round(Math.min(24, root.itemSize * 0.6) / 2) * 2
                    height: width

                    BlurFade {
                        anchors.fill: parent
                        shown: icon.status === Image.Ready && !root.recolourIcons
                        hiddenScale: 1
                        inDuration: 180
                        outDuration: 180

                        IconImage {
                            id: icon

                            anchors.centerIn: parent
                            implicitSize: artwork.width
                            source: {
                                const data = delegateItem.modelData;
                                if (data?.entry && data.entry.icon)
                                    return Quickshell.iconPath(data.entry.icon, "image-missing");
                                return Quickshell.iconPath(data?.iconName, "image-missing");
                            }
                            asynchronous: true
                        }
                    }

                    SequentialAnimation {
                        id: launchPulse

                        NumberAnimation {
                            target: icon
                            property: "scale"
                            to: 1.08
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: icon
                            property: "scale"
                            to: 1
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    BlurFade {
                        anchors.fill: parent
                        shown: colouredIcon.status === Image.Ready && root.recolourIcons
                        hiddenScale: 1
                        inDuration: 180
                        outDuration: 180

                        ColouredIcon {
                            id: colouredIcon

                            anchors.fill: parent
                            scale: icon.scale
                            source: icon.source
                            colour: Colours.palette.m3secondary
                            layer.enabled: true
                        }
                    }
                }

                BlurFade {
                    anchors.fill: artwork
                    anchors.margins: -Tokens.padding.small
                    shown: root.launchingApps[delegateItem.modelData?.appClass || delegateItem.modelData?.id] || false
                    hiddenScale: 1
                    inDuration: 180
                    outDuration: 180

                    Loader {
                        anchors.fill: parent
                        active: parent.visible || parent.shown
                        sourceComponent: CircularIndicator {
                            running: true
                            strokeWidth: 2
                        }
                    }
                }

                // One quiet dot per running app; focus changes brightness, never geometry.
                BlurFade {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 3
                    height: 3
                    shown: (delegateItem.modelData?.toplevels.length ?? 0) > 0
                    hiddenScale: 1
                    blurMax: 8
                    inDuration: 180
                    outDuration: 180

                    Rectangle {
                        anchors.fill: parent
                        radius: 1.5
                        color: Colours.palette.m3onSurface
                        opacity: delegateItem.isActive ? 1 : 0.4

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
