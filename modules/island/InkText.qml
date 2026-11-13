import QtQuick
import Caelestia.Config
import qs.services

// Two lines of text (title + subtitle) exactly `height` tall, aligned by ink: the top of tall glyphs
// (capitals, ascenders) in the title touches the top edge and the bottom of descenders in the subtitle
// touches the bottom edge. Give it the height of the artwork beside it so the text lines up with it and
// never pokes past. Without a subtitle the title is centred.
//
// The ink comes from fixed reference glyphs rather than the actual text, so the baselines (and the
// spacing between the lines) are the same for every string: a subtitle without descenders doesn't
// slide down, and one with them doesn't slide up.
Item {
    id: root

    property string title
    property string subtitle
    property font titleFont: Tokens.font.label.medium
    property font subtitleFont: Tokens.font.label.small
    property color titleColour: Colours.palette.m3onSurface
    property color subtitleColour: Colours.palette.m3onSurfaceVariant
    // Natural width of the longer line, for sizing the container (independent of the laid out width).
    // Checks for a subtitle rather than subtitleLine.visible, which is false whenever this item is hidden
    // (as when it's only used to measure text)
    readonly property real naturalWidth: Math.ceil(Math.max(titleLine.naturalWidth, subtitle.length > 0 ? subtitleLine.naturalWidth : 0))

    implicitWidth: naturalWidth

    FontMetrics {
        id: titleFontMetrics

        font: root.titleFont
    }

    FontMetrics {
        id: subtitleFontMetrics

        font: root.subtitleFont
    }

    // Reference glyphs: the tallest parts of the title and the deepest descenders of the subtitle
    TextMetrics {
        id: titleRef

        font: root.titleFont
        text: "Hdlkfb"
    }

    TextMetrics {
        id: subtitleRef

        font: root.subtitleFont
        text: "gjpqy"
    }

    InlineTimeText {
        id: titleLine

        // Reference ink relative to the baseline (top is negative); the baseline sits at `ascent`
        readonly property real inkTop: titleFontMetrics.ascent + titleRef.tightBoundingRect.y
        // Cap/ascender top to baseline, for centring a lone title
        readonly property real inkHeight: -titleRef.tightBoundingRect.y

        anchors.left: parent.left
        anchors.right: parent.right
        y: subtitleLine.visible ? -Math.round(inkTop) : Math.round((parent.height - inkHeight) / 2 - inkTop)
        text: root.title
        font: root.titleFont
        color: root.titleColour
        elide: Text.ElideRight
    }

    InlineTimeText {
        id: subtitleLine

        readonly property rect ink: subtitleRef.tightBoundingRect
        readonly property real inkBottom: subtitleFontMetrics.ascent + ink.y + ink.height

        anchors.left: parent.left
        anchors.right: parent.right
        y: Math.round(parent.height - inkBottom)
        visible: text.length > 0
        text: root.subtitle
        font: root.subtitleFont
        color: root.subtitleColour
        elide: Text.ElideRight
    }
}
