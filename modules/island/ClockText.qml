import QtQuick
import Caelestia.Config
import qs.services

// A running time ("12:34") for a wing. Sized for the widest digit so it never has to grow as the digits
// change, and to the digits' ink rather than the font's line box (which has room for descenders digits
// don't use), so the island centres the visible numbers.
Item {
    id: root

    property string text
    property font font: Tokens.font.label.medium
    property color colour: Colours.palette.m3onSurface

    readonly property bool numericText: /^[0-9:.,+\-\s]*$/.test(text)

    // The font's digits aren't all the same width
    readonly property string widestDigit: {
        let widest = "0";
        for (let d = 1; d <= 9; d++)
            if (fontMetrics.advanceWidth(`${d}`) > fontMetrics.advanceWidth(widest))
                widest = `${d}`;
        return widest;
    }
    // Ink bounds of the template relative to the baseline (top is negative)
    readonly property rect ink: template.tightBoundingRect

    function updateGlyphs(): void {
        const values = Array.from(numericText ? text : "");
        while (glyphs.count < values.length)
            glyphs.insert(0, {
                glyph: ""
            });
        while (glyphs.count > values.length)
            glyphs.remove(0);
        for (let i = 0; i < values.length; i++)
            glyphs.setProperty(i, "glyph", values[i]);
    }

    implicitWidth: Math.ceil(template.advanceWidth)
    implicitHeight: Math.round(ink.height)

    onTextChanged: updateGlyphs()
    Component.onCompleted: updateGlyphs()

    Behavior on width {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    ListModel {
        id: glyphs
    }

    FontMetrics {
        id: fontMetrics

        font: root.font
    }

    TextMetrics {
        id: template

        font: root.font
        text: root.text.replace(/[0-9]/g, root.widestDigit)
    }

    // Digits change in place without any transition; only the whole time fades in and out.
    BlurFade {
        anchors.fill: parent
        shown: root.numericText
        hiddenScale: 1
        inDuration: 180
        outDuration: 180

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height

            Repeater {
                model: glyphs

                Item {
                    id: slot

                    required property string glyph

                    width: /[0-9]/.test(glyph) ? fontMetrics.advanceWidth(root.widestDigit) : fontMetrics.advanceWidth(glyph)
                    height: root.height

                    Text {
                        x: (parent.width - implicitWidth) / 2
                        y: -Math.round(fontMetrics.ascent + root.ink.y)
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        text: slot.glyph
                        font: root.font
                        color: root.colour

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }
                        }
                    }
                }
            }
        }
    }

    BlurFade {
        anchors.fill: parent
        shown: !root.numericText
        hiddenScale: 1
        inDuration: 180
        outDuration: 180

        BlurText {
            x: (parent.width - implicitWidth) / 2
            y: -Math.round(fontMetrics.ascent + root.ink.y)
            text: root.text
            font: root.font
            color: root.colour
        }
    }
}
