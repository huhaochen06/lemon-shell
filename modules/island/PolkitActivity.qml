pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Polkit (services/Polkit.qml): asks for the password in the island on the focused monitor instead of
// the full screen dialog: shield | what needs it / the command | cancel, then the password field.
// The banner interrupts anything else (even an open expanded view), stays up until the request ends, and
// takes the keyboard while it shows. Enter submits, Escape cancels. When the island can't show it
// (fullscreen app, vertical bar, disabled) the dialog comes back.
Activity {
    id: root

    readonly property var flow: Polkit.flow
    readonly property bool shouldShow: enabled && Polkit.active && island.available && island.isFocusScreen

    // Same split as the dialog: the explanation, and the command when there is one
    readonly property var parts: {
        let msg = (flow?.message ?? "").trim();
        let cmd = "";
        const pkexec = msg.match(/Authentication is needed to run `(.+?)' as the super user/);
        if (pkexec) {
            cmd = pkexec[1];
            msg = qsTr("Run as root");
        } else {
            const tick = msg.match(/`(.+?)`/);
            if (tick) {
                cmd = tick[1];
                msg = msg.replace(tick[0], "").replace(/\s+/g, " ").trim();
            }
        }
        return {
            message: msg,
            command: cmd
        };
    }

    name: "polkit"
    enabled: IslandConfig.polkit.enabled
    priority: 200

    onShouldShowChanged: {
        if (shouldShow)
            post({
                key: "polkit",
                component: authBanner,
                priority: 200,
                duration: 3600,
                requeue: true,
                urgent: true,
                keyboard: true,
                valid: () => root.shouldShow
            });
        else
            dismiss("polkit");
    }

    Component {
        id: authBanner

        Item {
            id: bannerItem

            // Set by the island
            property var banner
            readonly property real slot: root.island.bannerH
            // Padded evenly so the cancel button and the field's round ends are concentric with the corners
            readonly property real inset: root.island.panelPadding
            readonly property string error: root.flow?.supplementaryIsError ? (root.flow?.supplementaryMessage ?? "") : ""

            function submit(): void {
                if (!root.flow || input.text.length === 0)
                    return;
                root.flow.submit(input.text);
                input.text = "";
            }

            function cancel(): void {
                input.text = "";
                root.flow?.cancelAuthenticationRequest();
            }

            implicitWidth: Math.min(460, root.island.maxWidth)
            implicitHeight: inset + root.island.coverSize + Tokens.spacing.medium + (commandBox.visible ? commandBox.height + Tokens.spacing.small : 0) + field.height + inset

            // The island takes the keyboard when this shows; grab it once it's there
            Component.onCompleted: focusTimer.start()

            Timer {
                id: focusTimer

                interval: 50
                repeat: true
                onTriggered: {
                    input.forceActiveFocus();
                    if (input.activeFocus)
                        stop();
                }
            }

            // Wrong password: shake the field
            Connections {
                target: root.flow

                function onAuthenticationFailed(): void {
                    shake.restart();
                }
            }

            RowLayout {
                id: header

                x: root.island.panelShift
                y: root.island.panelShift
                width: parent.width - x * 2
                height: bannerItem.slot
                spacing: Tokens.spacing.small

                IslandSlot {
                    size: bannerItem.slot

                    StyledRect {
                        anchors.centerIn: parent
                        implicitWidth: root.island.coverSize
                        implicitHeight: root.island.coverSize
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        IslandIcon {
                            anchors.fill: parent
                            text: "shield_person"
                            fill: 1
                            fontStyle: Tokens.font.icon.size(Math.round(root.island.coverSize * 0.55)).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }

                InkText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: root.island.coverSize
                    title: qsTr("Authentication required")
                    subtitle: bannerItem.error || root.parts.message
                    subtitleColour: bannerItem.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                }

                IslandSlot {
                    size: bannerItem.slot

                    IslandButton {
                        anchors.centerIn: parent
                        island: root.island
                        icon: "close"
                        variant: "plain"
                        onClicked: bannerItem.cancel()
                    }
                }
            }

            // The command, when there is one
            StyledRect {
                id: commandBox

                x: bannerItem.inset
                y: bannerItem.inset + root.island.coverSize + Tokens.spacing.medium
                width: parent.width - bannerItem.inset * 2
                visible: root.parts.command.length > 0
                height: commandText.implicitHeight + Tokens.padding.small * 2
                radius: root.island.panelInnerRadius
                color: Colours.palette.m3surfaceContainerHigh

                BlurText {
                    id: commandText

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    verticalAlignment: Text.AlignVCenter
                    text: root.parts.command
                    font: Tokens.font.mono.small
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideMiddle
                }
            }

            // Password field: lock | input | submit
            StyledRect {
                id: field

                x: bannerItem.inset
                y: commandBox.visible ? commandBox.y + commandBox.height + Tokens.spacing.small : bannerItem.inset + root.island.coverSize + Tokens.spacing.medium
                width: parent.width - bannerItem.inset * 2
                height: root.island.coverSize
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest
                border.width: input.activeFocus ? 2 : 0
                border.color: bannerItem.error ? Colours.palette.m3error : Colours.palette.m3primary

                SequentialAnimation {
                    id: shake

                    loops: 2

                    NumberAnimation {
                        target: fieldContent
                        property: "anchors.horizontalCenterOffset"
                        to: -6
                        duration: 50
                    }
                    NumberAnimation {
                        target: fieldContent
                        property: "anchors.horizontalCenterOffset"
                        to: 6
                        duration: 100
                    }
                    NumberAnimation {
                        target: fieldContent
                        property: "anchors.horizontalCenterOffset"
                        to: 0
                        duration: 50
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: input.forceActiveFocus()
                }

                Item {
                    id: fieldContent

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: parent.height

                    IslandIcon {
                        id: lockIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        width: field.height - Tokens.padding.small * 2
                        height: width
                        text: "lock"
                        fontStyle: Tokens.font.icon.size(Math.round(field.height * 0.5)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    TextInput {
                        id: input

                        anchors.left: lockIcon.right
                        anchors.right: submitButton.left
                        anchors.leftMargin: Tokens.spacing.small
                        anchors.rightMargin: Tokens.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                        selectionColor: Colours.palette.m3primary
                        selectedTextColor: Colours.palette.m3onPrimary
                        enabled: root.flow?.isResponseRequired ?? true

                        Keys.onReturnPressed: bannerItem.submit()
                        Keys.onEnterPressed: bannerItem.submit()
                        Keys.onEscapePressed: bannerItem.cancel()

                        BlurText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text.length === 0
                            text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || qsTr("Password")
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3outline
                        }
                    }

                    IslandButton {
                        id: submitButton

                        anchors.right: parent.right
                        anchors.rightMargin: Math.round((field.height - height) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: field.height - 8
                        implicitHeight: implicitWidth
                        island: root.island
                        icon: "arrow_forward"
                        variant: input.text.length > 0 ? "primary" : "plain"
                        onClicked: bannerItem.submit()
                    }
                }
            }
        }
    }
}
