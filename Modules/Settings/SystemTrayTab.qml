import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Item {
    id: root

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacingL
            }
            spacing: Theme.spacingL

            StyledText {
                text: "System Tray Icons"
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
                Layout.fillWidth: true
            }

            StyledText {
                text: "Customize the appearance of system tray icons"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            // Icon Theme Setting
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                StyledText {
                    text: "Icon Theme:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    Layout.minimumWidth: 120
                }

                DankDropdown {
                    Layout.fillWidth: true
                    text: "Icon Theme"
                    description: "Preferred icon theme for system tray"
                    currentValue: SettingsData.systemTrayIconTheme
                    model: ["Adwaita", "breeze", "hicolor"]
                    onValueChanged: {
                        SettingsData.systemTrayIconTheme = value
                        SettingsData.saveSettings()
                    }
                }
            }

            // Use Symbolic Icons Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                StyledText {
                    text: "Use Symbolic Icons:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    Layout.minimumWidth: 120
                }

                DankToggle {
                    checked: SettingsData.systemTrayUseSymbolicIcons
                    onCheckedChanged: {
                        SettingsData.systemTrayUseSymbolicIcons = checked
                        SettingsData.saveSettings()
                    }
                }

                StyledText {
                    text: "Prefer symbolic (outline) icons over full-color icons"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            // Current Tray Items Section
            StyledText {
                text: "Current System Tray Items"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
                Layout.fillWidth: true
            }

            StyledText {
                text: SystemTray.items.values.length > 0
                    ? `Found ${SystemTray.items.values.length} system tray items`
                    : "No system tray items currently active"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                Layout.fillWidth: true
            }

            // List of current tray items with override options
            Repeater {
                model: SystemTray.items.values

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    border.color: Theme.outline
                    border.width: 1

                    property var trayItem: modelData
                    property string appId: trayItem?.id || ""
                    property string currentIcon: trayItem?.icon || ""
                    property string currentOverride: SettingsData.systemTrayIconOverrides[appId] || ""

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: Theme.spacingM
                        }
                        spacing: Theme.spacingM

                        // Current icon preview
                        Rectangle {
                            width: 48
                            height: 48
                            radius: Theme.cornerRadius
                            color: Theme.surfaceVariant

                            IconImage {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                source: parent.parent.parent.currentOverride || parent.parent.parent.currentIcon
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: appId || "Unknown App"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: `Icon: ${currentIcon || "No icon"}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: currentOverride ? `Override: ${currentOverride}` : "No override set"
                                font.pixelSize: Theme.fontSizeSmall
                                color: currentOverride ? Theme.primary : Theme.surfaceVariantText
                            }
                        }

                        ColumnLayout {
                            spacing: Theme.spacingS

                            Button {
                                text: "Set Override"
                                enabled: appId !== ""
                                onClicked: {
                                    // TODO: Open icon picker dialog
                                    const iconName = "input-keyboard-symbolic"
                                    SettingsData.setSystemTrayIconOverride(appId, iconName)
                                }
                            }

                            Button {
                                text: "Remove"
                                enabled: currentOverride !== ""
                                onClicked: {
                                    SettingsData.removeSystemTrayIconOverride(appId)
                                }
                            }
                        }
                    }
                }
            }

            // Quick override section for fcitx5
            Rectangle {
                Layout.fillWidth: true
                height: 80
                radius: Theme.cornerRadius
                color: Theme.primaryBackground
                border.color: Theme.primary
                border.width: 1

                RowLayout {
                    anchors {
                        fill: parent
                        margins: Theme.spacingM
                    }
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Quick Fix for fcitx5:"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Fix fcitx5 Icon"
                        onClicked: {
                            SettingsData.setSystemTrayIconOverride("fcitx5", "input-keyboard-symbolic")
                        }
                    }

                    Button {
                        text: "Reset fcitx5"
                        enabled: SettingsData.systemTrayIconOverrides["fcitx5"] !== undefined
                        onClicked: {
                            SettingsData.removeSystemTrayIconOverride("fcitx5")
                        }
                    }
                }
            }

            // Clear all overrides button
            Button {
                Layout.alignment: Qt.AlignCenter
                text: "Clear All Icon Overrides"
                enabled: Object.keys(SettingsData.systemTrayIconOverrides).length > 0
                onClicked: {
                    SettingsData.clearAllSystemTrayIconOverrides()
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}