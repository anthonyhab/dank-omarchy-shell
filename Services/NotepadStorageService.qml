pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var tabs: []
    property int currentTabIndex: 0
    property bool loaded: false

    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    readonly property string _stateDir: _stateUrl.startsWith("file://") ? _stateUrl.substring(7) : _stateUrl

    FileView {
        id: storageFile
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell/notepad-data.json"
        blockWrites: true
        atomicWrites: true
        preload: true

        onLoaded: {
            try {
                const data = JSON.parse(text())
                root.tabs = data.tabs || []
                root.currentTabIndex = data.currentTabIndex || 0
                root.loaded = true

                if (root.tabs.length === 0) {
                    createDefaultTab()
                }
            } catch(e) {
                console.warn("NotepadStorageService: Failed to parse notepad data, creating default tab")
                createDefaultTab()
            }
        }

        onLoadFailed: error => {
            console.log("NotepadStorageService: No existing notepad data found, creating default tab")
            createDefaultTab()
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: performSave()
    }

    function createDefaultTab() {
        root.tabs = [{
            id: Date.now(),
            title: "Untitled",
            content: "",
            fileName: "",
            fileUrl: "",
            lastSavedContent: "",
            hasUnsavedChanges: false
        }]
        root.currentTabIndex = 0
        root.loaded = true
        save()
    }

    function save() {
        if (!root.loaded) return
        saveTimer.restart()
    }

    function performSave() {
        if (!root.loaded) return

        storageFile.setText(JSON.stringify({
            tabs: tabs,
            currentTabIndex: currentTabIndex,
            version: 1,
            lastModified: new Date().toISOString()
        }, null, 2))
    }

    function updateTab(index, properties) {
        if (index >= 0 && index < tabs.length) {
            let newTabs = [...tabs]
            newTabs[index] = Object.assign({}, newTabs[index], properties)
            tabs = newTabs
            save()
        }
    }

    function addTab(tabData) {
        let newTabs = [...tabs]
        newTabs.push(tabData)
        tabs = newTabs
        save()
        return newTabs.length - 1
    }

    function removeTab(index) {
        if (tabs.length <= 1) {
            createDefaultTab()
            return
        }

        let newTabs = [...tabs]
        newTabs.splice(index, 1)
        tabs = newTabs

        if (currentTabIndex >= tabs.length) {
            currentTabIndex = tabs.length - 1
        } else if (currentTabIndex > index) {
            currentTabIndex -= 1
        }

        save()
    }

    function setCurrentTabIndex(index) {
        if (index >= 0 && index < tabs.length) {
            currentTabIndex = index
            save()
        }
    }

    function migrateFromSession(sessionTabs, sessionCurrentTabIndex) {
        if (sessionTabs && sessionTabs.length > 0) {
            console.log("NotepadStorageService: Migrating", sessionTabs.length, "tabs from SessionData")
            tabs = sessionTabs
            currentTabIndex = sessionCurrentTabIndex || 0
            loaded = true
            performSave()
            return true
        }
        return false
    }

    Process {
        id: createDirProcess
        command: ["mkdir", "-p", _stateDir + "/DankMaterialShell"]
        running: false

        Component.onCompleted: {
            running = true
        }
    }
}