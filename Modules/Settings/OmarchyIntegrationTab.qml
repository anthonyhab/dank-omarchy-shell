import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: omarchyIntegrationTab

    property var parentModal: null
    property bool omarchyAvailable: SettingsData.omarchyTheme !== ""
    property var themeList: []

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
                height: statusSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: statusSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "info"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Integration Status"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Omarchy theme integration status and diagnostics"
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

                        DankIcon {
                            name: themeList.length > 0 ? "check_circle" : "cancel"
                            size: Theme.iconSize - 2
                            color: themeList.length > 0 ? Theme.primary : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Omarchy Installation"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: themeList.length > 0 ? "Omarchy is installed and detected" : "Omarchy not found - install from omarchy-theme-generator"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: SettingsData.omarchyTheme ? "check_circle" : "pending"
                            size: Theme.iconSize - 2
                            color: SettingsData.omarchyTheme ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Active Theme"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: SettingsData.omarchyTheme || "No theme currently active"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                                font.family: "monospace"
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: filePathsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: filePathsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "folder"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "File Paths"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Important file locations for Omarchy integration"
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
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Theme Colors File"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Rectangle {
                                width: parent.width
                                height: colorsPath.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius / 2
                                color: Theme.surfaceContainerLow
                                border.color: Theme.borderMedium
                                border.width: 1

                                StyledText {
                                    id: colorsPath
                                    anchors.centerIn: parent
                                    text: "~/.config/omarchy/current/theme/dank.colors"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "monospace"
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Theme Generator Script"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Rectangle {
                                width: parent.width
                                height: scriptPath.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius / 2
                                color: Theme.surfaceContainerLow
                                border.color: Theme.borderMedium
                                border.width: 1

                                StyledText {
                                    id: scriptPath
                                    anchors.centerIn: parent
                                    text: "scripts/omarchy/dank-shell.py"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "monospace"
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Template Directory"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Rectangle {
                                width: parent.width
                                height: templatePath.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius / 2
                                color: Theme.surfaceContainerLow
                                border.color: Theme.borderMedium
                                border.width: 1

                                StyledText {
                                    id: templatePath
                                    anchors.centerIn: parent
                                    text: "scripts/omarchy/templates/"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "monospace"
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: scriptsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: scriptsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "terminal"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Integration Scripts"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Omarchy hook scripts and theme generation tools"
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
                            text: "Available Commands"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: [
                                    {"cmd": "omarchy-theme-list", "desc": "List all available themes"},
                                    {"cmd": "omarchy-theme-current", "desc": "Get current theme name"},
                                    {"cmd": "omarchy-theme-set <name>", "desc": "Apply a theme by name"},
                                    {"cmd": "scripts/omarchy/dank-shell.py <theme>", "desc": "Generate toolkit themes"}
                                ]

                                Rectangle {
                                    width: parent.width
                                    height: cmdRow.implicitHeight + Theme.spacingS * 2
                                    radius: Theme.cornerRadius / 2
                                    color: Theme.surfaceContainerLow
                                    border.color: Theme.borderMedium
                                    border.width: 1

                                    Column {
                                        id: cmdRow
                                        anchors.centerIn: parent
                                        width: parent.width - Theme.spacingM * 2
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: modelData.cmd
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: "monospace"
                                            color: Theme.primary
                                        }

                                        StyledText {
                                            text: modelData.desc
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: aboutSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: aboutSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "auto_awesome"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "About Omarchy Integration"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Dynamic theming system for DankShell"
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

                    StyledText {
                        text: "Omarchy provides dynamic theme generation from wallpapers with Material Design 3 color schemes. Themes automatically update the shell, Qt applications, and Firefox.\n\nThe integration includes:\n• Real-time theme switching via DankBar widget\n• Automatic color extraction and application\n• Qt5/Qt6 toolkit theming\n• Firefox color scheme generation\n• Workspace customization support"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        lineHeight: 1.4
                    }
                }
            }
        }
    }
}
