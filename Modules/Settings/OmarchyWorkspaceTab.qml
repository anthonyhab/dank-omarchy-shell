import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: omarchyWorkspaceTab

    property var parentModal: null

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: workspaceDisplaySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: workspaceDisplaySection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "view_module"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Workspace Display Options"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Configure how workspaces are displayed in the DankBar"
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

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - showIndexToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Show Workspace Index"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Display workspace number in workspace pills"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: showIndexToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.showWorkspaceIndex
                            onToggled: (checked) => {
                                SettingsData.showWorkspaceIndex = checked
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - showPaddingToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Show Workspace Padding"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Add visual padding around workspace pills"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: showPaddingToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.showWorkspacePadding
                            onToggled: (checked) => {
                                SettingsData.showWorkspacePadding = checked
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - showAppsToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Show Workspace Apps"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Display app icons for running applications in each workspace"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: showAppsToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.showWorkspaceApps
                            onToggled: (checked) => {
                                SettingsData.showWorkspaceApps = checked
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: SettingsData.showWorkspaceApps

                        StyledText {
                            text: "Maximum App Icons"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankSlider {
                                id: maxIconsSlider
                                width: parent.width - maxIconsLabel.width - Theme.spacingM
                                minimum: 1
                                maximum: 10
                                value: SettingsData.maxWorkspaceIcons
                                onSliderValueChanged: (newValue) => {
                                    SettingsData.maxWorkspaceIcons = Math.round(newValue)
                                    SettingsData.saveSettings()
                                }
                            }

                            StyledText {
                                id: maxIconsLabel
                                text: Math.round(maxIconsSlider.value).toString()
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            text: "Maximum number of app icons to show per workspace"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - perMonitorToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Workspaces Per Monitor"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Show only workspaces for the current monitor (Niri only)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: perMonitorToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.workspacesPerMonitor
                            onToggled: (checked) => {
                                SettingsData.workspacesPerMonitor = checked
                                SettingsData.saveSettings()
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: customIconsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: customIconsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "label"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Custom Workspace Icons"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Assign custom icons to workspace names"
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

                        StyledText {
                            text: "Workspace name icons are configured via SettingsData.workspaceNameIcons"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 200
                            radius: Theme.cornerRadius / 1.5
                            color: Theme.surfaceContainerLow
                            border.color: Theme.borderMedium
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "construction"
                                    size: Theme.iconSize + 8
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Workspace Icon Editor"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Coming soon - edit workspace icons visually"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
