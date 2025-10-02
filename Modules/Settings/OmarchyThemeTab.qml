import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

Item {
    id: omarchyThemeTab

    property var parentModal: null
    property bool omarchyAvailable: SettingsData.omarchyTheme !== ""
    property var themeList: []
    property bool loadingThemes: false
    property string themeError: ""
    property string searchQuery: ""

    Component.onCompleted: {
        loadThemeList()
        refreshCurrentTheme()
    }

    function loadThemeList() {
        if (loadingThemes) return
        loadingThemes = true
        themeError = ""
        themeListProcess.command = ["sh", "-c", "omarchy-theme-list"]
        themeListProcess.running = true
    }

    function refreshCurrentTheme() {
        currentThemeProcess.command = ["sh", "-c", "omarchy-theme-current"]
        currentThemeProcess.running = true
    }

    function applyTheme(displayName) {
        if (!displayName || displayName.length === 0) return

        const command = "omarchy-theme-set " + shellQuote(displayName)
        Quickshell.execDetached(["sh", "-c", command])
    }

    function selectRandomTheme() {
        if (themeList.length === 0) return
        const randomIndex = Math.floor(Math.random() * themeList.length)
        applyTheme(themeList[randomIndex])
    }

    function slugify(value) {
        if (!value) return ""
        const lower = String(value).trim().toLowerCase()
        if (lower.length === 0) return ""
        return lower.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    }

    function prettifySlug(slug) {
        if (!slug) return ""
        return slug.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    property var filteredThemeList: {
        if (!searchQuery || searchQuery.length === 0) {
            return themeList
        }
        const query = searchQuery.toLowerCase()
        return themeList.filter(theme => theme.toLowerCase().includes(query))
    }

    Process {
        id: themeListProcess
        command: ["sh", "-c", "omarchy-theme-list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (text || "").split('\n').map(item => item.trim()).filter(item => item.length > 0)
                themeList = raw
            }
        }
        onExited: (exitCode) => {
            loadingThemes = false
            if (exitCode !== 0 && themeList.length === 0) {
                themeError = "Failed to load themes. Is Omarchy installed?"
            }
        }
    }

    Process {
        id: currentThemeProcess
        command: ["sh", "-c", "omarchy-theme-current"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const displayName = (text || "").trim()
                if (!displayName) return

                const slug = slugify(displayName)
                if (!SettingsData.omarchyTheme || SettingsData.omarchyTheme.length === 0 || slugify(SettingsData.omarchyTheme) !== slug) {
                    SettingsData.setOmarchyTheme(slug)
                }
            }
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: themeColumn.implicitHeight
        contentWidth: width

        Column {
            id: themeColumn

            width: parent.width
            spacing: Theme.spacingXL
            topPadding: Theme.spacingL

            StyledRect {
                width: parent.width
                height: currentThemeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceCard
                border.color: Theme.borderMedium
                border.width: 1

                Column {
                    id: currentThemeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "palette"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM * 2 - refreshButton.width - randomButton.width - Theme.spacingS
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Current Theme"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: prettifySlug(SettingsData.omarchyTheme) || "No theme set"
                                font.pixelSize: Theme.fontSizeMedium
                                color: SettingsData.omarchyTheme ? Theme.primary : Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankActionButton {
                            id: randomButton
                            anchors.verticalCenter: parent.verticalCenter
                            circular: true
                            iconName: "casino"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: selectRandomTheme()
                        }

                        DankActionButton {
                            id: refreshButton
                            anchors.verticalCenter: parent.verticalCenter
                            circular: true
                            iconName: "refresh"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: {
                                refreshCurrentTheme()
                                loadThemeList()
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: themeSelectionSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceCard
                border.color: Theme.borderMedium
                border.width: 1

                Column {
                    id: themeSelectionSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "list"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Theme Selection"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Browse and select from " + themeList.length + " available themes"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: searchField
                            width: parent.width
                            height: 48
                            placeholderText: "Search themes..."
                            backgroundColor: Theme.surfaceContainerLow
                            normalBorderColor: Theme.borderMedium
                            focusedBorderColor: Theme.primary
                            text: searchQuery
                            onTextChanged: searchQuery = text

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "search"
                                    size: Theme.iconSize - 4
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 350
                            radius: Theme.cornerRadius / 1.5
                            color: Theme.surfaceContainerLow
                            border.color: Theme.borderMedium
                            border.width: 1
                            clip: true

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXS
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                ListView {
                                    id: themeListView

                                    width: parent.width
                                    model: filteredThemeList
                                    spacing: Theme.spacingXS
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Rectangle {
                                        width: themeListView.width
                                        height: 40
                                    radius: Theme.cornerRadius
                                    property bool isSelected: slugify(modelData) === slugify(SettingsData.omarchyTheme)
                                    color: isSelected ? Theme.primary : (themeMouseArea.containsMouse ? Theme.primaryBackgroundMedium : "transparent")
                                    border.color: isSelected ? "transparent" : "transparent"
                                    border.width: 0

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.rightMargin: Theme.spacingS
                                        spacing: Theme.spacingM

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 10
                                            border.width: 2
                                            border.color: parent.parent.isSelected ? Qt.rgba(1, 1, 1, 1) : Theme.borderMedium
                                            color: parent.parent.isSelected ? Qt.rgba(1, 1, 1, 1) : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                width: 10
                                                height: 10
                                                radius: 5
                                                anchors.centerIn: parent
                                                color: Theme.primary
                                                visible: parent.parent.parent.isSelected
                                            }
                                        }

                                        StyledText {
                                            text: modelData
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: parent.parent.isSelected ? Qt.rgba(1, 1, 1, 1) : Theme.textPrimary
                                            font.weight: parent.parent.isSelected ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 20 - Theme.spacingM
                                        }
                                    }

                                    MouseArea {
                                        id: themeMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!parent.isSelected) {
                                                applyTheme(modelData)
                                            }
                                        }
                                    }
                                }

                                    BusyIndicator {
                                        anchors.centerIn: parent
                                        visible: loadingThemes
                                        running: loadingThemes
                                        width: 32
                                        height: 32
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        visible: !loadingThemes && filteredThemeList.length === 0
                                        text: themeError !== "" ? themeError : (searchQuery ? "No themes match search" : "No themes found")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: filteredThemeList.length + " theme" + (filteredThemeList.length !== 1 ? "s" : "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
