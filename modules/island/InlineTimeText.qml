import QtQuick
import Caelestia.Config
import qs.services

// A label can contain a clock as well as static text ("Running · 0:38 · paused").
// Give the clock its own stable digit slots instead of fading the entire label every second.
Item {
    id: root

    property string text
    property font font: Tokens.font.label.medium
    property color color: Colours.palette.m3onSurface
    property int elide: Text.ElideRight

    readonly property var timeMatch: displayedText.match(/[0-9]+(?::[0-9]{2})+/)
    readonly property string displayedText: width > 0 ? elision.elidedText : text
    readonly property string prefix: timeMatch ? displayedText.slice(0, timeMatch.index) : displayedText
    readonly property string timestamp: timeMatch?.[0] ?? ""
    readonly property string suffix: timeMatch ? displayedText.slice(timeMatch.index + timestamp.length) : ""
    readonly property string widestDigit: {
        let widest = "0";
        for (let digit = 1; digit <= 9; digit++)
            if (fontMetrics.advanceWidth(`${digit}`) > fontMetrics.advanceWidth(widest))
                widest = `${digit}`;
        return widest;
    }
    readonly property real naturalWidth: natural.advanceWidth

    implicitWidth: naturalWidth
    implicitHeight: fontMetrics.height
    clip: true

    FontMetrics {
        id: fontMetrics

        font: root.font
    }

    TextMetrics {
        id: natural

        font: root.font
        text: root.text.replace(/[0-9]+(?::[0-9]{2})+/, value => value.replace(/[0-9]/g, root.widestDigit))
    }

    TextMetrics {
        id: elision

        font: root.font
        text: root.text
        elide: root.elide
        elideWidth: root.width
    }

    Row {
        BlurText {
            text: root.prefix
            font: root.font
            color: root.color
        }

        ClockText {
            id: clock

            // ClockText is aligned by its ink; translate it back to this line's normal baseline.
            y: fontMetrics.ascent + clock.ink.y
            text: root.timestamp
            font: root.font
            colour: root.color
        }

        BlurText {
            text: root.suffix
            font: root.font
            color: root.color
        }
    }
}
