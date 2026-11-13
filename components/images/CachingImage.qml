import QtQuick
import Quickshell

// Compatibility shim for Midnight components that still use CachingImage.
// Caelestia replaced the C++ image cache behind it with Caelestia.Multimedia's
// Visual; this keeps the same `path` API on a plain Image decoded at display size.
Image {
    id: root

    property string path

    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    source: path
    sourceSize: {
        const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
        return Qt.size(width * dpr, height * dpr);
    }
}
