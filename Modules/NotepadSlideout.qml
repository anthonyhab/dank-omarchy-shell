import QtQuick
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

pragma ComponentBehavior: Bound

PanelWindow {
    id: root

    property bool isVisible: false
    property bool fileDialogOpen: false
    property string currentFileName: ""
    property bool hasUnsavedChanges: false
    property url currentFileUrl
    property var targetScreen: null
    property var modelData: null
    property bool confirmationDialogOpen: false
    property string pendingAction: ""
    property string lastSavedFileContent: ""
    property bool expandedWidth: false
    property var currentTab: NotepadStorageService.loaded && NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null
    property int nextTabId: Date.now()
    
    function hasFileChanges() {
        if (!currentTab) return false
        return currentTab.content !== currentTab.lastSavedContent
    }
    
    function getCurrentTabData() {
        return currentTab || {
            id: 0,
            title: "Untitled",
            content: "",
            fileName: "",
            fileUrl: "",
            lastSavedContent: "",
            hasUnsavedChanges: false
        }
    }
    
    function updateCurrentTab(properties, saveImmediately = false) {
        if (!currentTab) return
        
        NotepadStorageService.updateTab(NotepadStorageService.currentTabIndex, properties)
        if (saveImmediately) {
            NotepadStorageService.performSave()
        }
    }
    
    function createNewTab() {
        var newTab = {
            id: ++nextTabId,
            title: "Untitled",
            content: "",
            fileName: "",
            fileUrl: "",
            lastSavedContent: "",
            hasUnsavedChanges: false
        }
        
        var newIndex = NotepadStorageService.addTab(newTab)
        NotepadStorageService.setCurrentTabIndex(newIndex)
        
        textArea.text = ""
        textArea.forceActiveFocus()
        
    }
    
    function closeTab(tabIndex) {
        var tabToClose = NotepadStorageService.tabs[tabIndex]
        var hasChanges = tabToClose && tabToClose.content !== tabToClose.lastSavedContent
        
        if (hasChanges) {
            root.pendingAction = "close_tab_" + tabIndex
            root.confirmationDialogOpen = true
            confirmationDialog.open()
        } else {
            performCloseTab(tabIndex)
        }
    }
    
    function performCloseTab(tabIndex) {
        NotepadStorageService.removeTab(tabIndex)
        
        Qt.callLater(() => {
            if (currentTab) {
                textArea.text = currentTab.content
            }
        })
        
    }
    
    function switchToTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= NotepadStorageService.tabs.length) return

        NotepadStorageService.setCurrentTabIndex(tabIndex)
        
        Qt.callLater(() => {
            if (currentTab) {
                textArea.text = currentTab.content
                root.currentFileName = currentTab.fileName
                root.currentFileUrl = currentTab.fileUrl
                root.lastSavedFileContent = currentTab.lastSavedContent
            }
        })
        
    }

    function show() {
        visible = true
        isVisible = true
        textArea.forceActiveFocus()
    }

    function hide() {
        isVisible = false
    }

    function toggle() {
        if (isVisible) {
            hide()
        } else {
            show()
        }
    }

    visible: isVisible
    screen: modelData
    
    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    
    implicitWidth: 960
    implicitHeight: modelData ? modelData.height : 800
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    StyledRect {
        id: contentRect
        
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: expandedWidth ? 960 : 480
        color: Theme.surfaceContainer
        border.color: Theme.outlineMedium
        border.width: 1
        opacity: isVisible ? SettingsData.popupTransparency : 0
        
        Behavior on opacity {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }
        
        transform: Translate {
            id: slideTransform
            x: isVisible ? 0 : contentRect.width
            
            Behavior on x {
                NumberAnimation {
                    id: slideAnimation
                    duration: 450
                    easing.type: Easing.OutCubic
                    
                    onRunningChanged: {
                        if (!running && !isVisible) {
                            root.visible = false
                        }
                    }
                }
            }
        }
        
        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            // Header
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                
                // Title row
                Row {
                    width: parent.width
                    height: 32

                    Column {
                        width: parent.width - buttonRow.width
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        
                        StyledText {
                            text: qsTr("Notepad")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        id: buttonRow
                        spacing: Theme.spacingXS
                        
                        DankActionButton {
                            id: expandButton
                            iconName: root.expandedWidth ? "unfold_less" : "unfold_more"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.expandedWidth = !root.expandedWidth
                            
                            transform: Rotation {
                                angle: 90
                                origin.x: expandButton.width / 2
                                origin.y: expandButton.height / 2
                            }
                        }
                        
                        DankActionButton {
                            id: closeButton
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.hide()
                        }
                    }
                }
                
                // Tab bar
                Row {
                    width: parent.width
                    height: 36
                    spacing: Theme.spacingXS
                    
                    ScrollView {
                        width: parent.width - newTabButton.width - Theme.spacingXS
                        height: parent.height
                        clip: true
                        
                        ScrollBar.horizontal.visible: false
                        ScrollBar.vertical.visible: false
                        
                        Row {
                            spacing: Theme.spacingXS
                            
                            Repeater {
                                model: NotepadStorageService.tabs
                                
                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    
                                    readonly property bool isActive: NotepadStorageService.currentTabIndex === index
                                    readonly property bool tabHasChanges: modelData.content !== modelData.lastSavedContent
                                    readonly property bool isHovered: tabMouseArea.containsMouse && !closeMouseArea.containsMouse
                                    readonly property real calculatedWidth: {
                                        const textWidth = tabText.paintedWidth || 100
                                        const closeButtonWidth = NotepadStorageService.tabs.length > 1 ? 20 : 0
                                        const spacing = Theme.spacingXS
                                        const padding = Theme.spacingM * 2
                                        return Math.max(120, Math.min(200, textWidth + closeButtonWidth + spacing + padding))
                                    }
                                    
                                    width: calculatedWidth
                                    height: 32
                                    radius: Theme.cornerRadius
                                    color: isActive ? Theme.primaryPressed : isHovered ? Theme.primaryHoverLight : "transparent"
                                    border.width: isActive ? 0 : 1
                                    border.color: Theme.outlineMedium
                                    
                                    MouseArea {
                                        id: tabMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton
                                        
                                        onClicked: switchToTab(index)
                                    }
                                    
                                    Row {
                                        id: tabContent
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        
                                        StyledText {
                                            id: tabText
                                            text: (tabHasChanges ? "● " : "") + (modelData.title || "Untitled")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: isActive ? Theme.primary : Theme.surfaceText
                                            font.weight: isActive ? Font.Medium : Font.Normal
                                            elide: Text.ElideMiddle
                                            maximumLineCount: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Rectangle {
                                            id: tabCloseButton
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: closeMouseArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                                            visible: NotepadStorageService.tabs.length > 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            
                                            DankIcon {
                                                name: "close"
                                                size: 14
                                                color: Theme.surfaceTextMedium
                                                anchors.centerIn: parent
                                            }
                                            
                                            MouseArea {
                                                id: closeMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                z: 100
                                                
                                                onClicked: {
                                                    closeTab(index)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.standardEasing
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    DankActionButton {
                        id: newTabButton
                        width: 32
                        height: 32
                        iconName: "add"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: createNewTab()
                    }
                }
            }

            // Text area
            StyledRect {
                width: parent.width
                height: parent.height - 180
                color: Theme.surface
                border.color: Theme.outlineMedium
                border.width: 1
                radius: Theme.cornerRadius

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true

                    TextArea {
                        id: textArea
                        placeholderText: qsTr("Start typing your notes here...")
                        font.family: SettingsData.monoFontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        selectByMouse: true
                        selectByKeyboard: true
                        wrapMode: TextArea.Wrap
                        focus: root.isVisible
                        activeFocusOnTab: true
                        textFormat: TextEdit.PlainText
                        persistentSelection: true
                        tabStopDistance: 40
                        leftPadding: Theme.spacingM
                        topPadding: Theme.spacingM
                        rightPadding: Theme.spacingM
                        bottomPadding: Theme.spacingM
                        
                        Component.onCompleted: {
                            if (currentTab) {
                                text = currentTab.content
                                root.currentFileName = currentTab.fileName
                                root.currentFileUrl = currentTab.fileUrl
                                root.lastSavedFileContent = currentTab.lastSavedContent
                            }
                        }
                        
                        Connections {
                            target: root
                            function onCurrentTabChanged() {
                                if (currentTab && textArea.text !== currentTab.content) {
                                    textArea.text = currentTab.content
                                    root.currentFileName = currentTab.fileName
                                    root.currentFileUrl = currentTab.fileUrl
                                    root.lastSavedFileContent = currentTab.lastSavedContent
                                }
                            }
                        }
                        
                        onTextChanged: {
                            if (currentTab && text !== currentTab.content) {
                                updateCurrentTab({
                                    content: text,
                                    hasUnsavedChanges: true
                                })
                                autoSaveTimer.restart()
                            }
                        }
                        
                        Keys.onEscapePressed: (event) => {
                            root.hide()
                            event.accepted = true
                        }
                        
                        Keys.onPressed: (event) => {
                            if (event.modifiers & Qt.ControlModifier) {
                                switch (event.key) {
                                case Qt.Key_S:
                                    event.accepted = true
                                    if (currentTab && currentTab.fileUrl) {
                                        saveToFile(currentTab.fileUrl)
                                    } else {
                                        root.fileDialogOpen = true
                                        saveBrowser.open()
                                    }
                                    break
                                case Qt.Key_O:
                                    event.accepted = true
                                    if (hasFileChanges()) {
                                        root.pendingAction = "open"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        root.fileDialogOpen = true
                                        loadBrowser.open()
                                    }
                                    break
                                case Qt.Key_N:
                                    event.accepted = true
                                    if (hasFileChanges()) {
                                        root.pendingAction = "new"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        createNewTab()
                                    }
                                    break
                                case Qt.Key_A:
                                    event.accepted = true
                                    selectAll()
                                    break
                                }
                            }
                        }

                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Bottom controls
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingS
                        DankActionButton {
                            iconName: "save"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.primary
                            enabled: currentTab && (hasFileChanges() || currentTab.content.length > 0)
                            onClicked: {
                                root.fileDialogOpen = true
                                saveBrowser.open()
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Save")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        DankActionButton {
                            iconName: "folder_open"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.secondary
                            onClicked: {
                                if (hasFileChanges()) {
                                    root.pendingAction = "open"
                                    root.confirmationDialogOpen = true
                                    confirmationDialog.open()
                                } else {
                                    root.fileDialogOpen = true
                                    loadBrowser.open()
                                }
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Open")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        DankActionButton {
                            iconName: "note_add"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.surfaceText
                            onClicked: createNewTab()
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("New")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    StyledText {
                        text: currentTab && currentTab.content.length > 0 ? qsTr("%1 characters").arg(currentTab.content.length) : qsTr("Empty")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                    
                    StyledText {
                        text: qsTr("Lines: %1").arg(textArea.lineCount)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        visible: currentTab && currentTab.content.length > 0
                    }

                    StyledText {
                        text: autoSaveTimer.running ? qsTr("Auto-saving...") : (hasFileChanges() ? qsTr("Unsaved changes") : qsTr("Auto-saved"))
                        font.pixelSize: Theme.fontSizeSmall
                        color: hasFileChanges() ? Theme.warning : (autoSaveTimer.running ? Theme.primary : Theme.surfaceTextMedium)
                        opacity: currentTab && currentTab.content.length > 0 ? 1 : 0
                    }
                }
            }
        }
    }

    Timer {
        id: autoSaveTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (currentTab) {
                updateCurrentTab({
                    hasUnsavedChanges: false
                })
                NotepadStorageService.performSave()
            }
        }
    }
    

    property string pendingSaveContent: ""
    
    function saveToFile(fileUrl) {
        if (!currentTab) return

        const content = currentTab.content
        const filePath = fileUrl.toString().replace(/^file:\/\//, '')

        saveFileView.path = ""
        pendingSaveContent = content
        saveFileView.path = filePath

        // Use Qt.callLater to ensure path is set before calling setText
        Qt.callLater(() => {
            saveFileView.setText(pendingSaveContent)
        })
    }    function loadFromFile(fileUrl) {
        const filePath = fileUrl.toString().replace(/^file:\/\//, '')

        loadFileView.path = ""
        loadFileView.path = filePath

        // Wait for the file to be loaded before reading
        if (loadFileView.waitForJob()) {
            Qt.callLater(() => {
                const content = loadFileView.text()
                if (currentTab && content !== undefined && content !== null) {
                    updateCurrentTab({
                        content: content,
                        hasUnsavedChanges: false,
                        lastSavedContent: content
                    })
                    NotepadStorageService.performSave()
                    textArea.text = content
                    root.lastSavedFileContent = content
                }
            })
        } else {
            console.warn("Notepad: Failed to load file - waitForJob returned false")
        }
    }

    FileView {
        id: saveFileView
        blockWrites: true      
        preload: false         
        atomicWrites: true     
        printErrors: true      

        onSaved: {
            if (currentTab && saveFileView.path && pendingSaveContent) {
                updateCurrentTab({
                    hasUnsavedChanges: false,
                    lastSavedContent: pendingSaveContent
                })
                NotepadStorageService.performSave()
                root.lastSavedFileContent = pendingSaveContent
                pendingSaveContent = ""
            }
        }

        onSaveFailed: (error) => {
            console.warn("Notepad: Failed to save file:", error, "Path:", saveFileView.path)
            pendingSaveContent = ""
        }
    }

    FileView {
        id: loadFileView
        blockLoading: true     
        preload: true          
        atomicWrites: true     
        printErrors: true      

        onLoadFailed: (error) => {
            console.warn("Notepad: Failed to load file:", error)
        }
    }

    FileBrowserModal {
        id: saveBrowser

        browserTitle: qsTr("Save Notepad File")
        browserIcon: "save"
        browserType: "notepad_save"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true
        saveMode: true
        defaultFileName: (currentTab && currentTab.fileName) || "note.txt"
        
        WlrLayershell.layer: WlrLayershell.Overlay
        
        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath
            
            root.currentFileName = fileName
            root.currentFileUrl = fileUrl
            
            if (currentTab) {
                updateCurrentTab({
                    title: fileName,
                    fileName: fileName,
                    fileUrl: fileUrl
                })
            }
            
            saveToFile(fileUrl)
            
            if (root.pendingAction === "new") {
                Qt.callLater(() => {
                    createNewTab()
                })
            } else if (root.pendingAction === "open") {
                Qt.callLater(() => {
                    root.fileDialogOpen = true
                    loadBrowser.open()
                })
            } else if (root.pendingAction.startsWith("close_tab_")) {
                Qt.callLater(() => {
                    var tabIndex = parseInt(root.pendingAction.split("_")[2])
                    performCloseTab(tabIndex)
                })
            }
            root.pendingAction = ""
            
            close()
        }
        
        onDialogClosed: {
            root.fileDialogOpen = false
        }
    }

    FileBrowserModal {
        id: loadBrowser

        browserTitle: qsTr("Open Notepad File")
        browserIcon: "folder_open"
        browserType: "notepad_load"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true
        
        WlrLayershell.layer: WlrLayershell.Overlay
        
        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath
            
            root.currentFileName = fileName
            root.currentFileUrl = fileUrl
            
            if (currentTab) {
                updateCurrentTab({
                    title: fileName,
                    fileName: fileName,
                    fileUrl: fileUrl
                })
            }
            
            loadFromFile(fileUrl)
            close()
        }
        
        onDialogClosed: {
            root.fileDialogOpen = false
        }
    }

    DankModal {
        id: confirmationDialog

        width: 400
        height: 180
        shouldBeVisible: false
        allowStacking: true

        onBackgroundClicked: {
            close()
            root.confirmationDialogOpen = false
        }

        content: Component {
            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    confirmationDialog.close()
                    root.confirmationDialogOpen = false
                    event.accepted = true
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width

                        Column {
                            width: parent.width - 40
                            spacing: Theme.spacingXS

                            StyledText {
                                text: qsTr("Unsaved Changes")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: root.pendingAction === "new" ? 
                                      qsTr("You have unsaved changes. Save before creating a new file?") :
                                      root.pendingAction.startsWith("close_tab_") ?
                                      qsTr("You have unsaved changes. Save before closing this tab?") :
                                      qsTr("You have unsaved changes. Save before opening a file?")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceTextMedium
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                        }

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: {
                                confirmationDialog.close()
                                root.confirmationDialogOpen = false
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            Rectangle {
                                width: Math.max(80, discardText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: Theme.cornerRadius
                                color: discardArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                                border.color: Theme.surfaceVariantAlpha
                                border.width: 1

                                StyledText {
                                    id: discardText
                                    anchors.centerIn: parent
                                    text: qsTr("Don't Save")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: discardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmationDialog.close()
                                        root.confirmationDialogOpen = false
                                        if (root.pendingAction === "new") {
                                            createNewTab()
                                        } else if (root.pendingAction === "open") {
                                            root.fileDialogOpen = true
                                            loadBrowser.open()
                                        } else if (root.pendingAction.startsWith("close_tab_")) {
                                            var tabIndex = parseInt(root.pendingAction.split("_")[2])
                                            performCloseTab(tabIndex)
                                        }
                                        root.pendingAction = ""
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.max(70, saveAsText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: Theme.cornerRadius
                                color: saveAsArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                                StyledText {
                                    id: saveAsText
                                    anchors.centerIn: parent
                                    text: qsTr("Save")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.background
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: saveAsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmationDialog.close()
                                        root.confirmationDialogOpen = false
                                        root.fileDialogOpen = true
                                        saveBrowser.open()
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
    }
}