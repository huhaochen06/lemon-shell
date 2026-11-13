pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Sidebar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            configNode: root.targetConfig.sidebar
            propertyName: "enabled"
            checked: root.targetConfig.sidebar.enabled
            onToggled: {
                root.targetConfig.sidebar.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.sidebar.showOnHover
            onToggled: GlobalConfig.sidebar.showOnHover = checked
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the sidebar opens")
            configNode: root.targetConfig.sidebar
            propertyName: "dragThreshold"
            value: root.targetConfig.sidebar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => {
                root.targetConfig.sidebar.dragThreshold = v;
                root.targetConfig.save();
            }
        }
    }
}
