import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    readonly property string baseDir: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell"
    readonly property string filesDir: baseDir + "/notepad-files"
    readonly property string metadataPath: baseDir + "/notepad-session.json"

    property var tabs: []
    property int currentTabIndex: 0
    property var tabsBeingCreated: ({})

    Component.onCompleted: {
        ensureDirectoryProcess.running = true
    }

    Process {
        id: ensureDirectoryProcess
        command: ["mkdir", "-p", root.filesDir]
        onExited: loadMetadata()
    }

    FileView {
        id: metadataFile
        path: root.metadataPath
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            try {
                var data = JSON.parse(text())
                root.tabs = data.tabs || []
                root.currentTabIndex = data.currentTabIndex || 0
                migrateLegacyTabs()
                validateTabs()
            } catch(e) {
                console.warn("Failed to parse notepad metadata:", e)
                createDefaultTab()
            }
        }

        onLoadFailed: {
            // Try to migrate from legacy session.json if notepad-session.json doesn't exist
            migrateLegacySessionData()
        }
    }

    function migrateLegacyTabs() {
        // Check if we need to migrate old tab format
        var needsSave = false
        for (var i = 0; i < tabs.length; i++) {
            var tab = tabs[i]
            // Check for old format with fileUrl property or other legacy properties
            if (tab.fileUrl || tab.fileName) {
                var newTabs = tabs.slice()
                var filePath = tab.filePath
                var isTemporary = true

                // Handle fileUrl format - this indicates a saved file
                if (tab.fileUrl) {
                    var url = tab.fileUrl.toString()
                    if (url.startsWith("file://")) {
                        url = url.substring(7) // Remove file:// prefix
                    }
                    filePath = url  // Use the actual saved file path
                    isTemporary = false  // Saved files are not temporary
                }

                // Create clean tab object with only the new format properties
                newTabs[i] = {
                    id: tab.id || Date.now(),
                    title: tab.fileName || tab.title || "Untitled",
                    filePath: filePath,
                    isTemporary: isTemporary,
                    lastModified: tab.lastModified || new Date().toISOString(),
                    cursorPosition: tab.cursorPosition || 0,
                    scrollPosition: tab.scrollPosition || 0
                }
                tabs = newTabs
                needsSave = true
            }
        }
        if (needsSave) {
            console.log("Migrated legacy tab format")
            saveMetadata()
        }
    }

    function migrateLegacySessionData() {
        // Try to load from old session.json
        var legacyLoader = legacySessionLoaderComponent.createObject(root)
    }

    function loadMetadata() {
        metadataFile.path = ""
        metadataFile.path = root.metadataPath
    }

    function createDefaultTab() {
        var id = Date.now()
        var filePath = "notepad-files/untitled-" + id + ".txt"
        var fullPath = baseDir + "/" + filePath

        // Mark this tab as being created first
        var newTabsBeingCreated = Object.assign({}, tabsBeingCreated)
        newTabsBeingCreated[id] = true
        tabsBeingCreated = newTabsBeingCreated

        // Create file first, then add tab
        createEmptyFile(fullPath, function() {
            root.tabs = [{
                id: id,
                title: "Untitled",
                filePath: filePath,
                isTemporary: true,
                lastModified: new Date().toISOString(),
                cursorPosition: 0,
                scrollPosition: 0
            }]
            root.currentTabIndex = 0

            // Mark creation complete
            var updatedTabsBeingCreated = Object.assign({}, tabsBeingCreated)
            delete updatedTabsBeingCreated[id]
            tabsBeingCreated = updatedTabsBeingCreated
            saveMetadata()
        })
    }

    function saveMetadata() {
        var metadata = {
            version: 1,
            currentTabIndex: currentTabIndex,
            tabs: tabs
        }
        metadataFile.setText(JSON.stringify(metadata, null, 2))
    }

    function loadTabContent(tabIndex, callback) {
        if (tabIndex < 0 || tabIndex >= tabs.length) {
            callback("")
            return
        }

        var tab = tabs[tabIndex]
        var fullPath = tab.isTemporary
                        ? baseDir + "/" + tab.filePath
                        : tab.filePath

        // Check if this tab is currently being created
        if (tabsBeingCreated[tab.id]) {
            // Wait a bit and try again
            Qt.callLater(() => {
                loadTabContent(tabIndex, callback)
            })
            return
        }

        // Load the file - it should already exist from tab creation
        var loader = tabFileLoaderComponent.createObject(root, {
            path: fullPath,
            callback: callback
        })
    }

    function saveTabContent(tabIndex, content) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var tab = tabs[tabIndex]
        var fullPath = tab.isTemporary
                        ? baseDir + "/" + tab.filePath
                        : tab.filePath

        var saver = tabFileSaverComponent.createObject(root, {
            path: fullPath,
            content: content,
            tabIndex: tabIndex
        })
    }

    function createNewTab() {
        var id = Date.now()
        var filePath = "notepad-files/untitled-" + id + ".txt"
        var fullPath = baseDir + "/" + filePath

        var newTab = {
            id: id,
            title: "Untitled",
            filePath: filePath,
            isTemporary: true,
            lastModified: new Date().toISOString(),
            cursorPosition: 0,
            scrollPosition: 0
        }

        // Mark this tab as being created first
        var newTabsBeingCreated = Object.assign({}, tabsBeingCreated)
        newTabsBeingCreated[id] = true
        tabsBeingCreated = newTabsBeingCreated

        // Create file first, then add tab to array
        createEmptyFile(fullPath, function() {
            var newTabs = tabs.slice()
            newTabs.push(newTab)
            tabs = newTabs
            currentTabIndex = tabs.length - 1

            // Mark creation complete
            var updatedTabsBeingCreated = Object.assign({}, tabsBeingCreated)
            delete updatedTabsBeingCreated[id]
            tabsBeingCreated = updatedTabsBeingCreated
            saveMetadata()
        })

        return newTab
    }

    function closeTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var newTabs = tabs.slice()

        if (newTabs.length <= 1) {
            var id = Date.now()
            var filePath = "notepad-files/untitled-" + id + ".txt"

            // Mark this tab as being created
            var newTabsBeingCreated = Object.assign({}, tabsBeingCreated)
            newTabsBeingCreated[id] = true
            tabsBeingCreated = newTabsBeingCreated

            // Create file first, then update tab
            createEmptyFile(baseDir + "/" + filePath, function() {
                newTabs[0] = {
                    id: id,
                    title: "Untitled",
                    filePath: filePath,
                    isTemporary: true,
                    lastModified: new Date().toISOString(),
                    cursorPosition: 0,
                    scrollPosition: 0
                }
                currentTabIndex = 0
                tabs = newTabs

                var updatedTabsBeingCreated = Object.assign({}, tabsBeingCreated)
                delete updatedTabsBeingCreated[id]
                tabsBeingCreated = updatedTabsBeingCreated
                saveMetadata()
            })
            return
        } else {
            var tabToDelete = newTabs[tabIndex]
            if (tabToDelete.isTemporary) {
                deleteFile(baseDir + "/" + tabToDelete.filePath)
            }

            newTabs.splice(tabIndex, 1)
            if (currentTabIndex >= newTabs.length) {
                currentTabIndex = newTabs.length - 1
            } else if (currentTabIndex > tabIndex) {
                currentTabIndex -= 1
            }
        }

        tabs = newTabs
        saveMetadata()

    }

    function switchToTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        currentTabIndex = tabIndex
        saveMetadata()
    }

    function saveTabAs(tabIndex, userPath) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var tab = tabs[tabIndex]
        var fileName = userPath.split('/').pop()

        if (tab.isTemporary) {
            var tempPath = baseDir + "/" + tab.filePath
            copyFile(tempPath, userPath)
            deleteFile(tempPath)
        }

        var newTabs = tabs.slice()
        newTabs[tabIndex] = Object.assign({}, tab, {
            title: fileName,
            filePath: userPath,
            isTemporary: false,
            lastModified: new Date().toISOString()
        })
        tabs = newTabs
        saveMetadata()

    }

    function updateTabMetadata(tabIndex, properties) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var newTabs = tabs.slice()
        var updatedTab = Object.assign({}, newTabs[tabIndex], properties)
        updatedTab.lastModified = new Date().toISOString()
        newTabs[tabIndex] = updatedTab
        tabs = newTabs
        saveMetadata()

    }

    function validateTabs() {
        var validTabs = []
        for (var i = 0; i < tabs.length; i++) {
            var tab = tabs[i]
            // Keep all tabs - files will be created on demand when needed
            validTabs.push(tab)
        }
        tabs = validTabs

        if (tabs.length === 0) {
            createDefaultTab()
        }
    }

    Component {
        id: tabFileLoaderComponent
        FileView {
            property var callback
            blockLoading: false
            preload: true

            onLoaded: {
                callback(text())
                destroy()
            }

            onLoadFailed: {
                console.warn("NotepadStorageService: Failed to load file:", path, "- returning empty content")
                callback("")
                destroy()
            }
        }
    }

    Component {
        id: tabFileSaverComponent
        FileView {
            property string content
            property int tabIndex
            property var creationCallback

            blockWrites: false
            atomicWrites: true

            Component.onCompleted: setText(content)

            onSaved: {
                if (tabIndex >= 0) {
                    updateTabMetadata(tabIndex, {})
                }
                if (creationCallback) {
                    creationCallback()
                }
                destroy()
            }

            onSaveFailed: {
                console.error("Failed to save tab content")
                if (creationCallback) {
                    creationCallback()
                }
                destroy()
            }
        }
    }

    function createEmptyFile(path, callback) {
        // Ensure path is a local file path, not a URL
        var cleanPath = path.toString()
        if (cleanPath.startsWith("file://")) {
            cleanPath = cleanPath.substring(7)
        }

        // Validate the cleaned path is absolute and in the right location
        if (!cleanPath.startsWith("/")) {
            cleanPath = baseDir + "/" + cleanPath
        }

        var creator = fileCreatorComponent.createObject(root, {
            filePath: cleanPath,
            creationCallback: callback
        })
    }

    function copyFile(source, destination) {
        copyProcess.source = source
        copyProcess.destination = destination
        copyProcess.running = true
    }

    function deleteFile(path) {
        deleteProcess.filePath = path
        deleteProcess.running = true
    }

    Component {
        id: fileCreatorComponent
        QtObject {
            property string filePath
            property var creationCallback

            Component.onCompleted: {
                // Create and verify file accessibility
                var touchProcess = touchProcessComponent.createObject(this, {
                    filePath: filePath,
                    callback: creationCallback
                })
            }
        }
    }

    Component {
        id: touchProcessComponent
        Process {
            property string filePath
            property var callback
            command: ["touch", filePath]

            Component.onCompleted: running = true

            onExited: (exitCode) => {
                if (exitCode === 0) {
                    // Touch succeeded, file is created
                    if (callback) callback()
                } else {
                    console.error("Failed to create file:", filePath)
                    if (callback) callback()
                }
                destroy()
            }
        }
    }


    Process {
        id: copyProcess
        property string source
        property string destination
        command: ["cp", source, destination]
    }

    Process {
        id: deleteProcess
        property string filePath
        command: ["rm", "-f", filePath]
    }

    Component {
        id: legacySessionLoaderComponent
        FileView {
            path: baseDir + "/session.json"
            blockLoading: false

            onLoaded: {
                try {
                    var legacyData = JSON.parse(text())
                    if (legacyData.notepadTabs && legacyData.notepadTabs.length > 0) {
                        console.log("Migrating legacy notepad tabs from session.json")
                        var migratedTabs = []

                        for (var i = 0; i < legacyData.notepadTabs.length; i++) {
                            var oldTab = legacyData.notepadTabs[i]
                            var newTab = {
                                id: oldTab.id || Date.now() + i,
                                title: oldTab.fileName || oldTab.title || "Untitled",
                                filePath: oldTab.fileUrl ? oldTab.fileUrl.toString().replace("file://", "") : ("notepad-files/migrated-" + oldTab.id + ".txt"),
                                isTemporary: !oldTab.fileUrl,
                                lastModified: new Date().toISOString(),
                                cursorPosition: 0,
                                scrollPosition: 0
                            }

                            // If it was a saved file, it should point to the external location
                            if (oldTab.fileUrl) {
                                newTab.isTemporary = false
                            } else if (oldTab.content) {
                                // Create a migrated file for content that wasn't saved externally
                                newTab.isTemporary = true
                                var migratedPath = baseDir + "/" + newTab.filePath
                                createFileWithContent(migratedPath, oldTab.content || "")
                            }

                            migratedTabs.push(newTab)
                        }

                        root.tabs = migratedTabs
                        root.currentTabIndex = Math.min(legacyData.notepadCurrentTabIndex || 0, migratedTabs.length - 1)
                        saveMetadata()
                    } else {
                        createDefaultTab()
                    }
                } catch(e) {
                    console.warn("Failed to migrate legacy session data:", e)
                    createDefaultTab()
                }
                destroy()
            }

            onLoadFailed: {
                console.log("No legacy session.json found, creating default tab")
                createDefaultTab()
                destroy()
            }
        }
    }

    function createFileWithContent(path, content) {
        var creator = tabFileSaverComponent.createObject(root, {
            path: path,
            content: content,
            tabIndex: -1
        })
    }

}