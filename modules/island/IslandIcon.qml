import QtQuick
import Caelestia.Config
import qs.services

// A Material Symbols icon centred in whatever it fills (put it in a circle or slot with anchors.fill).
// MaterialIcon centres the text's line box, which leaves glyphs off by a pixel or two: each icon sits
// differently in its design grid (the play triangle leans right, more_time's "+" pulls it up and right)
// and the box is snapped to whole pixels. This centres the glyph itself instead:
//  - horizontally on its ink (TextMetrics measures the ligature's glyph exactly)
//  - vertically on its 24-unit design grid: the glyph's advance is one em, and the grid sits on the
//    baseline (TextMetrics doesn't report a glyph's lower edge, so its ink can't be used here)
// and snaps the result to whole pixels.
Item {
    id: root

    property alias text: icon.text
    property alias fontStyle: icon.fontStyle
    property alias fill: icon.fill
    property alias color: icon.color
    property alias animate: icon.animate

    TextMetrics {
        id: inkMetrics

        font: icon.font
        text: icon.text
    }

    BlurText {
        id: icon

        property real fill
        property int grade: Colours.light ? 0 : -25
        property font fontStyle: Tokens.font.icon.small

        // Ink relative to the glyph origin (x) / baseline
        readonly property rect ink: inkMetrics.tightBoundingRect
        // One em: Material Symbols glyphs are all exactly one em wide
        readonly property real em: inkMetrics.advanceWidth

        // Unhinted: native rendering snaps the glyph's outline to the pixel grid, which moves it up to a
        // pixel away from where the metrics say it is
        font: Tokens.font.icon.size(fontStyle.pointSize).weight(fontStyle.weight).fill(fill.toFixed(1)).grade(grade).build()
        renderType: Text.QtRendering

        x: root.width / 2 - (ink.x + ink.width / 2)
        // The grid spans one em up from the baseline; put its middle at our middle
        y: root.height / 2 + em / 2 - baselineOffset
    }
}
