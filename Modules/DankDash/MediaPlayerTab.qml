import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell
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

    property color extractedDominantColor: Theme.surface
    property color extractedAccentColor: Theme.primary
    property bool colorsExtracted: false

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
            currentPosition = activePlayer.position || 0  // Direct assignment, no binding
        } else {
            currentPosition = 0
        }
    }

    Timer {
        id: positionTimer
        interval: 300
        running: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing && !isSeeking
        repeat: true
        onTriggered: {
            if (activePlayer && activePlayer.positionSupported) {
                currentPosition = activePlayer.position || 0
            }
        }
    }

    property bool isSeeking: false

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
            extractedDominantColor = Theme.surface
            extractedAccentColor = Theme.primary
            colorsExtracted = false
            stop()
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: (root.activePlayer && root.activePlayer.trackArtUrl) || root.lastValidArtUrl || ""
        depth: 4
        rescaleSize: 128
        
        onSourceChanged: {
            if (source) {
                root.colorsExtracted = false
                extractionTimer.restart()
            }
        }
        
        onColorsChanged: {
            if (colors.length > 0) {
                root.extractedDominantColor = colors[0]
                root.extractedAccentColor = colors.length > 2 ? colors[2] : (colors.length > 1 ? colors[1] : colors[0])
                root.colorsExtracted = true
                extractionTimer.stop()
            }
        }
    }

    Timer {
        id: extractionTimer
        interval: 5000
        onTriggered: {
            if (!root.colorsExtracted && colorQuantizer.source) {
                root.extractedDominantColor = Theme.primary
                root.extractedAccentColor = Theme.secondary
                root.colorsExtracted = true
            }
        }
    }

    Rectangle {
        id: dynamicBackground
        anchors.fill: parent
        radius: Theme.cornerRadius
        visible: true // Always show background for debugging
        opacity: colorsExtracted ? 1.0 : 0.3
        
        gradient: Gradient {
            GradientStop { 
                position: 0.0
                color: colorsExtracted ? 
                    Qt.rgba(extractedDominantColor.r, extractedDominantColor.g, extractedDominantColor.b, 0.4) :
                    Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            }
            GradientStop { 
                position: 0.3
                color: colorsExtracted ?
                    Qt.rgba(extractedAccentColor.r, extractedAccentColor.g, extractedAccentColor.b, 0.3) :
                    Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
            }
            GradientStop { 
                position: 0.7
                color: colorsExtracted ?
                    Qt.rgba(extractedDominantColor.r, extractedDominantColor.g, extractedDominantColor.b, 0.2) :
                    Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
            }
            GradientStop { 
                position: 1.0
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85)
            }
        }
        
        Behavior on visible {
            NumberAnimation { duration: Theme.mediumDuration }
        }
    }

    Rectangle {
        id: dynamicOverlay
        anchors.fill: parent
        radius: Theme.cornerRadius
        visible: colorsExtracted && ((activePlayer && activePlayer.trackTitle !== "") || lastValidTitle !== "")
        color: "transparent"
        
        Rectangle {
            width: parent.width * 0.8
            height: parent.height * 0.4
            x: parent.width * 0.1
            y: parent.height * 0.1
            radius: Theme.cornerRadius * 2
            opacity: 0.15
            
            gradient: Gradient {
                GradientStop { 
                    position: 0.0
                    color: Qt.rgba(extractedAccentColor.r, extractedAccentColor.g, extractedAccentColor.b, 0.6)
                }
                GradientStop { 
                    position: 1.0
                    color: "transparent"
                }
            }
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                blurMultiplier: 1.0
            }
        }
        
        Behavior on visible {
            NumberAnimation { duration: Theme.mediumDuration }
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
            text: "No Active Players"
            font.pixelSize: Theme.fontSizeLarge
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Item {
        anchors.fill: parent
        clip: false
        visible: (activePlayer && activePlayer.trackTitle !== "") || lastValidTitle !== ""


        // Audio Devices Dropdown (positioned outside towers to avoid clipping)
        Rectangle {
            id: audioDevicesDropdown
            width: 280  // Wider for better visibility
            height: audioDevicesButton.devicesExpanded ? Math.max(120, Math.min(200, audioDevicesDropdown.availableDevices.length * 50 + 80)) : 0
            x: parent.width - width - 80  // Moved further left to avoid overlapping speaker icon
            y: parent.height - height - 60  // Position above bottom controls
            visible: audioDevicesButton.devicesExpanded
            clip: true
            z: 150  // Higher z-index to appear above everything, including the close MouseArea
            
            property var availableDevices: Pipewire.nodes.values.filter(node => {
                return node.audio && node.isSink && !node.isStream
            })
            
            Component.onCompleted: {
                console.log("Available devices count:", availableDevices.length)
                console.log("Devices expanded:", audioDevicesButton.devicesExpanded)
            }
            
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
            border.width: 2
            radius: Theme.cornerRadius * 2
            
            opacity: audioDevicesButton.devicesExpanded ? 1 : 0
            
            // Drop shadow effect
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 8
                shadowBlur: 1.0
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowOpacity: 0.7
            }
            
            Behavior on height {
                NumberAnimation { duration: Theme.mediumDuration }
            }
            
            Behavior on opacity {
                NumberAnimation { duration: Theme.mediumDuration }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                
                StyledText {
                    text: "Audio Output Devices (" + audioDevicesDropdown.availableDevices.length + ")"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bottomPadding: Theme.spacingM
                }
                
                DankFlickable {
                    width: parent.width
                    height: parent.height - 40  // Account for header
                    contentHeight: deviceColumn.height
                    clip: true
                    
                    Column {
                        id: deviceColumn
                        width: parent.width
                        spacing: Theme.spacingS
                        
                        Repeater {
                            model: audioDevicesDropdown.availableDevices
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                
                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: deviceMouseAreaLeft.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                                border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: modelData === AudioService.sink ? 2 : 1
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2
                                    
                                    DankIcon {
                                        name: {
                                            if (modelData.name.includes("bluez") || modelData.name.includes("bluetooth"))
                                                return "headset"
                                            else if (modelData.name.includes("hdmi"))
                                                return "tv"
                                            else if (modelData.name.includes("usb"))
                                                return "headset"
                                            else
                                                return "speaker"
                                        }
                                        size: 20
                                        color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 20 - Theme.spacingM * 2
                                        
                                        StyledText {
                                            text: AudioService.displayName(modelData)
                                            font.pixelSize: Theme.fontSizeMedium
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
                                    id: deviceMouseAreaLeft
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("MediaPlayer: Selecting audio device:", AudioService.displayName(modelData))
                                        console.log("MediaPlayer: Device node:", modelData)
                                        console.log("MediaPlayer: Setting Pipewire.preferredDefaultAudioSink")
                                        if (modelData) {
                                            Pipewire.preferredDefaultAudioSink = modelData  // Set the preferred audio sink
                                            console.log("MediaPlayer: Device selection completed")
                                        } else {
                                            console.log("MediaPlayer: ERROR - modelData is null")
                                        }
                                        audioDevicesButton.devicesExpanded = false  // Auto-close after selection
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

        // Center Column: Main Media Content
        Column {
            x: 72  // 48 + 24 spacing
            y: Math.max(12, (parent.height - height) / 2)  // Center vertically within available space
            width: 556  // 700 - 72 (left) - 72 (right) = 556
            height: Math.min(384, parent.height - 24)  // Dynamic height with padding
            spacing: Theme.spacingXS  // More compact spacing

            // Album Art Section
            Item {
                width: parent.width
                height: Math.min(parent.height * 0.55, 220)  // Dynamic but capped height
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    width: Math.min(parent.width * 0.8, parent.height * 0.9)
                    height: width
                    anchors.centerIn: parent

                    Loader {
                        active: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
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
                        visible: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
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
                height: parent.height * 0.42
                spacing: Theme.spacingS  // Better spacing between song info and controls
                anchors.horizontalCenter: parent.horizontalCenter

                // Song Info
                Column {
                    width: parent.width
                    spacing: Theme.spacingXS  // Compact spacing within song info
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

                // Seekbar Section (moved up, reduced width, thicker)
                Item {
                    width: parent.width * 0.7  // Reduced from parent.width - Theme.spacingM * 2
                    height: 24  // Slightly reduced for more compact layout
                    anchors.horizontalCenter: parent.horizontalCenter

                    Loader {
                        anchors.fill: parent
                        visible: activePlayer && activePlayer.length > 0
                        sourceComponent: SettingsData.waveProgressEnabled ? seekBarWaveComponent : seekBarFlatComponent

                        Component {
                            id: seekBarWaveComponent

                            M3WaveProgress {
                                value: ratio
                                isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: activePlayer ? (activePlayer.canSeek && activePlayer.length > 0) : false

                                    property real pendingSeekPosition: -1

                                    Timer {
                                        id: mainSeekDebounceTimer
                                        interval: 150
                                        onTriggered: {
                                            if (parent.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer && activePlayer.length > 0) {
                                                const clamped = Math.min(parent.pendingSeekPosition, activePlayer.length * 0.99)
                                                activePlayer.position = clamped
                                                parent.pendingSeekPosition = -1
                                            }
                                        }
                                    }

                                    onPressed: (mouse) => {
                                        root.isSeeking = true
                                        if (activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            pendingSeekPosition = r * activePlayer.length
                                            displayPosition = pendingSeekPosition
                                            mainSeekDebounceTimer.restart()
                                        }
                                    }
                                    onReleased: {
                                        root.isSeeking = false
                                        mainSeekDebounceTimer.stop()
                                        if (pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer && activePlayer.length > 0) {
                                            const clamped = Math.min(pendingSeekPosition, activePlayer.length * 0.99)
                                            activePlayer.position = clamped
                                            pendingSeekPosition = -1
                                        }
                                        displayPosition = Qt.binding(() => currentPosition)
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed && root.isSeeking && activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            pendingSeekPosition = r * activePlayer.length
                                            displayPosition = pendingSeekPosition
                                            mainSeekDebounceTimer.restart()
                                        }
                                    }
                                    onClicked: (mouse) => {
                                        if (activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            activePlayer.position = r * activePlayer.length
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: seekBarFlatComponent

                            Item {
                                property real value: ratio
                                property real lineWidth: 3
                                property color trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                                property color fillColor: Theme.primary
                                property color playheadColor: Theme.primary
                                readonly property real midY: height / 2

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
                                    y: parent.midY - height / 2
                                    z: 3
                                    Behavior on x { NumberAnimation { duration: 80 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: activePlayer ? (activePlayer.canSeek && activePlayer.length > 0) : false

                                    property real pendingSeekPosition: -1

                                    Timer {
                                        id: mainFlatSeekDebounceTimer
                                        interval: 150
                                        onTriggered: {
                                            if (parent.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer && activePlayer.length > 0) {
                                                const clamped = Math.min(parent.pendingSeekPosition, activePlayer.length * 0.99)
                                                activePlayer.position = clamped
                                                parent.pendingSeekPosition = -1
                                            }
                                        }
                                    }

                                    onPressed: (mouse) => {
                                        root.isSeeking = true
                                        if (activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            pendingSeekPosition = r * activePlayer.length
                                            displayPosition = pendingSeekPosition
                                            mainFlatSeekDebounceTimer.restart()
                                        }
                                    }
                                    onReleased: {
                                        root.isSeeking = false
                                        mainFlatSeekDebounceTimer.stop()
                                        if (pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer && activePlayer.length > 0) {
                                            const clamped = Math.min(pendingSeekPosition, activePlayer.length * 0.99)
                                            activePlayer.position = clamped
                                            pendingSeekPosition = -1
                                        }
                                        displayPosition = Qt.binding(() => currentPosition)
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed && root.isSeeking && activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            pendingSeekPosition = r * activePlayer.length
                                            displayPosition = pendingSeekPosition
                                            mainFlatSeekDebounceTimer.restart()
                                        }
                                    }
                                    onClicked: (mouse) => {
                                        if (activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                            activePlayer.position = r * activePlayer.length
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Timestamps Row - aligned with seekbar edges
                Item {
                    width: parent.width * 0.75
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 24
                    
                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!activePlayer) return "0:00"
                            const pos = Math.max(0, displayPosition / 1000000 || 0)  // Convert from microseconds to seconds and use displayPosition
                            const minutes = Math.floor(pos / 60)
                            const seconds = Math.floor(pos % 60)
                            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    
                    StyledText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!activePlayer) return "0:00"
                            const dur = Math.max(0, activePlayer.length / 1000000 || 0)  // Convert from microseconds to seconds
                            const minutes = Math.floor(dur / 60)
                            const seconds = Math.floor(dur % 60)
                            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                // Media Controls (moved below seekbar, enlarged)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM
                    height: 60

                    // Shuffle Button
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: shuffleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: "shuffle"
                            size: 20
                            color: activePlayer && activePlayer.shuffleStatus ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: shuffleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer && activePlayer.canControl) {
                                    activePlayer.shuffleStatus = !activePlayer.shuffleStatus
                                }
                            }
                        }
                        
                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: prevBtnArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 24
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
                        width: 50
                        height: 50
                        radius: 25
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                            size: 28
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
                        width: 40
                        height: 40
                        radius: 20
                        color: nextBtnArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 24
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

                    // Repeat Button
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: repeatArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: {
                                if (!activePlayer) return "repeat"
                                switch(activePlayer.loopStatus) {
                                    case "Track": return "repeat_one"
                                    case "Playlist": return "repeat"
                                    default: return "repeat"
                                }
                            }
                            size: 20
                            color: activePlayer && activePlayer.loopStatus !== "None" ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: repeatArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer && activePlayer.canControl) {
                                    switch(activePlayer.loopStatus) {
                                        case "None":
                                            activePlayer.loopStatus = "Playlist"
                                            break
                                        case "Playlist":
                                            activePlayer.loopStatus = "Track"
                                            break
                                        case "Track":
                                            activePlayer.loopStatus = "None"
                                            break
                                    }
                                }
                            }
                        }
                        
                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                    }
                }

            }
        }

        // Right Tower: Volume Control
        Rectangle {
            id: rightTower
            x: parent.width - 48 - Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: parent.height - Theme.spacingM * 12
            radius: Theme.cornerRadius * 2
            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            border.width: 1
            clip: true

            Item {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                
                // Volume icon at top
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: topIconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    
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
                        size: Theme.iconSize * 0.8
                        color: defaultSink && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: topIconArea
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
                    
                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                }

                // Custom vertical volume slider (DankSlider variant)
                Item {
                    width: parent.width * 0.8  // Wider track
                    height: parent.height - 100  // Use more space - only reserve 50px at top and bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 50  // Reduced margin for more slider length
                    
                    property bool dragging: false
                    property bool containsMouse: sliderMouseArea.containsMouse
                    
                    // Background track
                    Rectangle {
                        width: parent.width
                        height: parent.height
                        anchors.centerIn: parent
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                        radius: width / 2
                    }
                    
                    // Filled portion
                    Rectangle {
                        width: parent.width
                        height: defaultSink ? (defaultSink.audio.volume * parent.height) : 0
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.primary
                        radius: width / 2
                        
                        Behavior on height {
                            enabled: !parent.dragging
                            NumberAnimation { duration: 150 }
                        }
                    }
                    
                    // Tooltip positioned above the current level
                    Rectangle {
                        width: 48
                        height: 24
                        radius: 12
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        border.width: 1
                        visible: parent.containsMouse || parent.dragging
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - (defaultSink ? (defaultSink.audio.volume * parent.height) : 0) - height - Theme.spacingXS
                        z: 10
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: defaultSink ? Math.round(defaultSink.audio.volume * 100) + "%" : "0%"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                        
                        Behavior on y {
                            NumberAnimation { duration: 100 }
                        }
                    }
                    
                    MouseArea {
                        id: sliderMouseArea
                        anchors.fill: parent
                        anchors.margins: -12
                        enabled: defaultSink !== null
                        hoverEnabled: true
                        preventStealing: true
                        
                        onPressed: function(mouse) {
                            parent.dragging = true
                            updateVolume(mouse)
                        }
                        
                        onReleased: {
                            parent.dragging = false
                        }
                        
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                updateVolume(mouse)
                            }
                        }
                        
                        onClicked: function(mouse) {
                            updateVolume(mouse)
                        }
                        
                        function updateVolume(mouse) {
                            if (defaultSink) {
                                const ratio = 1.0 - (mouse.y / height)
                                const volume = Math.max(0, Math.min(1, ratio))
                                defaultSink.audio.volume = volume
                                if (volume > 0 && defaultSink.audio.muted) {
                                    defaultSink.audio.muted = false
                                }
                            }
                        }
                    }
                }

                // Audio Devices button
                Rectangle {
                    id: audioDevicesButton
                    width: 32
                    height: 32
                    radius: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingM  // More padding at bottom for better positioning
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: audioDevicesArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    
                    property bool devicesExpanded: false
                    
                    DankIcon {
                        anchors.centerIn: parent
                        name: parent.devicesExpanded ? "expand_less" : "speaker"
                        size: Theme.iconSize * 0.8
                        color: Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: audioDevicesArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            parent.devicesExpanded = !parent.devicesExpanded
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                }


            }
        }
    }

    // Click outside to close audio devices dropdown
    MouseArea {
        anchors.fill: parent
        enabled: audioDevicesButton.devicesExpanded
        onClicked: function(mouse) {
            // Only close if click is outside the dropdown area
            const dropdownX = audioDevicesDropdown.x
            const dropdownY = audioDevicesDropdown.y
            const dropdownWidth = audioDevicesDropdown.width
            const dropdownHeight = audioDevicesDropdown.height
            
            if (mouse.x < dropdownX || mouse.x > dropdownX + dropdownWidth ||
                mouse.y < dropdownY || mouse.y > dropdownY + dropdownHeight) {
                audioDevicesButton.devicesExpanded = false
            }
        }
        z: 50
    }

    MouseArea {
        id: progressMouseArea
        anchors.fill: parent
        enabled: false
        visible: false
        property bool isSeeking: false
    }
}