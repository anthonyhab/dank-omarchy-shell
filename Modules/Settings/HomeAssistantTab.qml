import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: homeAssistantTab

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
                height: enableSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: enableSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "home"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - enableToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Enable HomeAssistant"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Integrate with HomeAssistant for smart home control"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: enableToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.homeAssistantEnabled
                            onToggled: checked => {
                                SettingsData.homeAssistantEnabled = checked
                                SettingsData.saveSettings()
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: configSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: configSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "settings"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Configuration"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "HomeAssistant URL"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            DankTextField {
                                id: urlField
                                width: parent.width
                                placeholderText: "http://homeassistant.local:8123"
                                text: SettingsData.homeAssistantUrl
                                onTextChanged: {
                                    SettingsData.homeAssistantUrl = text
                                    SettingsData.saveSettings()
                                }
                            }

                            StyledText {
                                text: "Enter the full URL to your HomeAssistant instance"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Long-Lived Access Token"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            DankTextField {
                                id: tokenField
                                width: parent.width
                                placeholderText: "Enter your long-lived access token"
                                text: SettingsData.homeAssistantToken
                                echoMode: showTokenToggle.checked ? TextInput.Normal : TextInput.Password
                                onTextChanged: {
                                    SettingsData.homeAssistantToken = text
                                    SettingsData.saveSettings()
                                }
                            }

                            DankToggle {
                                id: showTokenToggle
                                text: "Show token"
                                checked: false
                            }

                            StyledText {
                                text: "Generate a long-lived access token in HomeAssistant under Profile → Security"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            Button {
                                id: testButton
                                text: HomeAssistantService.connecting ? "Testing..." : "Test Connection"
                                enabled: !HomeAssistantService.connecting && SettingsData.homeAssistantUrl !== "" && SettingsData.homeAssistantToken !== ""

                                background: Rectangle {
                                    color: parent.enabled ? (parent.hovered ? Theme.primaryHover : Theme.primary) : Theme.surfaceVariant
                                    radius: Theme.cornerRadius
                                    border.color: parent.enabled ? Theme.primary : Theme.outline
                                    border.width: 1
                                }

                                contentItem: StyledText {
                                    text: parent.text
                                    color: parent.enabled ? Theme.primaryText : Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeMedium
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                onClicked: {
                                    HomeAssistantService.testConnection()
                                }
                            }

                            Row {
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: {
                                        if (HomeAssistantService.connecting) return "sync"
                                        if (HomeAssistantService.connected) return "check_circle"
                                        return "error"
                                    }
                                    size: Theme.iconSizeSmall
                                    color: {
                                        if (HomeAssistantService.connecting) return Theme.warning
                                        if (HomeAssistantService.connected) return Theme.success
                                        return Theme.error
                                    }
                                }

                                StyledText {
                                    text: {
                                        if (HomeAssistantService.connecting) return "Connecting..."
                                        if (HomeAssistantService.connected) return "Connected"
                                        if (SettingsData.homeAssistantUrl === "" || SettingsData.homeAssistantToken === "") return "Enter URL and token"
                                        return "Not connected"
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: {
                                        if (HomeAssistantService.connecting) return Theme.warning
                                        if (HomeAssistantService.connected) return Theme.success
                                        return Theme.error
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: entitiesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: HomeAssistantService.connected

                Column {
                    id: entitiesSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "devices"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Connected Entities"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: `Found ${Object.keys(HomeAssistantService.entities).length} entities`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Media Players"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            visible: mediaPlayersRepeater.count > 0
                        }

                        Repeater {
                            id: mediaPlayersRepeater
                            model: {
                                const players = []
                                for (const [entityId, entity] of Object.entries(HomeAssistantService.mediaPlayers)) {
                                    players.push({ entityId, entity })
                                }
                                return players
                            }

                            Rectangle {
                                width: parent.width
                                height: 40
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                                border.width: 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: HomeAssistantService.getEntityIcon(modelData.entityId, modelData.entity)
                                        size: Theme.iconSize
                                        color: {
                                            const state = modelData.entity?.state
                                            if (state === "playing") return Theme.primary
                                            if (state === "paused") return Theme.warning
                                            return Theme.surfaceTextSecondary
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - Theme.spacingS - stateText.width - Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: modelData.entity?.attributes?.friendly_name || modelData.entityId
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: modelData.entity?.attributes?.media_title || "No media"
                                            font.pixelSize: Theme.fontSizeXS
                                            color: Theme.surfaceTextSecondary
                                            elide: Text.ElideRight
                                            width: parent.width
                                            visible: text !== "No media"
                                        }
                                    }

                                    StyledText {
                                        id: stateText
                                        text: (modelData.entity?.state || "unknown").charAt(0).toUpperCase() + (modelData.entity?.state || "unknown").slice(1)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextSecondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: "Other Devices"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            visible: otherEntitiesRepeater.count > 0
                        }

                        Repeater {
                            id: otherEntitiesRepeater
                            model: {
                                const entities = []
                                for (const [entityId, entity] of Object.entries(HomeAssistantService.entities)) {
                                    if (!entityId.startsWith("media_player.") &&
                                        (entityId.startsWith("light.") || entityId.startsWith("switch.") ||
                                         entityId.startsWith("climate.") || entityId.startsWith("cover.") ||
                                         entityId.startsWith("lock."))) {
                                        entities.push({ entityId, entity })
                                    }
                                }
                                return entities.slice(0, 10)
                            }

                            Rectangle {
                                width: parent.width
                                height: 40
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                                border.width: 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: HomeAssistantService.getEntityIcon(modelData.entityId, modelData.entity)
                                        size: Theme.iconSize
                                        color: {
                                            const state = modelData.entity?.state
                                            if (state === "on" || state === "open" || state === "unlocked") return Theme.primary
                                            return Theme.surfaceTextSecondary
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - Theme.spacingS - stateText.width - Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: modelData.entity?.attributes?.friendly_name || modelData.entityId.split('.')[1].replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    StyledText {
                                        id: stateText
                                        text: (modelData.entity?.state || "unknown").charAt(0).toUpperCase() + (modelData.entity?.state || "unknown").slice(1)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextSecondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: topBarSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: topBarSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "view_headline"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - showTopBarToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Show in Top Bar"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Display HomeAssistant media controls in the top bar"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: showTopBarToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.showHomeAssistant
                            onToggled: checked => {
                                SettingsData.showHomeAssistant = checked
                                SettingsData.saveSettings()
                            }
                        }
                    }
                }
            }
        }
    }
}