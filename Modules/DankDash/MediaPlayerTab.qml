import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property MprisPlayer activePlayer: MprisController.activePlayer
    property string lastValidTitle: ""
    property string lastValidArtist: ""
    property string lastValidAlbum: ""
    property string lastValidArtUrl: ""
    property real currentPosition: activePlayer && activePlayer.positionSupported ? activePlayer.position : 0
    property real displayPosition: currentPosition
    property var defaultSink: AudioService.sink

    readonly property real ratio: {
        if (!activePlayer || activePlayer.length <= 0) {
            return 0
        }
        const calculatedRatio = displayPosition / activePlayer.length
        return Math.max(0, Math.min(1, calculatedRatio))
    }

    implicitWidth: 700
    implicitHeight: 410

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.positionSupported) {
            currentPosition = Qt.binding(() => activePlayer?.position || 0)
        } else {
            currentPosition = 0
        }
    }

    Timer {
        id: positionTimer
        interval: 300
        running: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing && !progressSliderArea.isSeeking
        repeat: true
        onTriggered: activePlayer && activePlayer.positionSupported && activePlayer.positionChanged()
    }

    Timer {
        id: cleanupTimer
        interval: 2000
        running: !activePlayer
        onTriggered: {
            lastValidTitle = ""
            lastValidArtist = ""
            lastValidAlbum = ""
            lastValidArtUrl = ""
            currentPosition = 0
            stop()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingM
        visible: (!activePlayer && !lastValidTitle) || (activePlayer && activePlayer.trackTitle === "" && lastValidTitle === "")

        DankIcon {
            name: "music_note"
            size: Theme.iconSize * 3
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: "No Media Playing"
            font.pixelSize: Theme.fontSizeLarge
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: "Start playing media to see detailed controls"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Item {
        anchors.fill: parent
        visible: (activePlayer && activePlayer.trackTitle !== "") || lastValidTitle !== ""

        // Left Column: Album Art and Controls (60%)
        Column {
            x: 0
            y: 0
            width: parent.width * 0.6 - Theme.spacingM
            height: parent.height
            spacing: Theme.spacingL

            // Album Art Section
            Item {
                width: parent.width
                height: parent.height * 0.55
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    width: Math.min(parent.width * 0.8, parent.height * 0.9)
                    height: width
                    anchors.centerIn: parent

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
                        width: parent.width * 1.1
                        height: parent.height * 1.1
                        anchors.centerIn: parent
                        visible: activePlayer?.playbackState === MprisPlaybackState.Playing
                        asynchronous: false
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        z: 0
                        
                        layer.enabled: true
                        layer.smooth: true
                        layer.samples: 4
                        
                        readonly property real centerX: width / 2
                        readonly property real centerY: height / 2
                        readonly property real baseRadius: Math.min(width, height) * 0.35
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
                        width: parent.width * 0.75
                        height: width
                        radius: width / 2
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                        border.color: Theme.surfaceContainer
                        border.width: 1
                        anchors.centerIn: parent
                        z: 1

                        Image {
                            id: albumArt
                            source: (activePlayer && activePlayer.trackArtUrl) || lastValidArtUrl || ""
                            onSourceChanged: {
                                if (activePlayer && activePlayer.trackArtUrl && albumArt.status !== Image.Error) {
                                    lastValidArtUrl = activePlayer.trackArtUrl
                                }
                            }
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            cache: true
                            asynchronous: true
                            visible: false
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    console.warn("Failed to load album art:", source)
                                    source = ""
                                    if (activePlayer && activePlayer.trackArtUrl === source) {
                                        lastValidArtUrl = ""
                                    }
                                }
                            }
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
                            width: parent.width - 4
                            height: parent.height - 4
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
                            size: parent.width * 0.3
                            color: Theme.surfaceVariantText
                            visible: albumArt.status !== Image.Ready
                        }
                    }
                }
            }

            // Song Info and Controls Section
            Column {
                width: parent.width
                height: parent.height * 0.45
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter

                // Song Info
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: (activePlayer && activePlayer.trackTitle) || lastValidTitle || "Unknown Track"
                        onTextChanged: {
                            if (activePlayer && activePlayer.trackTitle) {
                                lastValidTitle = activePlayer.trackTitle
                            }
                        }
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: (activePlayer && activePlayer.trackArtist) || lastValidArtist || "Unknown Artist"
                        onTextChanged: {
                            if (activePlayer && activePlayer.trackArtist) {
                                lastValidArtist = activePlayer.trackArtist
                            }
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: (activePlayer && activePlayer.trackAlbum) || lastValidAlbum || ""
                        onTextChanged: {
                            if (activePlayer && activePlayer.trackAlbum) {
                                lastValidAlbum = activePlayer.trackAlbum
                            }
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                }

                // Progress Bar
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
                    readonly property real midY: height / 2

                    // Background track
                    Rectangle {
                        width: parent.width
                        height: progressSlider.lineWidth
                        anchors.verticalCenter: parent.verticalCenter
                        color: progressSlider.trackColor
                        radius: height / 2
                    }

                    // Filled portion
                    Rectangle {
                        width: Math.max(0, Math.min(parent.width, parent.width * progressSlider.value))
                        height: progressSlider.lineWidth
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: progressSlider.fillColor
                        radius: height / 2
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }

                    // Playhead
                    Rectangle {
                        id: playhead
                        width: 2.5
                        height: Math.max(progressSlider.lineWidth + 8, 12)
                        radius: width / 2
                        color: progressSlider.playheadColor
                        x: Math.max(0, Math.min(progressSlider.width, progressSlider.width * progressSlider.value)) - width / 2
                        y: progressSlider.midY - height / 2
                        z: 3
                        Behavior on x { NumberAnimation { duration: 80 } }
                    }

                    MouseArea {
                        id: progressSliderArea
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
                                if (progressSliderArea.pendingSeekPosition >= 0 && activePlayer?.canSeek && activePlayer?.length > 0) {
                                    const clamped = Math.min(progressSliderArea.pendingSeekPosition, activePlayer.length * 0.99)
                                    activePlayer.position = clamped
                                    progressSliderArea.pendingSeekPosition = -1
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

                // Media Controls
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXL
                    height: 64

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: prevBtnArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 18
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: prevBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!activePlayer) {
                                    return
                                }

                                if (activePlayer.position > 8 && activePlayer.canSeek) {
                                    activePlayer.position = 0
                                } else {
                                    activePlayer.previous()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                            size: 24
                            color: Theme.background
                            weight: 500
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activePlayer && activePlayer.togglePlaying()
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 6
                            shadowBlur: 1.0
                            shadowColor: Qt.rgba(0, 0, 0, 0.3)
                            shadowOpacity: 0.3
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: nextBtnArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 18
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: nextBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activePlayer && activePlayer.next()
                        }
                    }
                }
            }
        }

        // Right Column: Audio Controls (40%)
        Column {
            x: parent.width * 0.6 + Theme.spacingM
            y: 0
            width: parent.width * 0.4 - Theme.spacingM
            height: parent.height
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            // Volume Control
            Row {
                x: -Theme.spacingS
                width: parent.width + Theme.spacingS
                height: 40
                spacing: Theme.spacingXS

                Rectangle {
                    width: Theme.iconSize + Theme.spacingS * 2
                    height: Theme.iconSize + Theme.spacingS * 2
                    anchors.verticalCenter: parent.verticalCenter
                    radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                    color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    
                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }

                    MouseArea {
                        id: iconArea
                        anchors.fill: parent
                        visible: defaultSink !== null
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (defaultSink) {
                                defaultSink.audio.muted = !defaultSink.audio.muted
                            }
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: {
                            if (!defaultSink) return "volume_off"
                            
                            let volume = defaultSink.audio.volume
                            let muted = defaultSink.audio.muted
                            
                            if (muted || volume === 0.0) return "volume_off"
                            if (volume <= 0.33) return "volume_down"
                            if (volume <= 0.66) return "volume_up"
                            return "volume_up"
                        }
                        size: Theme.iconSize
                        color: defaultSink && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
                    }
                }

                DankSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (Theme.iconSize + Theme.spacingS * 2) - Theme.spacingXS
                    enabled: defaultSink !== null
                    minimum: 0
                    maximum: 100
                    value: defaultSink ? Math.round(defaultSink.audio.volume * 100) : 0
                    onSliderValueChanged: function(newValue) {
                        if (defaultSink) {
                            defaultSink.audio.volume = newValue / 100.0
                            if (newValue > 0 && defaultSink.audio.muted) {
                                defaultSink.audio.muted = false
                            }
                        }
                    }
                }
            }

            // Audio Devices
            DankFlickable {
                width: parent.width
                height: parent.height - y
                contentHeight: deviceColumn.height
                clip: true

                Column {
                    id: deviceColumn
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: Pipewire.nodes.values.filter(node => {
                            return node.audio && node.isSink && !node.isStream
                        })

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 42
                            radius: Theme.cornerRadius
                            color: deviceMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                            border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: modelData === AudioService.sink ? 2 : 1

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: {
                                        if (modelData.name.includes("bluez"))
                                            return "headset"
                                        else if (modelData.name.includes("hdmi"))
                                            return "tv"
                                        else if (modelData.name.includes("usb"))
                                            return "headset"
                                        else
                                            return "speaker"
                                    }
                                    size: Theme.iconSize - 4
                                    color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.parent.width - parent.parent.anchors.leftMargin - parent.spacing - Theme.iconSize - Theme.spacingS * 2

                                    StyledText {
                                        text: AudioService.displayName(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        width: parent.width
                                        wrapMode: Text.NoWrap
                                    }

                                    StyledText {
                                        text: modelData === AudioService.sink ? "Active" : "Available"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        wrapMode: Text.NoWrap
                                    }
                                }
                            }

                            MouseArea {
                                id: deviceMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData) {
                                        Pipewire.preferredDefaultAudioSink = modelData
                                    }
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: Theme.shortDuration }
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: Theme.shortDuration }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: progressMouseArea
        anchors.fill: parent
        enabled: false
        visible: false
        property bool isSeeking: false
    }
}