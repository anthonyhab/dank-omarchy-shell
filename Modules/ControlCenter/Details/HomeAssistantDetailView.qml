import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

Rectangle {
    id: root

    implicitHeight: {
        let height = headerRow.height + Theme.spacingM
        if (HomeAssistantService.haAvailable) {
            height += mediaSection.height + Theme.spacingS
            if (Object.keys(HomeAssistantService.entities).length > 1) {
                height += otherDevicesSection.height + Theme.spacingS
            }
        } else {
            height += connectionSection.height + Theme.spacingS
        }
        return height
    }

    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.6)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    readonly property var appletvEntity: HomeAssistantService.appletvEntity || null
    readonly property bool appletvAvailable: HomeAssistantService.appletvAvailable || false
    readonly property string currentState: HomeAssistantService.appletvState || "unknown"
    readonly property string currentTitle: HomeAssistantService.appletvTitle || ""
    readonly property string currentArtist: HomeAssistantService.appletvArtist || ""
    readonly property string currentApp: HomeAssistantService.appletvApp || ""
    readonly property real currentPosition: HomeAssistantService.appletvPosition || 0
    readonly property real currentDuration: HomeAssistantService.appletvDuration || 0
    readonly property real currentVolume: HomeAssistantService.appletvVolume || 0
    readonly property bool isMuted: HomeAssistantService.appletvMuted || false

    Component.onCompleted: {
        if (HomeAssistantService.configValid && !HomeAssistantService.connected) {
            HomeAssistantService.testConnection()
        }
    }

    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: 40

        StyledText {
            id: headerText
            text: "HomeAssistant"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            DankIcon {
                name: {
                    if (HomeAssistantService.connecting) return "sync"
                    if (HomeAssistantService.connected) return "wifi"
                    return "wifi_off"
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
                    return "Disconnected"
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        spacing: Theme.spacingS

        Rectangle {
            id: connectionSection
            visible: !HomeAssistantService.haAvailable
            width: parent.width
            height: 80
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.errorContainer.r, Theme.errorContainer.g, Theme.errorContainer.b, 0.1)
            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                StyledText {
                    text: "HomeAssistant Unavailable"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.error
                    font.weight: Font.Medium
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: HomeAssistantService.configValid ? "Check connection and server" : "Configure in Settings"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextSecondary
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Rectangle {
            id: mediaSection
            visible: HomeAssistantService.haAvailable
            width: parent.width
            height: mediaColumn.height + Theme.spacingM
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1

            Column {
                id: mediaColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankIcon {
                        name: HomeAssistantService.getMediaIcon(currentState)
                        size: Theme.iconSizeLarge
                        color: appletvAvailable ? Theme.primary : Theme.surfaceTextSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSizeLarge - Theme.spacingS - volumeButton.width - Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: {
                                if (!appletvAvailable) return "Apple TV (Unavailable)"
                                if (currentState === "off") return "Apple TV (Off)"
                                if (currentState === "idle") return currentApp
                                let title = currentTitle || "No Media"
                                if (currentArtist && currentArtist !== "null") {
                                    title = currentArtist + " - " + title
                                }
                                return title
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            text: {
                                if (!appletvAvailable) return "Check Apple TV connection"
                                if (currentState === "playing") return "Playing"
                                if (currentState === "paused") return "Paused"
                                if (currentState === "idle") return "Ready"
                                return currentState.charAt(0).toUpperCase() + currentState.slice(1)
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextSecondary
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            visible: currentDuration > 0 && currentPosition >= 0
                            text: `${HomeAssistantService.formatTime(currentPosition)} / ${HomeAssistantService.formatTime(currentDuration)}`
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextSecondary
                            font.family: Theme.monoFontFamily
                        }
                    }

                    DankIcon {
                        id: volumeButton
                        name: isMuted ? "volume_off" : "volume_up"
                        size: Theme.iconSize
                        color: appletvAvailable ? (isMuted ? Theme.error : Theme.surfaceText) : Theme.surfaceTextSecondary
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: HomeAssistantService.toggleMute()
                        }
                    }
                }

                DankSlider {
                    id: volumeSlider
                    width: parent.width
                    visible: appletvAvailable
                    enabled: appletvAvailable && !isMuted
                    minimum: 0
                    maximum: 100
                    value: Math.round(currentVolume * 100)
                    onSliderDragFinished: finalValue => HomeAssistantService.setVolume(finalValue / 100)

                    leftIcon: "volume_up"
                }

                DankSlider {
                    id: progressSlider
                    width: parent.width
                    visible: appletvAvailable && currentDuration > 0
                    enabled: appletvAvailable && currentState !== "idle"
                    minimum: 0
                    maximum: Math.round(currentDuration)
                    value: Math.round(currentPosition)
                    onSliderDragFinished: finalValue => HomeAssistantService.mediaSeek(finalValue)

                    leftIcon: "fast_forward"
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "skip_previous"
                        size: Theme.iconSizeLarge
                        color: appletvAvailable ? Theme.surfaceText : Theme.surfaceTextSecondary

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: HomeAssistantService.mediaPrevious()
                        }
                    }

                    DankIcon {
                        name: "replay_30"
                        size: Theme.iconSizeLarge
                        color: appletvAvailable ? Theme.surfaceText : Theme.surfaceTextSecondary

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: HomeAssistantService.mediaSeekBackward()
                        }
                    }

                    DankIcon {
                        name: currentState === "playing" ? "pause" : "play_arrow"
                        size: Theme.iconSizeLarge * 1.5
                        color: appletvAvailable ? Theme.primary : Theme.surfaceTextSecondary

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: HomeAssistantService.mediaPlayPause()
                        }
                    }

                    DankIcon {
                        name: "forward_30"
                        size: Theme.iconSizeLarge
                        color: appletvAvailable ? Theme.surfaceText : Theme.surfaceTextSecondary

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: HomeAssistantService.mediaSeekForward()
                        }
                    }

                    DankIcon {
                        name: "skip_next"
                        size: Theme.iconSizeLarge
                        color: appletvAvailable ? Theme.surfaceText : Theme.surfaceTextSecondary

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: HomeAssistantService.mediaNext()
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingL

                    DankIcon {
                        name: "power_settings_new"
                        size: Theme.iconSize
                        color: appletvAvailable ? (currentState === "off" ? Theme.error : Theme.surfaceText) : Theme.surfaceTextSecondary

                        MouseArea {
                            anchors.fill: parent
                            enabled: appletvAvailable
                            onClicked: {
                                if (currentState === "off") {
                                    HomeAssistantService.turnOn()
                                } else {
                                    HomeAssistantService.turnOff()
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: otherDevicesSection
            visible: HomeAssistantService.haAvailable && Object.keys(HomeAssistantService.entities).length > 1
            width: parent.width
            height: otherDevicesColumn.height + Theme.spacingM
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1

            Column {
                id: otherDevicesColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXS

                StyledText {
                    text: "Other Devices"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }

                Repeater {
                    model: {
                        const entities = []
                        for (const [entityId, entity] of Object.entries(HomeAssistantService.entities)) {
                            if (entityId !== "media_player.anttv" &&
                                (entityId.startsWith("light.") || entityId.startsWith("switch.") || entityId.startsWith("climate."))) {
                                entities.push({ entityId, entity })
                            }
                        }
                        return entities.slice(0, 5)
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: Theme.cornerRadius
                        color: deviceMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"

                        MouseArea {
                            id: deviceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const domain = modelData.entityId.split('.')[0]
                                if (domain === "light") {
                                    HomeAssistantService.toggleLight(modelData.entityId)
                                } else if (domain === "switch") {
                                    HomeAssistantService.toggleSwitch(modelData.entityId)
                                }
                            }
                        }

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
                                    if (state === "on" || state === "playing") return Theme.primary
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
}