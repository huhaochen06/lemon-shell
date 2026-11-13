import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property string currentSection: "" // "start", "center" or "end" of the bar entry that opened the popout
    property var dockModel: null
    property string selectedClientAddress: ""
    property bool sidebarOpen: false
    property bool isHorizontal: true

    signal detachRequested(mode: string)
}
