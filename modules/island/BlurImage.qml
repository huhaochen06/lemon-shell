import QtQuick
import QtQuick.Effects

// An image is its own replacement unit; its surrounding labels and controls stay untouched.
Image {
    id: root

    property real imageProgress: 0
    property bool waitingForImage: true

    function revealWhenReady(): void {
        if (waitingForImage && status === Image.Ready) {
            waitingForImage = false;
            reveal.restart();
        }
    }

    opacity: imageProgress
    retainWhileLoading: true
    layer.enabled: imageProgress > 0 && imageProgress < 1
    layer.smooth: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 12
        blur: 1 - root.imageProgress
    }

    onStatusChanged: revealWhenReady()

    NumberAnimation {
        id: reveal

        target: root
        property: "imageProgress"
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    Behavior on source {
        onTargetValueChanged: {
            reveal.stop();
            root.waitingForImage = false;
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "imageProgress"
                to: 0
                duration: 90
                easing.type: Easing.OutCubic
            }
            PropertyAction {}
            ScriptAction {
                script: {
                    root.waitingForImage = true;
                    root.revealWhenReady();
                }
            }
        }
    }
}
