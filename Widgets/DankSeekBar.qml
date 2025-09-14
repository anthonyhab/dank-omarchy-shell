import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Widgets

Item {
    id: root

    property MprisPlayer player: null
    property bool isWave: false
    property real currentPosition: 0
    
    readonly property real ratio: {
        if (!player || player.length <= 0) return 0
        return Math.max(0, Math.min(1, currentPosition / player.length))
    }
    
    Timer {
        id: positionTimer
        interval: 500
        running: player && player.positionSupported
        repeat: true
        onTriggered: {
            if (player && player.positionSupported) {
                player.positionChanged()
                root.currentPosition = player.position || 0
            }
        }
    }
    
    onPlayerChanged: {
        if (player && player.positionSupported) {
            currentPosition = player.position || 0
        } else {
            currentPosition = 0
        }
    }

    Loader {
        anchors.fill: parent
        visible: player && player.length > 0
        sourceComponent: isWave ? waveComponent : flatComponent

        Component {
            id: waveComponent

            M3WaveProgress {
                value: root.ratio
                isPlaying: root.player && root.player.playbackState === MprisPlaybackState.Playing

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player && root.player.canSeek && root.player.length > 0

                    onClicked: (mouse) => {
                        if (root.player && root.player.canSeek && root.player.length > 0) {
                            const ratio = Math.max(0, Math.min(1, mouse.x / width))
                            root.player.position = ratio * root.player.length
                        }
                    }
                }
            }
        }

        Component {
            id: flatComponent

            Item {
                property real value: root.ratio
                property real lineWidth: 3
                property color trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                property color fillColor: Theme.primary
                property color playheadColor: Theme.primary

                Rectangle {
                    width: parent.width
                    height: parent.lineWidth
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.trackColor
                    radius: height / 2
                }

                Rectangle {
                    width: Math.max(0, Math.min(parent.width, parent.width * parent.value))
                    height: parent.lineWidth
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.fillColor
                    radius: height / 2
                    Behavior on width { NumberAnimation { duration: 80 } }
                }

                Rectangle {
                    id: playhead
                    width: 3
                    height: Math.max(parent.lineWidth + 8, 14)
                    radius: width / 2
                    color: parent.playheadColor
                    x: Math.max(0, Math.min(parent.width, parent.width * parent.value)) - width / 2
                    y: parent.height / 2 - height / 2
                    z: 3
                    Behavior on x { NumberAnimation { duration: 80 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player && root.player.canSeek && root.player.length > 0

                    onClicked: (mouse) => {
                        if (root.player && root.player.canSeek && root.player.length > 0) {
                            const ratio = Math.max(0, Math.min(1, mouse.x / width))
                            root.player.position = ratio * root.player.length
                        }
                    }
                }
            }
        }
    }
}