import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    property bool loadingThemes: false
    property bool pendingRandomSelection: false
    property string themeListError: ""
    property var themeOptions: []
    property var shuffledThemeQueue: []
    property bool menuOpen: themeMenuWindow.visible
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS
    readonly property string currentThemeLabel: {
        const slug = slugify(SettingsData.omarchyTheme)
        if (!slug)
            return "Theme…"

        const match = matchDisplayFromSlug(slug)
        if (match)
            return match

        return prettifySlug(slug)
    }
    readonly property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)

    width: contentRow.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground)
            return "transparent"

        const hovered = themeMouseArea.containsMouse
        const base = Theme.widgetBaseBackgroundColor
        const hover = Theme.widgetBaseHoverColor
        const selected = Theme.primaryHover
        const background = menuOpen ? selected : (hovered ? hover : base)
        return Qt.rgba(background.r, background.g, background.b, background.a * Theme.widgetTransparency)
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "palette"
            size: Theme.iconSize - 6
            color: menuOpen || themeMouseArea.containsMouse ? Theme.primary : Theme.surfaceText
        }

        StyledText {
            text: currentThemeLabel
            font.pixelSize: Theme.fontSizeMedium - 1
            color: Theme.surfaceText
            elide: Text.ElideRight
            maximumLineCount: 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: themeMouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
                       if (mouse.button === Qt.LeftButton) {
                           root.selectRandomTheme()
                       } else if (mouse.button === Qt.RightButton) {
                           root.toggleThemeMenu(mouse)
                       }
                   }
    }

    function selectRandomTheme() {
        if (themeOptions.length === 0) {
            pendingRandomSelection = true
            loadThemeList(true)
            return
        }

        ensureThemeQueue()
        if (!shuffledThemeQueue || shuffledThemeQueue.length === 0)
            return

        let nextTheme = shuffledThemeQueue.shift()
        const currentSlug = slugify(SettingsData.omarchyTheme)
        if (currentSlug && slugify(nextTheme) === currentSlug && shuffledThemeQueue.length > 0)
            nextTheme = shuffledThemeQueue.shift()

        if (!nextTheme)
            return

        applyTheme(nextTheme)

        if (!shuffledThemeQueue || shuffledThemeQueue.length === 0)
            rebuildThemeQueue()
    }

    function toggleThemeMenu(mouse) {
        if (themeMenuWindow.visible) {
            themeMenuWindow.visible = false
            return
        }
        loadThemeList(false)
        openThemeMenu(mouse)
    }

    function openThemeMenu(mouse) {
        const globalPoint = root.mapToGlobal(mouse.x, mouse.y)

        let targetScreen = root.parentScreen
        if (!targetScreen && Quickshell.screens && Quickshell.screens.length > 0) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const screen = Quickshell.screens[i]
                const withinX = globalPoint.x >= screen.x && globalPoint.x < screen.x + screen.width
                const withinY = globalPoint.y >= screen.y && globalPoint.y < screen.y + screen.height
                if (withinX && withinY) {
                    targetScreen = screen
                    break
                }
            }
            if (!targetScreen) {
                targetScreen = Quickshell.screens[0]
            }
        }

        themeMenuWindow.screen = targetScreen

        const popupOffset = SettingsData.getPopupYPosition(root.barHeight)
        const screenTop = targetScreen ? targetScreen.y : 0
        const screenHeight = targetScreen ? targetScreen.height : Screen.height

        let anchorY = globalPoint.y
        if (targetScreen) {
            if (SettingsData.dankBarAtBottom) {
                anchorY = screenTop + Math.max(Theme.spacingS, Math.min(screenHeight - Theme.spacingS, screenHeight - popupOffset))
            } else {
                anchorY = screenTop + Math.max(Theme.spacingS, Math.min(screenHeight - Theme.spacingS, popupOffset))
            }
        }

        themeMenuWindow.anchorPoint = Qt.point(globalPoint.x, anchorY)
        themeMenuWindow.anchorAtBottom = SettingsData.dankBarAtBottom

        themeMenuWindow.visible = true
    }

    PanelWindow {
        id: themeMenuWindow

        property point anchorPoint: Qt.point(0, 0)
        property bool anchorAtBottom: false
        property int rowHeight: 36
        property int maxVisibleRows: 8
        property int minVisibleRows: 4
        property int menuWidth: 240
        readonly property real screenLeft: screen ? screen.x : 0
        readonly property real screenTop: screen ? screen.y : 0
        readonly property real screenWidth: screen ? screen.width : 0
        readonly property real screenHeight: screen ? screen.height : 0

        color: "transparent"
        visible: false
        screen: root.parentScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible) {
                const index = root.indexForCurrentTheme()
                if (index >= 0)
                    Qt.callLater(() => themeList.positionViewAtIndex(index, ListView.Center))
            }
        }

        Rectangle {
            id: menuContainer

            readonly property int listRowCount: Math.min(Math.max(themeOptions.length, themeMenuWindow.minVisibleRows), themeMenuWindow.maxVisibleRows)
            readonly property real listHeight: themeMenuWindow.rowHeight * listRowCount

            width: themeMenuWindow.menuWidth
            height: headerText.implicitHeight + Theme.spacingS * 3 + listHeight

            x: {
                const localX = themeMenuWindow.anchorPoint.x - themeMenuWindow.screenLeft
                const centered = localX - width / 2
                const minX = Theme.spacingS
                const maxX = Math.max(minX, themeMenuWindow.screenWidth - width - Theme.spacingS)
                return Math.max(minX, Math.min(maxX, centered))
            }

            y: {
                const localY = themeMenuWindow.anchorPoint.y - themeMenuWindow.screenTop
                const minY = Theme.spacingS
                const maxY = Math.max(minY, themeMenuWindow.screenHeight - height - Theme.spacingS)
                if (themeMenuWindow.anchorAtBottom) {
                    const above = localY - height - Theme.popupDistance
                    return Math.max(minY, Math.min(maxY, above))
                }
                const below = localY + Theme.popupDistance
                return Math.max(minY, Math.min(maxY, below))
            }

            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1

            Column {
                width: parent.width - Theme.spacingS * 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                spacing: Theme.spacingS

                StyledText {
                    id: headerText

                    text: "Theme…"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }

                Item {
                    id: listContainer

                    width: parent.width
                    height: themeMenuWindow.rowHeight * Math.min(Math.max(themeOptions.length, themeMenuWindow.minVisibleRows), themeMenuWindow.maxVisibleRows)
                    clip: true

                    ScrollView {
                        id: menuScroll

                        anchors.fill: parent
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        contentItem: ListView {
                            id: themeList

                            width: menuScroll.width
                            implicitHeight: contentHeight
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: Theme.spacingXS
                            model: themeOptions
                            clip: true

                            delegate: Rectangle {
                                width: themeList.width
                                height: themeMenuWindow.rowHeight
                                radius: Theme.cornerRadius / 1.5
                                readonly property bool selected: root.isCurrentTheme(modelData)
                                color: selected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (delegateMouse.containsMouse ? Theme.surfaceHover : "transparent")

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        border.width: 1
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                        color: selected ? Theme.primary : Theme.surfaceContainerHigh
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: selected ? Theme.primary : Theme.surfaceText
                                        font.weight: selected ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: delegateMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (selected) {
                                            themeMenuWindow.visible = false
                                            return
                                        }
                                        applyTheme(modelData)
                                    }
                                }
                            }
                        }
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        visible: root.loadingThemes
                        running: root.loadingThemes
                        width: 24
                        height: 24
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: !root.loadingThemes && themeOptions.length === 0
                        text: themeListError !== "" ? themeListError : "No themes found"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: themeMenuWindow.visible = false
        }
    }

    function loadThemeList(force) {
        if (loadingThemes)
            return
        if (!force && themeOptions.length > 0)
            return

        loadingThemes = true
        themeListError = ""
        themeListProcess.command = ["sh", "-c", "omarchy-theme-list"]
        themeListProcess.running = true
    }

    function applyTheme(displayName) {
        if (!displayName || displayName.length === 0)
            return

        const slug = slugify(displayName)
        if (slug && slug !== slugify(SettingsData.omarchyTheme))
            SettingsData.setOmarchyTheme(slug)

        const command = "omarchy-theme-set " + shellQuote(displayName)
        Quickshell.execDetached(["sh", "-c", command])
        removeFromQueue(displayName)
        if (themeMenuWindow.visible)
            themeMenuWindow.visible = false
    }

    function slugify(value) {
        if (!value)
            return ""
        const lower = String(value).trim().toLowerCase()
        if (lower.length === 0)
            return ""
        return lower.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    }

    function prettifySlug(slug) {
        if (!slug)
            return ""
        return slug.split('-').filter(part => part.length > 0).map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(' ')
    }

    function matchDisplayFromSlug(slug) {
        if (!slug)
            return ""
        for (var i = 0; i < themeOptions.length; i++) {
            if (slugify(themeOptions[i]) === slug)
                return themeOptions[i]
        }
        return ""
    }

    function isCurrentTheme(displayName) {
        if (!displayName)
            return false
        return slugify(displayName) === slugify(SettingsData.omarchyTheme)
    }

    function indexForCurrentTheme() {
        const slug = slugify(SettingsData.omarchyTheme)
        if (!slug)
            return -1
        for (var i = 0; i < themeOptions.length; i++) {
            if (slugify(themeOptions[i]) === slug)
                return i
        }
        return -1
    }

    function handleThemeListOutput(output) {
        const raw = (output || "").split('\n').map(item => item.trim()).filter(item => item.length > 0)
        themeOptions = raw
        rebuildThemeQueue()
    }

    function ensureRandomSelectionIfPending() {
        if (pendingRandomSelection) {
            pendingRandomSelection = false
            if (themeOptions.length > 0)
                Qt.callLater(() => root.selectRandomTheme())
        }
    }

    function refreshCurrentTheme() {
        currentThemeProcess.command = ["sh", "-c", "omarchy-theme-current"]
        currentThemeProcess.running = true
    }

    function ensureThemeQueue() {
        if (!themeOptions || themeOptions.length === 0)
            return
        if (!shuffledThemeQueue || shuffledThemeQueue.length === 0)
            rebuildThemeQueue()
    }

    function rebuildThemeQueue() {
        if (!themeOptions || themeOptions.length === 0) {
            shuffledThemeQueue = []
            return
        }

        const copy = themeOptions.slice()
        shuffledThemeQueue = shuffle(copy)

        const currentSlug = slugify(SettingsData.omarchyTheme)
        if (currentSlug)
            shuffledThemeQueue = shuffledThemeQueue.filter(name => slugify(name) !== currentSlug)

        if (shuffledThemeQueue.length === 0)
            shuffledThemeQueue = shuffle(themeOptions.slice())
    }

    function removeFromQueue(displayName) {
        if (!shuffledThemeQueue || shuffledThemeQueue.length === 0)
            return
        const slug = slugify(displayName)
        shuffledThemeQueue = shuffledThemeQueue.filter(name => slugify(name) !== slug)
    }

    function shuffle(source) {
        var array = source.slice()
        for (var i = array.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var tmp = array[i]
            array[i] = array[j]
            array[j] = tmp
        }
        return array
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    Process {
        id: themeListProcess
        command: ["sh", "-c", "omarchy-theme-list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.handleThemeListOutput(text)
        }
        onExited: exitCode => {
                      loadingThemes = false
                      if (exitCode !== 0 && themeOptions.length === 0)
                      themeListError = "Failed to load themes"
                      ensureRandomSelectionIfPending()
                  }
    }

    Process {
        id: currentThemeProcess
        command: ["sh", "-c", "omarchy-theme-current"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const displayName = (text || "").trim()
                if (!displayName)
                    return

                const slug = root.slugify(displayName)
                if (!SettingsData.omarchyTheme || SettingsData.omarchyTheme.length === 0 || root.slugify(SettingsData.omarchyTheme) !== slug)
                    SettingsData.setOmarchyTheme(slug)
            }
        }
    }

    Component.onCompleted: {
        refreshCurrentTheme()
        loadThemeList(false)
    }
}
