import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.services

// Retain the old glyphs through the outgoing blur, then change text while fully hidden.
// Used by island labels and symbols so live updates follow the same motion as view replacements.
Text {
    id: root

    property bool animate: true
    property real textProgress: 1

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface
    font: Tokens.font.body.small
    opacity: textProgress

    layer.enabled: textProgress > 0 && textProgress < 1
    layer.smooth: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 12
        blur: 1 - root.textProgress
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "textProgress"
                to: 0
                duration: 90
                easing.type: Easing.OutCubic
            }
            PropertyAction {}
            NumberAnimation {
                target: root
                property: "textProgress"
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on x {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }
}
