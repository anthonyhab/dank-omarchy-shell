import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property var activePlayer: HomeAssistantService.activeMediaPlayer || null
    readonly property bool hasActiveMedia: HomeAssistantService.hasActiveMedia || false
    readonly property bool appletvAvailable: HomeAssistantService.appletvAvailable || false
    readonly property string currentState: HomeAssistantService.appletvState || "unknown"
    readonly property string currentTitle: HomeAssistantService.appletvTitle || ""
    readonly property string currentArtist: HomeAssistantService.appletvArtist || ""
    readonly property string currentApp: HomeAssistantService.appletvApp || ""

    property bool showDetailView: false

    signal detailViewRequested()

    iconName: HomeAssistantService.getMediaIcon(currentState)
    iconColor: isActive ? Theme.primary : Theme.surfaceText
    primaryText: {
        if (!HomeAssistantService.haAvailable) return "HomeAssistant"
        if (!appletvAvailable) return "Apple TV"
        if (currentState === "off" || currentState === "standby") return "Apple TV (Off)"
        if (currentState === "idle") return currentApp

        let text = currentTitle || "No Media"
        if (currentArtist && currentArtist !== "null") {
            text = currentArtist + " - " + text
        }
        return text
    }
    secondaryText: {
        if (!HomeAssistantService.haAvailable) return "Disconnected"
        if (!appletvAvailable) return "Unavailable"
        if (currentState === "playing") return "Playing"
        if (currentState === "paused") return "Paused"
        if (currentState === "idle") return "Ready"
        return currentState.charAt(0).toUpperCase() + currentState.slice(1)
    }
    isActive: hasActiveMedia || currentState === "playing" || currentState === "paused"

    onClicked: {
        if (HomeAssistantService.haAvailable && appletvAvailable) {
            HomeAssistantService.mediaPlayPause()
        }
    }

    onExpandClicked: {
        detailViewRequested()
    }

    onWheelEvent: (wheelEvent) => {
        if (!HomeAssistantService.haAvailable || !appletvAvailable) return

        if (wheelEvent.angleDelta.y > 0) {
            HomeAssistantService.volumeUp()
        } else {
            HomeAssistantService.volumeDown()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton

        onClicked: (mouse) => {
            if (!HomeAssistantService.haAvailable || !appletvAvailable) return

            if (mouse.button === Qt.MiddleButton) {
                HomeAssistantService.mediaSeekForward()
            } else if (mouse.button === Qt.RightButton) {
                HomeAssistantService.mediaNext()
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
        visible: hasActiveMedia && HomeAssistantService.appletvDuration > 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: {
                const duration = HomeAssistantService.appletvDuration
                const position = HomeAssistantService.appletvPosition
                if (duration > 0 && position >= 0) {
                    return parent.width * (position / duration)
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

    StateGroup {
        states: [
            State {
                name: "available"
                when: HomeAssistantService.haAvailable && appletvAvailable
                PropertyChanges {
                    target: root
                    opacity: 1
                }
            },
            State {
                name: "unavailable"
                when: !HomeAssistantService.haAvailable || !appletvAvailable
                PropertyChanges {
                    target: root
                    opacity: 0.6
                }
            }
        ]

        transitions: [
            Transition {
                NumberAnimation {
                    properties: "opacity"
                    duration: Theme.mediumDuration
                    easing.type: Easing.OutCubic
                }
            }
        ]
    }
}