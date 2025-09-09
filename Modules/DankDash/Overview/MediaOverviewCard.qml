import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    property MprisPlayer activePlayer: MprisController.activePlayer
    property real currentPosition: activePlayer?.positionSupported ? activePlayer.position : 0
    property real displayPosition: currentPosition

    readonly property real ratio: {
        if (!activePlayer || activePlayer.length <= 0) return 0
        const calculatedRatio = displayPosition / activePlayer.length
        return Math.max(0, Math.min(1, calculatedRatio))
    }

    onActivePlayerChanged: {
        if (activePlayer?.positionSupported) {
            currentPosition = Qt.binding(() => activePlayer?.position || 0)
        } else {
            currentPosition = 0
        }
    }

    Timer {
        interval: 300
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && !progressMouseArea.isSeeking
        repeat: true
        onTriggered: activePlayer?.positionSupported && activePlayer.positionChanged()
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: !activePlayer

        DankIcon {
            name: "music_note"
            size: Theme.iconSize
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: "No Media"
            font.pixelSize: Theme.fontSizeSmall
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        spacing: Theme.spacingS
        visible: activePlayer

        Item {
            width: 110
            height: 80
            anchors.horizontalCenter: parent.horizontalCenter

            Loader {
                active: activePlayer?.playbackState === MprisPlaybackState.Playing
                sourceComponent: Component {
                    Ref {
                        service: CavaService
                    }
                }
            }

            Shape {
                id: morphingBlob
                width: 110
                height: 110
                anchors.centerIn: parent
                visible: activePlayer?.playbackState === MprisPlaybackState.Playing
                asynchronous: false
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                
                
                readonly property real centerX: width / 2
                readonly property real centerY: height / 2
                readonly property real baseRadius: 35
                readonly property int segments: 24
                
                property var audioLevels: {
                    if (!CavaService.cavaAvailable || CavaService.values.length === 0) {
                        return [0.5, 0.3, 0.7, 0.4, 0.6, 0.5]
                    }
                    return CavaService.values
                }
                
                property var smoothedLevels: [0.5, 0.3, 0.7, 0.4, 0.6, 0.5]
                property var cubics: []

                
                onAudioLevelsChanged: updatePath()
                
                Timer {
                    running: morphingBlob.visible
                    interval: 16
                    repeat: true
                    onTriggered: morphingBlob.updatePath()
                }
                
                Component {
                    id: cubicSegment
                    PathCubic {}
                }
                
                Component.onCompleted: {
                    shapePath.pathElements.push(Qt.createQmlObject(
                        'import QtQuick; import QtQuick.Shapes; PathMove {}', shapePath
                    ))
                    
                    for (let i = 0; i < segments; i++) {
                        const seg = cubicSegment.createObject(shapePath)
                        shapePath.pathElements.push(seg)
                        cubics.push(seg)
                    }
                    
                    updatePath()
                }
                
                function expSmooth(prev, next, alpha) {
                    return prev + alpha * (next - prev)
                }
                
                function updatePath() {
                    if (cubics.length === 0) return
                    
                    for (let i = 0; i < Math.min(smoothedLevels.length, audioLevels.length); i++) {
                        smoothedLevels[i] = expSmooth(smoothedLevels[i], audioLevels[i], 0.2)
                    }
                    
                    const points = []
                    for (let i = 0; i < segments; i++) {
                        const angle = (i / segments) * 2 * Math.PI
                        const audioIndex = i % Math.min(smoothedLevels.length, 6)
                        const audioLevel = Math.max(0.1, Math.min(1.5, (smoothedLevels[audioIndex] || 0) / 50))
                        
                        const radius = baseRadius * (1.0 + audioLevel * 0.3)
                        const x = centerX + Math.cos(angle) * radius
                        const y = centerY + Math.sin(angle) * radius
                        points.push({x: x, y: y})
                    }
                    
                    const startMove = shapePath.pathElements[0]
                    startMove.x = points[0].x
                    startMove.y = points[0].y
                    
                    const tension = 0.5
                    for (let i = 0; i < segments; i++) {
                        const p0 = points[(i - 1 + segments) % segments]
                        const p1 = points[i]
                        const p2 = points[(i + 1) % segments]
                        const p3 = points[(i + 2) % segments]
                        
                        const c1x = p1.x + (p2.x - p0.x) * tension / 3
                        const c1y = p1.y + (p2.y - p0.y) * tension / 3
                        const c2x = p2.x - (p3.x - p1.x) * tension / 3
                        const c2y = p2.y - (p3.y - p1.y) * tension / 3
                        
                        const seg = cubics[i]
                        seg.control1X = c1x
                        seg.control1Y = c1y
                        seg.control2X = c2x
                        seg.control2Y = c2y
                        seg.x = p2.x
                        seg.y = p2.y
                    }
                }
                
                ShapePath {
                    id: shapePath
                    fillColor: Theme.primary
                    strokeColor: "transparent"
                    strokeWidth: 0
                    joinStyle: ShapePath.RoundJoin
                    fillRule: ShapePath.WindingFill
                }
            }

            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Theme.surfaceContainer
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                z: 1

                Image {
                    id: albumArt
                    source: activePlayer?.trackArtUrl || ""
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    cache: true
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: albumArt
                    maskEnabled: true
                    maskSource: circularMask
                    visible: albumArt.status === Image.Ready
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Item {
                    id: circularMask
                    width: 60
                    height: 60
                    layer.enabled: true
                    layer.smooth: true
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                        antialiasing: true
                    }
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "album"
                    size: 20
                    color: Theme.surfaceVariantText
                    visible: albumArt.status !== Image.Ready
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: activePlayer?.trackTitle || "Unknown"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                text: activePlayer?.trackArtist || "Unknown Artist"
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Item {
            id: progressSlider
            width: parent.width
            height: 20
            visible: activePlayer?.length > 0

            property real value: ratio
            property real lineWidth: 2.5
            property color trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
            property color fillColor: Theme.primary
            property color playheadColor: Theme.primary

            Rectangle {
                width: parent.width
                height: progressSlider.lineWidth
                anchors.verticalCenter: parent.verticalCenter
                color: progressSlider.trackColor
                radius: height / 2
            }

            Rectangle {
                width: Math.max(0, Math.min(parent.width, parent.width * progressSlider.value))
                height: progressSlider.lineWidth
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: progressSlider.fillColor
                radius: height / 2
                Behavior on width { NumberAnimation { duration: 80 } }
            }

            Rectangle {
                id: playhead
                width: 2.5
                height: Math.max(progressSlider.lineWidth + 8, 12)
                radius: width / 2
                color: progressSlider.playheadColor
                x: Math.max(0, Math.min(progressSlider.width, progressSlider.width * progressSlider.value)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                z: 3
                Behavior on x { NumberAnimation { duration: 80 } }
            }

            MouseArea {
                id: progressMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: activePlayer ? (activePlayer.canSeek && activePlayer.length > 0) : false

                property bool isSeeking: false
                property real pendingSeekPosition: -1

                Timer {
                    id: seekDebounceTimer
                    interval: 150
                    onTriggered: {
                        if (progressMouseArea.pendingSeekPosition >= 0 && activePlayer?.canSeek && activePlayer?.length > 0) {
                            const clamped = Math.min(progressMouseArea.pendingSeekPosition, activePlayer.length * 0.99)
                            activePlayer.position = clamped
                            progressMouseArea.pendingSeekPosition = -1
                        }
                    }
                }

                onPressed: (mouse) => {
                    isSeeking = true
                    if (activePlayer?.length > 0 && activePlayer?.canSeek) {
                        const r = Math.max(0, Math.min(1, mouse.x / progressSlider.width))
                        pendingSeekPosition = r * activePlayer.length
                        displayPosition = pendingSeekPosition
                        seekDebounceTimer.restart()
                    }
                }
                onReleased: {
                    isSeeking = false
                    seekDebounceTimer.stop()
                    if (pendingSeekPosition >= 0 && activePlayer?.canSeek && activePlayer?.length > 0) {
                        const clamped = Math.min(pendingSeekPosition, activePlayer.length * 0.99)
                        activePlayer.position = clamped
                        pendingSeekPosition = -1
                    }
                    displayPosition = Qt.binding(() => currentPosition)
                }
                onPositionChanged: (mouse) => {
                    if (pressed && isSeeking && activePlayer?.length > 0 && activePlayer?.canSeek) {
                        const r = Math.max(0, Math.min(1, mouse.x / progressSlider.width))
                        pendingSeekPosition = r * activePlayer.length
                        displayPosition = pendingSeekPosition
                        seekDebounceTimer.restart()
                    }
                }
                onClicked: (mouse) => {
                    if (activePlayer?.length > 0 && activePlayer?.canSeek) {
                        const r = Math.max(0, Math.min(1, mouse.x / progressSlider.width))
                        activePlayer.position = r * activePlayer.length
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 32

            Row {
                spacing: Theme.spacingS
                anchors.centerIn: parent

            Rectangle {
                width: 28
                height: 28
                radius: 14
                anchors.verticalCenter: playPauseButton.verticalCenter
                color: prevArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12) : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    size: 14
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!activePlayer) return
                        if (activePlayer.position > 8 && activePlayer.canSeek) {
                            activePlayer.position = 0
                        } else {
                            activePlayer.previous()
                        }
                    }
                }
            }

            Rectangle {
                id: playPauseButton
                width: 32
                height: 32
                radius: 16
                color: Theme.primary

                DankIcon {
                    anchors.centerIn: parent
                    name: activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                    size: 16
                    color: Theme.background
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activePlayer?.togglePlaying()
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                anchors.verticalCenter: playPauseButton.verticalCenter
                color: nextArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12) : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    size: 14
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activePlayer?.next()
                }
            }
            }
        }
    }
}