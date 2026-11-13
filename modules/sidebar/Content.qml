import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Props props
    required property ScreenState screenState

    property var popouts
    property var utilities
    readonly property bool isBarHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property bool showPopoutSeparator: isBarHorizontal && root.screenState.sidebar && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext" && popouts.currentName !== "activewindow"

    GridLayout {
        id: layout

        anchors.fill: parent
        columns: 1
        rowSpacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: isBarHorizontal ? 1 : 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            NotifDock {
                objectName: "sidebarNotifications"

                props: root.props
                screenState: root.screenState
            }
        }

        // Utilities Separator
        StyledRect {
            visible: utilities && utilities.offsetScale < 1
            Layout.row: Config.bar.position === "bottom" ? 0 : (Config.bar.position === "top" ? 2 : 1)
            Layout.topMargin: Config.bar.position === "bottom" ? 0 : (visible ? 18 : 0)
            Layout.bottomMargin: Config.bar.position === "bottom" ? (visible ? 18 : 0) : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }

        // Popout Separator
        StyledRect {
            visible: showPopoutSeparator
            Layout.row: Config.bar.position === "bottom" ? 2 : 0
            Layout.topMargin: Config.bar.position === "top" ? 0 : 12
            Layout.bottomMargin: Config.bar.position === "top" ? 12 : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
