import QtQuick

// A square slot for banner/expanded layouts. Make it as tall as the pill and put it at either end of
// a row: content centred in it is then concentric with the pill's rounded end.
Item {
    required property real size

    implicitWidth: size
    implicitHeight: size
}
