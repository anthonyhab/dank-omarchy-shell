import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: omarchyDankBarTab

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
                height: themeSetSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: themeSetSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

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
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Theme Switcher Widget"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Configure the OmarchyThemeSet widget in the DankBar"
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
                            text: "Widget Behavior"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            width: parent.width
                            height: behaviorInfo.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius / 1.5
                            color: Theme.surfaceContainerLow
                            border.color: Theme.borderMedium
                            border.width: 1

                            Column {
                                id: behaviorInfo
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacingM * 2
                                spacing: Theme.spacingXS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "mouse"
                                        size: Theme.iconSize - 4
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Left Click: Apply random theme"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "mouse"
                                        size: Theme.iconSize - 4
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Right Click: Open theme menu"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Widget Position"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "The OmarchyThemeSet widget is positioned in the DankBar via the widget order settings. Visit the DankBar tab in main Settings to adjust widget positioning."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: workspaceSwitcherSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: workspaceSwitcherSection

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
                                text: "Workspace Switcher Widget"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Enhanced workspace switcher with custom icons and Niri/Hyprland support"
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
                            text: "Widget configuration is available in the Workspace tab. The enhanced workspace switcher replaces the default upstream switcher with Omarchy-specific features."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        StyledRect {
                            width: parent.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: Theme.primaryContainer

                            StyledText {
                                anchors.centerIn: parent
                                text: "Configure Workspace Settings"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.weight: Font.Medium
                            }

                            StateLayer {
                                stateColor: Theme.primary
                                cornerRadius: parent.radius
                                onClicked: {
                                    if (parentModal?.parent?.sidebar) {
                                        parentModal.parent.sidebar.currentIndex = 1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: futureModulesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: futureModulesSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "extension"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Future Omarchy Modules"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Additional Omarchy-specific DankBar widgets coming soon"
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

                        Rectangle {
                            width: parent.width
                            height: 150
                            radius: Theme.cornerRadius / 1.5
                            color: Theme.surfaceContainerLow
                            border.color: Theme.borderMedium
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "lightbulb"
                                    size: Theme.iconSize + 4
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Planned Modules"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "• Profile switcher\n• Theme auto-rotation\n• Wallpaper integration"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
