import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

Item {
    id: omarchyTab

    property var parentModal: null
    property bool omarchyAvailable: false
    property bool loadingStatus: false
    property int currentSubTab: 0

    Component.onCompleted: {
        checkOmarchyStatus()
    }

    function checkOmarchyStatus() {
        loadingStatus = true
        statusProcess.command = ["sh", "-c", "command -v omarchy-theme-list"]
        statusProcess.running = true
    }

    function prettifySlug(slug) {
        if (!slug) return ""
        return slug.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')
    }

    Process {
        id: statusProcess
        command: ["sh", "-c", "command -v omarchy-theme-list"]
        running: false
        onExited: (exitCode) => {
            loadingStatus = false
            omarchyAvailable = (exitCode === 0)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        spacing: Theme.spacingL

        Row {
            Layout.fillWidth: true
            spacing: Theme.spacingL

            Column {
                width: (parent.width - Theme.spacingL) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: "Active Theme"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    font.weight: Font.Medium
                }

                StyledText {
                    text: prettifySlug(SettingsData.omarchyTheme) || "None"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }
            }

            Column {
                width: (parent.width - Theme.spacingL) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: "Status"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    font.weight: Font.Medium
                }

                Row {
                    spacing: Theme.spacingS

                    DankIcon {
                        name: loadingStatus ? "pending" : (omarchyAvailable ? "check_circle" : "cancel")
                        size: Theme.iconSize - 4
                        color: loadingStatus ? Theme.surfaceVariantText : (omarchyAvailable ? Theme.success : Theme.error)
                        anchors.verticalCenter: parent.verticalCenter

                        RotationAnimator {
                            target: parent
                            running: loadingStatus
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    StyledText {
                        text: loadingStatus ? "Checking..." : (omarchyAvailable ? "Ready" : "Not installed")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderMedium
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingL

            DankTabBar {
                id: tabBar

                Layout.fillWidth: true
                currentIndex: omarchyTab.currentSubTab
                showIcons: true
                model: [
                    {"text": "Theme", "icon": "palette"},
                    {"text": "Workspace", "icon": "workspaces"},
                    {"text": "DankBar", "icon": "toolbar"},
                    {"text": "Integration", "icon": "integration_instructions"}
                ]
                onCurrentIndexChanged: omarchyTab.currentSubTab = currentIndex
            }

            Item {
                id: tabContent

                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: themeLoader

                    anchors.fill: parent
                    active: omarchyTab.currentSubTab === 0
                    visible: active
                    asynchronous: true

                    sourceComponent: OmarchyThemeTab {
                        parentModal: omarchyTab.parentModal
                    }
                }

                Loader {
                    id: workspaceLoader

                    anchors.fill: parent
                    active: omarchyTab.currentSubTab === 1
                    visible: active
                    asynchronous: true

                    sourceComponent: OmarchyWorkspaceTab {
                        parentModal: omarchyTab.parentModal
                    }
                }

                Loader {
                    id: dankBarLoader

                    anchors.fill: parent
                    active: omarchyTab.currentSubTab === 2
                    visible: active
                    asynchronous: true

                    sourceComponent: OmarchyDankBarTab {
                        parentModal: omarchyTab.parentModal
                    }
                }

                Loader {
                    id: integrationLoader

                    anchors.fill: parent
                    active: omarchyTab.currentSubTab === 3
                    visible: active
                    asynchronous: true

                    sourceComponent: OmarchyIntegrationTab {
                        parentModal: omarchyTab.parentModal
                    }
                }
            }
        }
    }
}
