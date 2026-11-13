pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// Dynamic island: the dock pill in the bar, which grows around the dock to show activities.
//
// Modes:
//   dock      - just the dock icons
//   compact   - a live activity, with the dock revealed on centre hover
//   peek      - a wing is hovered, waiting for the hover delay: slowly swells around the dock row
//   expanded  - the live activity's expanded view
//   banner    - a brief message from an activity (track changed, volume, notification, ...)
// Activities take priority over app icons. Hovering the compact centre reveals the dock until the
// pointer leaves the island. Banners and expanded views take over the whole pill. The dock remains
// centred on the bar as the activity's wings grow around it.
//
// Activities (see Activity.qml) supply the content. The highest priority live activity takes the wings,
// up to two more are shown as satellite circles on either side of the pill, which emerge from and merge
// back into it with a metaball goo (tap one to swap it into the pill). Banners go through a priority
// queue: a higher priority banner interrupts a lower one, equal or lower ones wait their turn.
//
// Motion follows boring.notch / DynamicNotchKit: springs for the shape, blur replace for content.
Item {
    id: root

    required property var popouts // BarPopouts.Wrapper
    required property var bar // BarWrapper
    required property ScreenState screenState
    required property bool fullscreen

    // Exposed for the input mask: the pill, plus the safe area around it while expanded
    readonly property alias shape: hoverZone

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property bool atBottom: Config.bar.position === "bottom"
    // The island takes the place of the bar's "dock" entry
    readonly property bool dockEnabled: {
        const e = Config.bar.entries;
        return [e.start, e.center, e.end].some(s => s.values.some(v => v.id === "dock" && v.enabled));
    }
    readonly property bool available: dockEnabled && isHorizontal && !fullscreen && bar.shouldBeVisible
    // Activities that should only show once (notifications) use the island on the focused monitor
    readonly property bool isFocusScreen: (Hypr.focusedMonitor?.name ?? bar.screen.name) === bar.screen.name
    // The OSD's change popup is suppressed while this is true (see ContentWindow)
    readonly property bool handlesLevels: available && levelActivity.enabled && mode !== "peek" && mode !== "expanded"

    // Geometry. The dock row sits where the bar's entries are and is centred on the bar.
    readonly property real rowH: Tokens.sizes.bar.innerWidth
    readonly property real rowY: atBottom ? bar.y : bar.y + bar.height - rowH
    readonly property real centreX: bar.x + bar.width / 2
    readonly property real dockPadding: Math.max(Tokens.padding.medium, rowH * 0.35)
    property bool dockRevealed: false
    readonly property bool hideDockDuringActivity: IslandConfig.hideDockDuringActivity
    readonly property bool showDock: !tall && (!primary || !hideDockDuringActivity || dockRevealed)
    // Shape springs follow the requested state; outgoing content keeps its own independent blur fade.
    readonly property real dockW: showDock ? (dockRow.targetCount > 0 ? dockRow.targetWidth + dockPadding * 2 : 0) : primary ? rowH : 0
    readonly property real margin: Tokens.padding.large
    readonly property real expandedRadius: Math.max(Tokens.rounding.extraLarge, rowH / 2)
    // Wing size: content in a wing this wide is concentric with the pill's rounded end
    readonly property real wingW: rowH
    readonly property real compactSize: Math.round(rowH * 0.7)
    readonly property real peekGrowH: 8 // split evenly above and below the dock row
    // Peek scales the whole compact pill (dock and wings) up about the row's centre by this much
    readonly property real peekScale: (rowH + peekGrowH) / rowH
    // How far into the peek swell the pill is (0 - 1), following its spring so the content grows with it
    readonly property real peekAmount: Math.max(0, Math.min(1, overhangSpring.value / (peekGrowH / 2)))
    // Banners: a single row this tall, with artwork this big in square slots at either end
    readonly property real bannerH: Math.round(rowH * 1.4)
    readonly property real coverSize: Math.round(bannerH * 0.66)
    // The inset of a one-row view's artwork and buttons: centred in square slots as tall as the row
    readonly property real slotPadding: Math.round((bannerH - coverSize) / 2)
    // Views taller than one row get the full corner radius (expandedRadius), which is bigger than half a
    // row. Padding their content by this much on every side keeps round coverSize items (artwork, buttons,
    // pills) concentric with the corners. panelShift is what a one-row header (slots) needs on top.
    readonly property real panelPadding: Math.max(slotPadding, Math.round(expandedRadius - coverSize / 2))
    readonly property real panelShift: panelPadding - slotPadding
    // Corner radius for boxes inset by panelPadding (previews, command boxes)
    readonly property real panelInnerRadius: Math.max(0, expandedRadius - panelPadding)

    // Activities. To add one: create modules/island/<Name>Activity.qml extending Activity, instantiate it
    // below and add it to this list.
    readonly property list<Activity> activities: [mediaActivity, recordingActivity, levelActivity, notificationActivity, bluetoothActivity, networkActivity, batteryActivity, togglesActivity, keyboardActivity, timerActivity, discordActivity, fileTransferActivity, ipcActivity, screenshotActivity, polkitActivity, updatesActivity, downloadsActivity]

    MediaActivity {
        id: mediaActivity

        island: root
    }

    RecordingActivity {
        id: recordingActivity

        island: root
    }

    LevelActivity {
        id: levelActivity

        island: root
    }

    NotificationActivity {
        id: notificationActivity

        island: root
    }

    BluetoothActivity {
        id: bluetoothActivity

        island: root
    }

    NetworkActivity {
        id: networkActivity

        island: root
    }

    BatteryActivity {
        id: batteryActivity

        island: root
    }

    TogglesActivity {
        id: togglesActivity

        island: root
    }

    KeyboardActivity {
        id: keyboardActivity

        island: root
    }

    TimerActivity {
        id: timerActivity

        island: root
    }

    DiscordActivity {
        id: discordActivity

        island: root
    }

    FileTransferActivity {
        id: fileTransferActivity

        island: root
    }

    IpcActivity {
        id: ipcActivity

        island: root
    }

    ScreenshotActivity {
        id: screenshotActivity

        island: root
    }

    PolkitActivity {
        id: polkitActivity

        island: root
    }

    UpdatesActivity {
        id: updatesActivity

        island: root
    }

    DownloadsActivity {
        id: downloadsActivity

        island: root
    }

    // caelestia screenshot's notifications get the screenshot banner (NotificationActivity asks it)
    readonly property var screenshotHandler: screenshotActivity

    // A banner that needs typing (the polkit password) is showing: the window takes the keyboard
    readonly property bool wantsKeyboard: available && mode === "banner" && current?.keyboard === true

    // Quick Share requests get a banner with accept / decline here instead of a notification
    readonly property bool handlesTransfers: available && isFocusScreen && fileTransferActivity.enabled

    // Events this island shows itself, so the shell skips its own toast for them (see IslandState).
    // Only the focused monitor's island shows global events, so only it reports.
    readonly property var coverage: !available ? ({}) : ({
            charging: batteryActivity.enabled && IslandConfig.battery.charging,
            batteryLow: batteryActivity.enabled && IslandConfig.battery.lowWarnings,
            vpn: networkActivity.enabled && IslandConfig.network.vpn,
            doNotDisturb: togglesActivity.enabled && IslandConfig.toggles.doNotDisturb,
            gameMode: togglesActivity.enabled && IslandConfig.toggles.gameMode,
            keyboardLayout: keyboardActivity.enabled,
            timer: timerActivity.enabled,
            ipc: ipcActivity.enabled,
            polkit: polkitActivity.enabled
        })

    Binding {
        target: IslandState
        property: "covered"
        value: root.coverage
        when: root.isFocusScreen
    }

    // Live activities, highest priority first
    readonly property var liveActivities: activities.filter(a => a.live).sort((a, b) => b.priority - a.priority)
    // Set by tapping a satellite; wins over priority while it stays live
    property Activity pinned: null
    readonly property Activity primary: !available ? null : pinned && liveActivities.includes(pinned) ? pinned : (liveActivities[0] ?? null)

    // Up to two more live activities, as satellite circles on either side of the pill. Sides are sticky:
    // an activity keeps its side while it stays a satellite, the first extra one takes the right.
    readonly property int maxSatellites: 2
    readonly property var satelliteCandidates: available && IslandConfig.multiActivity ? liveActivities.filter(a => a !== root.primary).slice(0, maxSatellites) : []
    property Activity leftActivity: null
    property Activity rightActivity: null

    function assignSides(): void {
        const c = satelliteCandidates;
        let l = c.includes(leftActivity) ? leftActivity : null;
        let r = c.includes(rightActivity) ? rightActivity : null;
        for (const a of c) {
            if (a === l || a === r)
                continue;
            if (!r)
                r = a;
            else if (!l)
                l = a;
        }
        leftActivity = l;
        rightActivity = r;
    }

    onSatelliteCandidatesChanged: assignSides()

    // Satellite geometry. The goo neck pinches off at gooReach, short of the resting gap, so separated
    // circles never stay bridged to the pill.
    readonly property real satelliteGap: Math.max(Tokens.spacing.medium, Math.round(rowH * 0.35))
    readonly property real gooReach: Math.round(satelliteGap * 0.85)

    // Swap chain, driven by tapping a satellite (see swapChain): 1 = the tapped circle is separated
    property real chainMerge: 1

    // Connector between circles (c1, r1) and (c2, r2), or null once their gap reaches maxGap or one
    // contains the other. Returns the four tangent points (p1..p4) and their curve handles (h1..h4).
    function metaball(c1x: real, c1y: real, r1: real, c2x: real, c2y: real, r2: real, maxGap: real): var {
        const dx = c2x - c1x;
        const dy = c2y - c1y;
        const d = Math.hypot(dx, dy);
        const maxDist = r1 + r2 + maxGap;
        if (r1 <= 0 || r2 <= 0 || maxGap <= 0 || d >= maxDist || d <= Math.abs(r1 - r2))
            return null;
        const clamp = x => Math.max(-1, Math.min(1, x));
        // Spread: full while overlapping, pinching to a point as the gap opens
        const v = 0.5 * Math.min(1, (maxDist - d) / maxGap);
        const overlap = d < r1 + r2;
        const u1 = overlap ? Math.acos(clamp((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d))) : 0;
        const u2 = overlap ? Math.acos(clamp((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d))) : 0;
        const a = Math.atan2(dy, dx);
        const spread = Math.acos(clamp((r1 - r2) / d));
        const a1 = a + u1 + (spread - u1) * v;
        const a2 = a - u1 - (spread - u1) * v;
        const a3 = a + Math.PI - u2 - (Math.PI - u2 - spread) * v;
        const a4 = a - Math.PI + u2 + (Math.PI - u2 - spread) * v;
        const p1x = c1x + r1 * Math.cos(a1), p1y = c1y + r1 * Math.sin(a1);
        const p2x = c1x + r1 * Math.cos(a2), p2y = c1y + r1 * Math.sin(a2);
        const p3x = c2x + r2 * Math.cos(a3), p3y = c2y + r2 * Math.sin(a3);
        const p4x = c2x + r2 * Math.cos(a4), p4y = c2y + r2 * Math.sin(a4);
        const handle = Math.min(v * 2.4, Math.hypot(p3x - p1x, p3y - p1y) / (r1 + r2)) * Math.min(1, d * 2 / (r1 + r2));
        const k1 = r1 * handle;
        const k2 = r2 * handle;
        const h = Math.PI / 2;
        return {
            p1x,
            p1y,
            p2x,
            p2y,
            p3x,
            p3y,
            p4x,
            p4y,
            h1x: p1x + k1 * Math.cos(a1 - h),
            h1y: p1y + k1 * Math.sin(a1 - h),
            h2x: p2x + k1 * Math.cos(a2 + h),
            h2y: p2y + k1 * Math.sin(a2 + h),
            h3x: p3x + k2 * Math.cos(a3 + h),
            h3y: p3y + k2 * Math.sin(a3 + h),
            h4x: p4x + k2 * Math.cos(a4 - h),
            h4y: p4y + k2 * Math.sin(a4 - h)
        };
    }

    function swapWith(sat: Satellite): void {
        if (swapChain.running || sat.busy || !sat.activity || !primary || mode !== "compact")
            return;
        swapChain.sat = sat;
        swapChain.incoming = sat.activity;
        swapChain.outgoing = primary;
        swapChain.start();
    }

    // The circle is fully merged: the old primary moves into its side and the tapped activity takes the pill
    function commitSwap(): void {
        const sat = swapChain.sat;
        if (sat.side < 0)
            leftActivity = swapChain.outgoing;
        else
            rightActivity = swapChain.outgoing;
        sat.activity = swapChain.outgoing;
        pinned = swapChain.incoming;
        // The pin didn't take (the activity ended mid-chain): bring the wings back anyway
        if (swapping) {
            swapping = false;
            if (primary)
                shown = primary;
            refresh();
        }
    }

    // The activity currently drawn in the wings. Lags `primary` briefly so the old wings fade out first.
    property Activity shown: null
    property bool swapping: false

    property string mode: "dock"
    property string fromMode: "dock"

    // Banner queue
    property var current: null
    property var pendingBanner: null
    property var queue: []
    property int activeSlot: 0
    readonly property BannerSlot currentSlot: activeSlot === 0 ? slotA : slotB

    readonly property int leaveDelay: 40
    // Slack around the expanded view, so overshooting its edge with the pointer doesn't close it
    readonly property real safeMargin: 36

    // Geometry follows the selected activity immediately, even while the old wings blur out.
    // Each side fits its own wing, so a narrow wing isn't padded to match a wider one.
    readonly property real leadW: primary?.leadingWidth ?? 0
    readonly property real trailW: primary?.trailingWidth ?? 0
    // Narrowest a banner may be: the pill it grows from
    readonly property real baseWidth: dockW + (primary ? leadW + trailW : 0)
    readonly property real maxWidth: width - margin * 2

    // Banners and the expanded view are centred on the dock, so both sides grow by the same amount
    function sideTarget(wing: real): real {
        if (mode === "expanded")
            return Math.max(wing, ((shown?.expandedWidth ?? 0) - dockW) / 2);
        if (mode === "banner")
            return Math.max(0, (currentSlot.width - dockW) / 2);
        // Scaled about the dock's centre: the wing grows by the scale, plus the dock's own growth on this side
        if (mode === "peek")
            return wing * peekScale + dockW * (peekScale - 1) / 2;
        if (mode === "compact")
            return wing;
        return 0;
    }
    readonly property real maxSide: Math.max(0, (maxWidth - dockW) / 2)
    readonly property real leftTarget: Math.min(sideTarget(leadW), maxSide)
    readonly property real rightTarget: Math.min(sideTarget(trailW), maxSide)
    readonly property real heightTarget: {
        if (mode === "expanded")
            return shown?.expandedHeight ?? rowH;
        if (mode === "banner")
            return currentSlot.height;
        if (mode === "peek")
            return rowH + peekGrowH;
        return rowH;
    }
    // Views that grow vertically take over the whole pill and hide the dock
    readonly property bool tall: mode === "banner" || mode === "expanded"
    // Every open state shares the same elevation, regardless of the activity's dimensions.
    property real expandAmount: mode === "peek" || tall ? 1 : 0

    Behavior on expandAmount {
        Anim {
            type: Anim.DefaultEffects
        }
    }
    // The outline waits for the island to actually open; the peek swell doesn't get one
    property real outlineAmount: tall ? 1 : 0

    Behavior on outlineAmount {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    function setMode(m: string): void {
        if (m === mode)
            return;
        fromMode = mode;
        mode = m;
    }

    // Work out the mode from the current state
    function refresh(): void {
        if (!available) {
            expandTimer.stop();
            leaveTimer.stop();
            bannerTimer.stop();
            current = null;
            pendingBanner = null;
            queue = [];
            setMode("dock");
            return;
        }
        if (current) {
            setMode("banner");
            return;
        }
        // Stay open while the expanded activity is still the one shown
        if ((mode === "peek" || mode === "expanded") && shown && shown === primary && shown.expandable)
            return;
        setMode(primary ? "compact" : "dock");
        // Banners that waited for the expanded view to close
        if (queue.length > 0)
            next();
    }

    function expandActivity(activity: Activity): void {
        if (!activity || activity !== shown || !activity.expandable || !available)
            return;
        expandTimer.stop();
        leaveTimer.stop();
        // Leaving a banner for the expanded view (e.g. clicking the track banner)
        if (current) {
            bannerTimer.stop();
            current = null;
        }
        setMode("expanded");
    }

    function collapse(): void {
        expandTimer.stop();
        leaveTimer.stop();
        if (mode === "peek" || mode === "expanded") {
            setMode(primary ? "compact" : "dock");
            if (queue.length > 0)
                next();
        }
    }

    // Banners -------------------------------------------------------------------------------------

    function post(banner: var): void {
        if (!available)
            return;
        banner.time = Date.now();

        // Keep a stable view for updates to the same layout. Its changed children animate locally.
        if (current && current.key === banner.key && current.component === banner.component) {
            current = Object.assign({}, current, banner, {
                time: current.time
            });
            currentSlot.banner = current;
            bannerTimer.interval = current.duration * 1000;
            bannerTimer.restart();
            return;
        }

        queue = queue.filter(b => b.key !== banner.key);

        // Don't pull the expanded view away from under the cursor, unless it's urgent (polkit)
        const busy = (mode === "peek" || mode === "expanded") && !banner.urgent;
        if (!busy && (!current || banner.priority > current.priority)) {
            if (current?.requeue)
                enqueue(current);
            show(banner);
        } else if (banner.queueable) {
            enqueue(banner);
        }
    }

    function enqueue(banner: var): void {
        const q = queue.slice();
        q.push(banner);
        q.sort((a, b) => b.priority - a.priority || a.time - b.time);
        queue = q;
    }

    function show(banner: var): void {
        // Never overwrite a slot before its outgoing content has disappeared.
        const target = activeSlot === 0 ? slotB : slotA;
        if (target.progress > 0) {
            pendingBanner = banner;
            return;
        }
        pendingBanner = null;
        current = banner;
        target.banner = banner;
        activeSlot = activeSlot === 0 ? 1 : 0;
        bannerTimer.interval = banner.duration * 1000;
        bannerTimer.restart();
        refresh();
    }

    function next(): void {
        bannerTimer.stop();
        current = null;
        if (pendingBanner) {
            const banner = pendingBanner;
            pendingBanner = null;
            if (!banner.valid || banner.valid()) {
                show(banner);
                return;
            }
        }
        while (queue.length > 0) {
            const banner = queue[0];
            queue = queue.slice(1);
            if (!banner.valid || banner.valid()) {
                show(banner);
                return;
            }
        }
        refresh();
    }

    function dismiss(key: string): void {
        if (pendingBanner?.key === key)
            pendingBanner = null;
        if (current?.key === key)
            next();
        else
            queue = queue.filter(b => b.key !== key);
    }

    // ---------------------------------------------------------------------------------------------

    readonly property bool wingHovered: leftWingHover.hovered || rightWingHover.hovered
    readonly property bool islandHovered: pillHover.hovered || (mode === "expanded" && safeHover.hovered)

    onWingHoveredChanged: {
        if (wingHovered) {
            leaveTimer.stop();
            if (mode === "compact" && shown?.expandable && IslandConfig.hoverExpand) {
                setMode("peek");
                expandTimer.restart();
                mergeLeadTimer.restart();
            }
        } else {
            expandTimer.stop();
            mergeLeadTimer.stop();
            expandImminent = false;
            if (mode === "peek")
                leaveTimer.restart();
        }
    }

    onIslandHoveredChanged: {
        if (islandHovered) {
            dockHideTimer.stop();
        } else {
            dockRevealTimer.stop();
            dockHideTimer.restart();
        }
        if (mode !== "expanded")
            return;
        if (islandHovered)
            leaveTimer.stop();
        else
            leaveTimer.restart();
    }

    onModeChanged: {
        if (mode === "banner" || mode === "expanded")
            dockRevealed = false;
        if (mode !== "peek") {
            mergeLeadTimer.stop();
            expandImminent = false;
        }
    }

    onHideDockDuringActivityChanged: dockRevealed = false

    onAvailableChanged: {
        if (!available)
            dockRevealed = false;
        refresh();
    }

    onLiveActivitiesChanged: {
        if (pinned && !liveActivities.includes(pinned))
            pinned = null;
    }

    onPrimaryChanged: {
        // A new activity starts compact, independently of any previous dock hover or outgoing content.
        dockRevealTimer.stop();
        dockRevealed = false;
        // The swap chain already blurred the wings out; bring the new activity straight in
        if (swapChain.running) {
            if (primary)
                shown = primary;
            swapping = false;
            refresh();
            return;
        }
        // The expanded view belongs to the old primary
        if (mode === "peek" || mode === "expanded")
            collapse();
        if (shown && primary && mode === "compact") {
            // Fade the old wings out, then swap
            swapping = true;
            swapTimer.restart();
        } else {
            if (primary)
                shown = primary;
            refresh();
        }
    }

    anchors.fill: parent

    Timer {
        id: dockRevealTimer

        interval: 180
        onTriggered: {
            if (root.hideDockDuringActivity && root.primary && centreHover.hovered && !root.tall && root.mode !== "peek")
                root.dockRevealed = true;
        }
    }

    Timer {
        id: dockHideTimer

        interval: 220
        onTriggered: {
            // Hold the strip while its context menu is in use.
            if (root.islandHovered || (root.popouts.hasCurrent && root.popouts.currentName === "dockcontext"))
                restart();
            else
                root.dockRevealed = false;
        }
    }

    Timer {
        id: swapTimer

        interval: 150
        onTriggered: {
            root.shown = root.primary ?? root.shown;
            root.swapping = false;
            root.refresh();
        }
    }

    // Tapping a satellite: its content and the pill's wings blur out, the circle merges into the pill,
    // the pill takes the tapped activity, then the circle separates again carrying the old one.
    SequentialAnimation {
        id: swapChain

        property Satellite sat: null
        property Activity incoming: null
        property Activity outgoing: null

        ScriptAction {
            script: {
                root.chainMerge = 1;
                swapChain.sat.locked = true;
                swapChain.sat.contentShown = false;
                root.swapping = true;
            }
        }
        // Merges straight away, while its content and the wings blur out
        NumberAnimation {
            target: root
            property: "chainMerge"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: root.commitSwap()
        }
        PauseAnimation {
            duration: 80
        }
        ScriptAction {
            script: swapChain.sat.contentShown = true
        }
        NumberAnimation {
            target: root
            property: "chainMerge"
            to: 1
            duration: 360
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                const sat = swapChain.sat;
                sat.detach = 1;
                sat.locked = false;
                Qt.callLater(sat.sync);
            }
        }
    }

    Timer {
        id: bannerTimer

        onTriggered: {
            // Keep it up while it is being looked at
            if (root.islandHovered)
                restart();
            else
                root.next();
        }
    }

    // Satellites start merging this long before a hover expand, so they're gone by the time it opens
    readonly property int satelliteMergeLead: 160
    property bool expandImminent: false

    Timer {
        id: mergeLeadTimer

        interval: Math.max(0, IslandConfig.hoverDelay - root.satelliteMergeLead)
        onTriggered: {
            if (root.wingHovered && root.mode === "peek")
                root.expandImminent = true;
        }
    }

    Timer {
        id: expandTimer

        interval: IslandConfig.hoverDelay
        onTriggered: {
            if (root.wingHovered && root.mode === "peek")
                root.expandActivity(root.shown);
        }
    }

    Timer {
        id: leaveTimer

        interval: root.leaveDelay
        onTriggered: {
            if ((root.mode === "peek" && !root.wingHovered) || (root.mode === "expanded" && !root.islandHovered))
                root.collapse();
        }
    }

    // Springs: slow and critically damped while peeking, snappy with a hint of bounce when opening,
    // and quicker with no bounce when contracting (boring.notch: open 0.42/0.8, close 0.45/1.0)
    readonly property bool contracting: mode === "dock" || (mode === "compact" && fromMode !== "dock")
    readonly property real springResponse: mode === "peek" ? 0.7 : mode === "expanded" ? 0.42 : mode === "banner" ? 0.45 : contracting ? 0.3 : 0.4
    readonly property real springDamping: mode === "peek" ? 1 : mode === "expanded" || mode === "banner" ? 0.8 : contracting ? 1 : 0.85

    // The dock's own width (apps opening/closing)
    IslandSpring {
        id: dockSpring

        target: root.dockW
        response: 0.4
        dampingFraction: 0.85
        instant: !root.available
    }

    // Extension past the dock on each side
    IslandSpring {
        id: leftSpring

        target: root.leftTarget
        response: root.springResponse
        dampingFraction: root.springDamping
        instant: !root.available
    }

    IslandSpring {
        id: rightSpring

        target: root.rightTarget
        response: root.springResponse
        dampingFraction: root.springDamping
        instant: !root.available
    }

    IslandSpring {
        id: heightSpring

        target: root.heightTarget
        response: root.springResponse
        dampingFraction: root.springDamping
        instant: !root.available
    }

    // How far the pill reaches past the dock row towards the screen edge. Peek swells evenly around the
    // row so the dock doesn't move; tall views start at the row's edge. Springing this (rather than
    // switching anchors) keeps peek -> expanded seamless.
    IslandSpring {
        id: overhangSpring

        target: root.mode === "peek" ? root.peekGrowH / 2 : 0
        response: root.springResponse
        dampingFraction: root.springDamping
        instant: !root.available
    }

    // The pill grown by the safe margin while expanded. Takes input (see Regions) so leaving the pill
    // into this area keeps the expanded view open; matches the pill exactly otherwise.
    Item {
        id: hoverZone

        readonly property real margin: root.mode === "expanded" ? root.safeMargin : 0

        visible: pill.visible
        x: pill.x - margin
        y: pill.y - margin
        width: pill.width + margin * 2
        height: pill.height + margin * 2

        HoverHandler {
            id: safeHover
        }
    }

    BlurFade {
        id: pill

        // Top of the dock row, in pill coordinates; the row never moves on screen
        readonly property real rowTop: root.rowY - y

        shown: root.available && (dockRow.hasApps || root.primary || root.mode === "banner")
        visible: progress > 0 && width > 0 && height > 0
        hiddenScale: 0.9
        width: dockSpring.value + leftSpring.value + rightSpring.value
        height: heightSpring.value
        x: root.centreX - dockSpring.value / 2 - leftSpring.value
        y: root.atBottom ? root.rowY + root.rowH + overhangSpring.value - height : root.rowY - overhangSpring.value

        HoverHandler {
            id: pillHover
        }

        // Background
        StyledRect {
            id: background

            anchors.fill: parent
            radius: Math.min(height / 2, root.expandedRadius)
            color: Colours.palette.m3surfaceContainer

            layer.enabled: root.expandAmount > 0
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 32
                shadowBlur: 1
                shadowVerticalOffset: root.atBottom ? -2 : 2
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.22 * root.expandAmount)
            }
        }

        // Rounded clip for the expanded content
        Item {
            id: maskShape

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: background.radius
                color: "black"
            }
        }

        Item {
            id: content

            anchors.fill: parent
            clip: true
            layer.enabled: expandedContent.visible
            layer.effect: Mask {
                maskSource: maskShape
            }

            // The compact row (dock and wings). Peek scales it with the pill about the row's centre, which
            // stays put on screen, so the whole pill grows in proportion.
            Item {
                id: compactRow

                anchors.fill: parent

                transform: Scale {
                    origin.x: root.centreX - pill.x
                    origin.y: pill.rowTop + root.rowH / 2
                    xScale: 1 + root.peekAmount * (root.peekScale - 1)
                    yScale: xScale
                }

                // A stable centre target exposes the app strip without intercepting activity controls.
                Item {
                    z: 1
                    x: root.centreX - width / 2 - pill.x
                    y: pill.rowTop
                    width: Math.max(root.rowH, dockSpring.value)
                    height: root.rowH

                    HoverHandler {
                        id: centreHover

                        enabled: root.available && !root.tall
                        blocking: false
                        onHoveredChanged: {
                            if (hovered)
                                dockRevealTimer.restart();
                            else
                                dockRevealTimer.stop();
                        }
                    }
                }

                // The dock, pinned to the centre of the bar
                DockRow {
                    id: dockRow

                    x: root.centreX - width / 2 - pill.x
                    y: pill.rowTop + (root.rowH - height) / 2
                    width: implicitWidth
                    height: implicitHeight
                    itemSize: Math.round(Math.max(root.rowH * 0.8, Math.min(36, root.rowH)))
                    popouts: root.popouts

                    // DockRow uses the same blur fade as the activity content, retaining outgoing icons.
                    presented: root.showDock

                    onContextMenuOpened: root.collapse()
                }

                // Wings: the shown activity's leading / trailing content, revealed as the pill grows. Each
                // sits at the pill's outer end so it is concentric with the rounded end.
                Wing {
                    id: leftWing

                    x: root.centreX - dockSpring.value / 2 - width - pill.x
                    contentWidth: root.shown?.leadingWidth ?? 0
                    contentComponent: root.shown?.leading ?? null
                    alignRight: false

                    HoverHandler {
                        id: leftWingHover

                        enabled: root.mode === "compact" || root.mode === "peek"
                        cursorShape: root.shown?.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Wing {
                    id: rightWing

                    x: root.centreX + dockSpring.value / 2 - pill.x
                    contentWidth: root.shown?.trailingWidth ?? 0
                    contentComponent: root.shown?.trailing ?? null
                    alignRight: true

                    HoverHandler {
                        id: rightWingHover

                        enabled: root.mode === "compact" || root.mode === "peek"
                        cursorShape: root.shown?.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }

            // Banners, in two slots that alternate so one can blur out while the next blurs in
            BannerSlot {
                id: slotA

                index: 0
            }

            BannerSlot {
                id: slotB

                index: 1
            }

            // Expanded: the activity's expanded view, laid out at its final size and revealed by the morph
            BlurFade {
                id: expandedContent

                x: (pill.width - width) / 2
                y: root.atBottom ? pill.height - height : 0
                width: root.shown?.expandedWidth ?? 0
                height: root.shown?.expandedHeight ?? 0
                transformOrigin: root.atBottom ? Item.Bottom : Item.Top

                shown: root.mode === "expanded"
                inDelay: 90
                inDuration: 360
                outDuration: 150
                hiddenScale: 0.9

                Loader {
                    anchors.fill: parent
                    asynchronous: true
                    // Start loading while peeking so it is ready when the delay elapses
                    active: root.mode === "peek" || root.mode === "expanded" || expandedContent.visible
                    sourceComponent: root.shown?.expanded ?? null
                }
            }
        }

        // Keep the outline above all activity content, following the same morph as the background.
        Rectangle {
            anchors.fill: parent
            radius: background.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outline, 0.35 * root.outlineAmount)
        }
    }

    // More live activities, as satellite circles beside the pill. Tap one to swap it into the pill.
    // They sit behind the pill, so they emerge from under it, joined by a metaball neck while close.
    Satellite {
        id: leftSatellite

        z: -1
        side: -1
    }

    Satellite {
        id: rightSatellite

        z: -1
        side: 1
    }

    GooBridge {
        z: -1
        satellite: leftSatellite
    }

    GooBridge {
        z: -1
        satellite: rightSatellite
    }

    // A live activity's circle beside the pill. It emerges from the pill's end with a goo separation, and
    // merges back into it to leave or change activity. `detach` runs 0 (inside the pill) to 1 (separated).
    component Satellite: Item {
        id: sat

        required property int side // -1 left, 1 right
        readonly property Activity want: side < 0 ? root.leftActivity : root.rightActivity
        // Stays out through the hover swell (peek), and merges away just before the island expands
        readonly property bool present: root.mode === "compact" || (root.mode === "peek" && !root.expandImminent)

        // The activity drawn, which lags `want` so the old one can merge away first
        property Activity activity: null
        property real detach: 0
        property bool contentShown: false
        // Driven by the swap chain (root.chainMerge) instead of its own animations
        property bool locked: false
        readonly property bool busy: locked || emergeAnim.running || retractAnim.running

        readonly property real d: locked ? root.chainMerge : detach
        readonly property real size: root.rowH * (0.7 + 0.3 * Math.max(0, Math.min(1, d)))
        // Centre inside the pill's rounded end, and centre once separated by satelliteGap
        readonly property real innerX: side > 0 ? pill.x + pill.width - root.rowH / 2 : pill.x + root.rowH / 2
        readonly property real outerX: side > 0 ? pill.x + pill.width + root.satelliteGap + root.rowH / 2 : pill.x - root.satelliteGap - root.rowH / 2

        // Step towards `want`: merge away a stale activity, then emerge with the new one
        function sync(): void {
            if (busy)
                return;
            const target = present ? want : null;
            if (activity && activity !== target) {
                retractAnim.start();
                return;
            }
            if (target && (activity !== target || detach < 1)) {
                activity = target;
                emergeAnim.start();
                return;
            }
            contentShown = activity !== null;
        }

        x: innerX + (outerX - innerX) * d - width / 2
        y: root.rowY + (root.rowH - height) / 2
        width: size
        height: size
        visible: d > 0.001 && pill.visible

        onWantChanged: sync()
        onPresentChanged: sync()
        Component.onCompleted: sync()

        SequentialAnimation {
            id: emergeAnim

            ScriptAction {
                script: sat.contentShown = true
            }
            // Slow at the end, so the neck visibly stretches and pinches off
            NumberAnimation {
                target: sat
                property: "detach"
                to: 1
                duration: 480
                easing.type: Easing.OutCubic
            }
            ScriptAction {
                script: Qt.callLater(sat.sync)
            }
        }

        SequentialAnimation {
            id: retractAnim

            ScriptAction {
                script: sat.contentShown = false
            }
            // Merges straight away; the content blurs out on the way (its activity is kept until merged)
            NumberAnimation {
                target: sat
                property: "detach"
                to: 0
                duration: 260
                easing.type: Easing.InCubic
            }
            ScriptAction {
                script: {
                    sat.activity = null;
                    Qt.callLater(sat.sync);
                }
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainer
        }

        // Content comes in as the circle pulls away, and leaves before it merges back
        BlurFade {
            anchors.centerIn: parent
            width: root.rowH
            height: root.rowH
            shown: sat.contentShown
            hiddenScale: 0.8
            inDelay: 100
            inDuration: 220
            outDuration: 120

            Loader {
                anchors.centerIn: parent
                sourceComponent: sat.activity?.bubble ?? null
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: sat.contentShown && !sat.busy
            onTapped: root.swapWith(sat)
        }
    }

    // Metaball neck between a satellite and the pill's rounded end (Hiroyuki Sato's metaball connector):
    // two cubic curves tangent to both circles. The neck spreads while they overlap and narrows to nothing
    // as the gap reaches gooReach, so it stretches and snaps as the circle separates.
    component GooBridge: Shape {
        id: bridge

        required property Satellite satellite
        readonly property var g: {
            const s = satellite;
            if (!s.visible)
                return null;
            const r1 = background.radius;
            const r2 = s.width / 2;
            const c2x = s.x + r2;
            const c2y = s.y + r2;
            const c1x = s.side > 0 ? pill.x + pill.width - r1 : pill.x + r1;
            const c1y = Math.max(pill.y + r1, Math.min(pill.y + pill.height - r1, c2y));
            return root.metaball(c1x, c1y, r1, c2x, c2y, r2, root.gooReach);
        }

        anchors.fill: parent
        visible: g !== null
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Colours.palette.m3surfaceContainer
            strokeWidth: -1
            strokeColor: "transparent"
            startX: bridge.g?.p1x ?? 0
            startY: bridge.g?.p1y ?? 0

            PathCubic {
                control1X: bridge.g?.h1x ?? 0
                control1Y: bridge.g?.h1y ?? 0
                control2X: bridge.g?.h3x ?? 0
                control2Y: bridge.g?.h3y ?? 0
                x: bridge.g?.p3x ?? 0
                y: bridge.g?.p3y ?? 0
            }
            // The chords close the shape inside the circles, which are drawn over it in the same colour
            PathLine {
                x: bridge.g?.p4x ?? 0
                y: bridge.g?.p4y ?? 0
            }
            PathCubic {
                control1X: bridge.g?.h4x ?? 0
                control1Y: bridge.g?.h4y ?? 0
                control2X: bridge.g?.h2x ?? 0
                control2Y: bridge.g?.h2y ?? 0
                x: bridge.g?.p2x ?? 0
                y: bridge.g?.p2y ?? 0
            }
            PathLine {
                x: bridge.g?.p1x ?? 0
                y: bridge.g?.p1y ?? 0
            }
        }
    }

    component Wing: BlurFade {
        id: wing

        property real contentWidth
        property Component contentComponent
        property bool alignRight

        y: pill.rowTop
        width: contentWidth
        height: root.rowH

        Behavior on contentWidth {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        shown: (root.mode === "compact" || root.mode === "peek") && !root.swapping
        inDelay: root.fromMode === "expanded" || root.fromMode === "banner" ? 140 : 90
        inDuration: 300
        outDuration: 140

        TapHandler {
            enabled: wing.shown && (root.shown?.expandable ?? false)
            onTapped: root.expandActivity(root.shown)
        }

        Item {
            x: wing.alignRight ? wing.width - width : 0
            width: wing.contentWidth
            height: wing.height

            Loader {
                anchors.centerIn: parent
                sourceComponent: wing.contentComponent
            }
        }
    }

    component BannerSlot: BlurFade {
        id: slot

        required property int index
        property var banner: null
        readonly property bool isCurrent: root.activeSlot === index && root.mode === "banner"

        x: (pill.width - width) / 2
        y: root.atBottom ? pill.height - height : 0
        width: Math.min(root.maxWidth, Math.max(root.baseWidth, loader.item?.implicitWidth ?? 0))
        height: loader.item?.implicitHeight ?? root.bannerH
        transformOrigin: root.atBottom ? Item.Bottom : Item.Top

        shown: isCurrent
        inDelay: 80
        inDuration: 320
        outDuration: 140
        hiddenScale: 0.9

        // Unload once faded out
        onProgressChanged: {
            if (progress === 0 && !isCurrent) {
                banner = null;
                if (root.pendingBanner)
                    Qt.callLater(() => {
                        if (root.pendingBanner)
                            root.show(root.pendingBanner);
                    });
            }
        }

        Loader {
            id: loader

            anchors.fill: parent
            sourceComponent: slot.banner?.component ?? null
            onLoaded: {
                if ("banner" in item)
                    item.banner = Qt.binding(() => slot.banner);
            }
        }
    }
}
