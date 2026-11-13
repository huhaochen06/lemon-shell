import QtQuick
import QtQuick.Effects

// Apple-style "blur replace": content blurs, shrinks and fades out, and comes back in reverse
Item {
    id: root

    property bool shown
    property int inDelay: 0
    property int inDuration: 320
    property int outDuration: 160
    property real hiddenScale: 0.8
    property real blurMax: 24

    property real progress: 0

    opacity: progress
    scale: hiddenScale + (1 - hiddenScale) * progress
    visible: progress > 0

    // Only pay for the offscreen layer while actually transitioning
    layer.enabled: progress > 0 && progress < 1
    layer.smooth: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: root.blurMax
        blur: 1 - root.progress
    }

    states: State {
        name: "shown"
        when: root.shown

        PropertyChanges {
            root.progress: 1
        }
    }

    transitions: [
        Transition {
            to: "shown"

            SequentialAnimation {
                PauseAnimation {
                    duration: root.inDelay
                }
                NumberAnimation {
                    property: "progress"
                    duration: root.inDuration
                    easing.type: Easing.OutCubic
                }
            }
        },
        Transition {
            from: "shown"

            NumberAnimation {
                property: "progress"
                duration: root.outDuration
                easing.type: Easing.OutQuad
            }
        }
    ]
}
