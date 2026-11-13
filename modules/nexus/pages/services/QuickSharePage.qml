import QtQuick
import QtQuick.Layouts
import qs.components.controls
import qs.modules.nexus.common
import qs.services
import Caelestia.Config

PageBase {
    id: root

    title: qsTr("Quick Share & AirDrop")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Quick Share (Android)")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable Quick Share")
            subtext: QuickShare.isEnabled ? qsTr("Discoverable by nearby Android devices") : qsTr("Disabled")
            checked: QuickShare.isEnabled
            onToggled: {
                QuickShare.setEnabled(checked);
                QuickShare.setVisible(checked);
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Auto-start on launch")
            subtext: qsTr("Enable Quick Share when the shell starts")
            configNode: root.targetConfig.services
            propertyName: "quickShareAutoStart"
            checked: root.targetConfig.services.quickShareAutoStart
            onToggled: {
                root.targetConfig.services.quickShareAutoStart = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("AirDrop (iPhone, through Owly)")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable AirDrop")
            subtext: AirDrop.isEnabled ? (AirDrop.radioUp ? qsTr("Visible to nearby iPhones") : qsTr("Starting...")) : qsTr("Disabled. Takes Wi-Fi down while on (Intel cards)")
            checked: AirDrop.isEnabled
            onToggled: {
                AirDrop.setEnabled(checked);
                AirDrop.setVisible(checked);
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Auto-start on launch")
            subtext: qsTr("Enable AirDrop when the shell starts")
            checked: AirDrop.autoStart
            onToggled: AirDrop.autoStart = checked
        }
    }
}
