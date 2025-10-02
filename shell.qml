//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    id: root

    readonly property bool runGreeter: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    Loader {
        id: dmsShellLoader
        asynchronous: false
        sourceComponent: DMSShell{}
        active: !root.runGreeter
    }

    Loader {
        id: dmsGreeterLoader
        asynchronous: false
        sourceComponent: DMSGreeter{}
        active: root.runGreeter
    }
}
