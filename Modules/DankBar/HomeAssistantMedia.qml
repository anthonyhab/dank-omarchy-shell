import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    readonly property bool hasActiveMedia: HomeAssistantService.hasActiveMedia || false
    readonly property bool appletvAvailable: HomeAssistantService.appletvAvailable || false
    readonly property string currentState: HomeAssistantService.appletvState || "unknown"
    readonly property string currentTitle: HomeAssistantService.appletvTitle || ""
    readonly property string currentArtist: HomeAssistantService.appletvArtist || ""
    readonly property string currentApp: HomeAssistantService.appletvApp || ""
    readonly property real currentPosition: HomeAssistantService.appletvPosition || 0
    readonly property real currentDuration: HomeAssistantService.appletvDuration || 0

    property bool compactMode: false
    readonly property int textWidth: {
        switch (SettingsData.mediaSize) {
        case 0:
            return 0
        case 2:
            return 240
        default:
            return 160
        }
    }
    readonly property int currentContentWidth: {
        const controlsWidth = 20 + Theme.spacingXS + 24 + Theme.spacingXS + 20
        const iconWidth = 20
        const contentWidth = iconWidth + Theme.spacingXS + controlsWidth
        return contentWidth + (textWidth > 0 ? textWidth + Theme.spacingXS : 0) + horizontalPadding * 2
    }
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent"
        }
        const baseColor = Theme.surfaceTextHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }

    states: [
        State {
            name: "shown"
            when: HomeAssistantService.haAvailable && (appletvAvailable || hasActiveMedia)

            PropertyChanges {
                target: root
                opacity: 1
                width: currentContentWidth
            }
        },
        State {
            name: "hidden"
            when: !HomeAssistantService.haAvailable || (!appletvAvailable && !hasActiveMedia)

            PropertyChanges {
                target: root
                opacity: 0
                width: 0
            }
        }
    ]

    transitions: [
        Transition {
            from: "shown"
            to: "hidden"

            SequentialAnimation {
                NumberAnimation {
                    properties: "opacity"
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    properties: "width"
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        },
        Transition {
            from: "hidden"
            to: "shown"

            SequentialAnimation {
                NumberAnimation {
                    properties: "width"
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    properties: "opacity"
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        },
        Transition {
            NumberAnimation {
                properties: "width,opacity"
                duration: Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }
    ]

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: horizontalPadding
        anchors.rightMargin: horizontalPadding
        spacing: Theme.spacingXS

        DankIcon {
            id: statusIcon
            name: HomeAssistantService.getMediaIcon(currentState)
            size: 20
            color: hasActiveMedia ? Theme.primaryText : Theme.surfaceTextSecondary
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: textContainer
            width: textWidth
            height: parent.height
            color: "transparent"
            visible: textWidth > 0
            clip: true

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: titleText
                    text: {
                        if (!appletvAvailable) return "Apple TV"
                        if (currentState === "off" || currentState === "standby") return "Apple TV (Off)"
                        if (currentState === "idle") return currentApp

                        let title = currentTitle || "No Media"
                        let artist = currentArtist && currentArtist !== "null" ? currentArtist : ""

                        if (artist && textWidth > 180) {
                            return artist + " - " + title
                        } else if (artist && textWidth > 120) {
                            return title + " • " + artist
                        } else {
                            return title
                        }
                    }
                    font.pixelSize: compactMode ? Theme.fontSizeSmall : Theme.fontSizeSmall
                    color: hasActiveMedia ? Theme.surfaceText : Theme.surfaceTextSecondary
                    elide: Text.ElideRight
                    width: parent.width
                    font.weight: Font.Medium
                    visible: SettingsData.mediaSize > 0
                }

                StyledText {
                    id: positionText
                    text: {
                        if (currentDuration > 0 && currentPosition >= 0) {
                            return `${HomeAssistantService.formatTime(currentPosition)} / ${HomeAssistantService.formatTime(currentDuration)}`
                        }
                        if (currentState === "playing") return "Playing"
                        if (currentState === "paused") return "Paused"
                        return ""
                    }
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.surfaceTextSecondary
                    elide: Text.ElideRight
                    width: parent.width
                    visible: SettingsData.mediaSize > 1 && text.length > 0
                    font.family: Theme.monoFontFamily
                }
            }
        }

        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: "skip_previous"
                size: 20
                color: appletvAvailable ? Theme.surfaceText : Theme.surfaceTextSecondary

                MouseArea {
                    anchors.fill: parent
                    enabled: appletvAvailable
                    onClicked: HomeAssistantService.mediaPrevious()
                }
            }

            DankIcon {
                name: currentState === "playing" ? "pause" : "play_arrow"
                size: 24
                color: appletvAvailable ? Theme.primary : Theme.surfaceTextSecondary

                MouseArea {
                    anchors.fill: parent
                    enabled: appletvAvailable
                    onClicked: HomeAssistantService.mediaPlayPause()
                }
            }

            DankIcon {
                name: "skip_next"
                size: 20
                color: appletvAvailable ? Theme.surfaceText : Theme.surfaceTextSecondary

                MouseArea {
                    anchors.fill: parent
                    enabled: appletvAvailable
                    onClicked: HomeAssistantService.mediaNext()
                }
            }
        }
    }

    Rectangle {
        id: progressBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: "transparent"
        visible: hasActiveMedia && currentDuration > 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: {
                if (currentDuration > 0 && currentPosition >= 0) {
                    return parent.width * (currentPosition / currentDuration)
                }
                return 0
            }
            color: Theme.primary
            opacity: 0.7

            Behavior on width {
                NumberAnimation { duration: Theme.shortDuration }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onWheel: (wheel) => {
            if (!appletvAvailable) return
            if (wheel.angleDelta.y > 0) {
                HomeAssistantService.volumeUp()
            } else {
                HomeAssistantService.volumeDown()
            }
        }
        onClicked: (mouse) => {
            if (!appletvAvailable) return

            if (mouse.button === Qt.LeftButton) {
                root.clicked()
            } else if (mouse.button === Qt.MiddleButton) {
                HomeAssistantService.mediaSeekForward()
            } else if (mouse.button === Qt.RightButton) {
                HomeAssistantService.mediaNext()
            }
        }
    }
}