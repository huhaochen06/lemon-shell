import QtQuick
import qs.components
import qs.services

// Square audio visualiser, sized to match the cover art beside it. Thin bars spread evenly across the
// square; the bar count follows the size so the spacing stays the same. Needs a ServiceRef on
// Audio.cava somewhere while shown.
Item {
    id: root

    property real size
    property bool playing
    readonly property real barWidth: 2
    readonly property int barCount: Math.max(3, Math.floor((size + 3) / (barWidth + 3)))
    readonly property real gap: (size - barCount * barWidth) / Math.max(1, barCount - 1)

    implicitWidth: size
    implicitHeight: size

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            readonly property var values: Audio.cava?.values ?? []
            readonly property real cavaVal: values.length > index * 2 ? values[index * 2] : 0
            readonly property real minHeight: root.barWidth
            readonly property real targetHeight: root.playing ? Math.max(minHeight, Math.min(root.height, minHeight + cavaVal * (root.height - minHeight))) : minHeight

            x: Math.round(index * (root.barWidth + root.gap))
            y: Math.round((root.height - height) / 2)
            width: root.barWidth
            height: Math.round(targetHeight)
            radius: root.barWidth / 2
            color: Colours.palette.m3primary

            Behavior on height {
                NumberAnimation {
                    duration: 60
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
