import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property MprisPlayer activePlayer: MprisController.activePlayer
    property var allPlayers: MprisController.availablePlayers

    onAllPlayersChanged: {
        console.log("allPlayers changed:", allPlayers?.length || 0)
        if (allPlayers) {
            for (let i = 0; i < allPlayers.length; i++) {
                console.log(`  Player ${i}:`, allPlayers[i]?.identity || "no identity")
            }
        }
    }

    property string lastValidTitle: ""
    property string lastValidArtist: ""
    property string lastValidAlbum: ""
    property string lastValidArtUrl: ""

    property var defaultSink: AudioService.sink

    property color extractedDominantColor: Theme.surface
    property color extractedAccentColor: Theme.primary
    property bool colorsExtracted: false

    readonly property real ratio: {
        if (!activePlayer || activePlayer.length <= 0) {
            return 0
        }
        const calculatedRatio = (activePlayer.position || 0) / activePlayer.length
        return Math.max(0, Math.min(1, calculatedRatio))
    }

    implicitWidth: 700
    implicitHeight: 410


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
            extractedDominantColor = Theme.surface
            extractedAccentColor = Theme.primary
            colorsExtracted = false
            stop()
        }
    }


    ColorQuantizer {
        id: colorQuantizer
        source: {
            const artUrl = (root.activePlayer && root.activePlayer.trackArtUrl) || root.lastValidArtUrl || ""
            if (!artUrl) return ""

            const urlString = String(artUrl)
            if (!urlString || typeof urlString !== 'string') return ""

            if (urlString.includes("scdn.co")) {
                return urlString.replace(/640x640|300x300|64x64/, "640x640").replace("http://", "https://")
            } else if (urlString.startsWith("file://")) {
                return urlString
            } else if (urlString.includes("googleusercontent.com") || urlString.includes("ytimg.com") || urlString.includes("youtube.com")) {
                if (urlString.includes("=")) {
                    return urlString.replace(/=w\d+-h\d+/, "=w640-h640").replace(/=s\d+/, "=s640")
                } else {e
                    return urlString + "=w640-h640"
                }
            } else if (urlString.includes("ggpht.com")) {
                return urlString.includes("=") ? urlString.replace(/=s\d+/, "=s640") : urlString + "=s640"
            } else if (urlString.includes("discordapp.com") || urlString.includes("discord.com")) {
                return urlString
            } else if (urlString.includes("soundcloud.com")) {
                return urlString.replace("large.jpg", "t500x500.jpg")
            } else if (urlString.includes("bandcamp.com")) {
                return urlString.replace("_10.jpg", "_2.jpg").replace("_16.jpg", "_2.jpg")
            } else if (urlString.includes("last.fm") || urlString.includes("lastfm.")) {
                return urlString.replace("/174s/", "/300x300/").replace("/64s/", "/300x300/")
            } else if (urlString.includes("tidal.com")) {
                return urlString.replace(/\/\d+x\d+\//, "/640x640/")
            }

            return urlString
        }
        depth: 4
        rescaleSize: 128
        
        onSourceChanged: {
            if (source) {
                root.colorsExtracted = false
                colorFallbackTimer.restart()
                const playerName = root.activePlayer ? root.activePlayer.identity : "Unknown"
                const sourceString = String(source)
                let sourceDomain = "local"
                if (sourceString.startsWith("file://")) {
                    if (sourceString.includes(".com.google.Chrome")) {
                        sourceDomain = "chrome-temp"
                    } else if (sourceString.includes("/tmp/")) {
                        sourceDomain = "temp-file"
                    } else {
                        sourceDomain = "local-file"
                    }
                } else if (sourceString.includes("//")) {
                    const parts = sourceString.split("/")
                    sourceDomain = parts.length > 2 ? parts[2] : "unknown-url"
                }
                console.log(`ColorQuantizer loading art for ${playerName} from ${sourceDomain}:`, source)
            }
        }

        onColorsChanged: {
            if (colors.length > 0) {
                colorFallbackTimer.stop()
                root.extractedDominantColor = colors[0]
                root.extractedAccentColor = colors.length > 2 ? colors[2] : (colors.length > 1 ? colors[1] : colors[0])
                root.colorsExtracted = true
            }
        }

    }

    Timer {
        id: colorFallbackTimer
        interval: {
            const source = String(colorQuantizer.source)
            if (source.includes(".com.google.Chrome") && source.includes("/tmp/")) {
                return 500 
            } else if (source.includes("scdn.co") || source.includes("spotify.com")) {
                return 2500 
            }
            return 3000 
        }
        onTriggered: {
            if (!root.colorsExtracted) {
                const playerName = root.activePlayer ? root.activePlayer.identity : "Unknown"
                const source = String(colorQuantizer.source)

                if (source.includes("scdn.co") || source.includes("spotify.com")) {
                    console.info(`Spotify CORS block expected for ${playerName} - using theme colors`)
                } else if (source.includes(".com.google.Chrome") && source.includes("/tmp/")) {
                    console.info(`Chrome temporary file inaccessible for ${playerName} - using theme colors`)
                } else {
                    console.warn(`ColorQuantizer timeout for ${playerName} image:`, source)
                    console.warn("Using fallback colors - network or CORS issue likely")
                }

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
        visible: true 
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

        Rectangle {
            id: audioDevicesDropdown
            width: 280 
            height: audioDevicesButton.devicesExpanded ? Math.max(Math.min(140, audioDevicesDropdown.availableDevices.length * 40 + 60), Math.min(180, audioDevicesDropdown.availableDevices.length * 40 + 60)) : 0
            x: parent.width + Theme.spacingS 
            y: 180  
            visible: audioDevicesButton.devicesExpanded
            clip: true
            z: 150  
            
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
                    height: parent.height - 40 
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
                                        console.log("Audio device clicked:", modelData ? AudioService.displayName(modelData) : "null")
                                        if (modelData) {
                                            console.log("Setting preferredDefaultAudioSink to:", modelData.name)
                                            Pipewire.preferredDefaultAudioSink = modelData
                                            console.log("Current default sink after change:", AudioService.sink ? AudioService.sink.name : "null")
                                        }
                                        audioDevicesButton.devicesExpanded = false
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

        Rectangle {
            id: playerSelectorDropdown
            width: 240
            height: playerSelectorButton.playersExpanded ? Math.max(Math.min(140, (allPlayers?.length || 0) * 40 + 60), Math.min(160, (allPlayers?.length || 0) * 40 + 60)) : 0
            x: parent.width + Theme.spacingS
            y: 130
            visible: playerSelectorButton.playersExpanded
            clip: true
            z: 150

            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
            border.width: 2
            radius: Theme.cornerRadius * 2

            opacity: playerSelectorButton.playersExpanded ? 1 : 0

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
                    text: "Media Players (" + (allPlayers?.length || 0) + ")"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bottomPadding: Theme.spacingM
                }

                DankFlickable {
                    width: parent.width
                    height: parent.height - 40
                    contentHeight: playerColumn.height
                    clip: true

                    Column {
                        id: playerColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: allPlayers || []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: playerMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                                border.color: modelData === activePlayer ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: modelData === activePlayer ? 2 : 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2

                                    DankIcon {
                                        name: "music_note"
                                        size: 20
                                        color: modelData === activePlayer ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 20 - Theme.spacingM * 2

                                        StyledText {
                                            text: modelData && modelData.identity ? modelData.identity : "Unknown Player"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            font.weight: modelData === activePlayer ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }

                                        StyledText {
                                            text: modelData === activePlayer ? "Active" : "Available"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }
                                    }
                                }

                                MouseArea {
                                    id: playerMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.identity) {
                                            console.log("Switching to player:", modelData.identity)

                                            // Pause the currently active player before switching
                                            if (activePlayer && activePlayer !== modelData && activePlayer.canPause) {
                                                console.log("Pausing current player:", activePlayer.identity)
                                                activePlayer.pause()
                                            }

                                            MprisController.activePlayer = modelData
                                        }
                                        playerSelectorButton.playersExpanded = false
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
        ColumnLayout {
            x: 72  // 48 + 24 spacing
            y: 20  // Adjusted top position for better centering
            width: 484  // 700 - 72 (left) - 144 (right for floating buttons) = 484
            height: 370  // Fixed height to fit within container (410 - 40 margin)
            spacing: Theme.spacingXS  // More compact spacing

            Item {
                width: parent.width
                height: 200

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
            Item {
                width: parent.width
                Layout.fillHeight: true

                // Song Info
                Column {
                    id: songInfo
                    width: parent.width
                    spacing: Theme.spacingXS
                    anchors.top: parent.top
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
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
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
                        wrapMode: Text.WordWrap
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
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                }

                // Controls Group
                Column {
                    id: controlsGroup
                    width: parent.width
                    spacing: Theme.spacingXS
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0

                    Item {
                        width: parent.width
                        height: 20

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
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed && root.isSeeking && activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                                const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                                pendingSeekPosition = r * activePlayer.length
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
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed && root.isSeeking && activePlayer && activePlayer.length > 0 && activePlayer && activePlayer.canSeek) {
                                                const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                                                pendingSeekPosition = r * activePlayer.length
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

                    Item {
                        width: parent.width
                        height: 20

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!activePlayer) return "0:00"
                                const pos = Math.max(0, activePlayer.position || 0)
                                const minutes = Math.floor(pos / 60)
                                const seconds = Math.floor(pos % 60)
                                const timeStr = minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                                return timeStr
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        
                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!activePlayer || !activePlayer.length) return "0:00"
                                const dur = Math.max(0, activePlayer.length || 0)  // Length is already in seconds
                                const minutes = Math.floor(dur / 60)
                                const seconds = Math.floor(dur % 60)
                                return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        width: parent.width
                        height: 50
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM
                            height: parent.height

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: shuffleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: activePlayer && activePlayer.shuffleSupported

                            DankIcon {
                                anchors.centerIn: parent
                                name: "shuffle"
                                size: 20
                                color: activePlayer && activePlayer.shuffle ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: shuffleArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (activePlayer && activePlayer.canControl && activePlayer.shuffleSupported) {
                                        activePlayer.shuffle = !activePlayer.shuffle
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

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: repeatArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: activePlayer && activePlayer.loopSupported

                            DankIcon {
                                anchors.centerIn: parent
                                name: {
                                    if (!activePlayer) return "repeat"
                                    switch(activePlayer.loopState) {
                                        case MprisLoopState.Track: return "repeat_one"
                                        case MprisLoopState.Playlist: return "repeat"
                                        default: return "repeat"
                                    }
                                }
                                size: 20
                                color: activePlayer && activePlayer.loopState !== MprisLoopState.None ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: repeatArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (activePlayer && activePlayer.canControl && activePlayer.loopSupported) {
                                        switch(activePlayer.loopState) {
                                            case MprisLoopState.None:
                                                activePlayer.loopState = MprisLoopState.Playlist
                                                break
                                            case MprisLoopState.Playlist:
                                                activePlayer.loopState = MprisLoopState.Track
                                                break
                                            case MprisLoopState.Track:
                                                activePlayer.loopState = MprisLoopState.None
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
            }            
        }                  

        Rectangle {
            id: playerSelectorButton
            width: 40
            height: 40
            radius: 20
            x: parent.width - 40 - Theme.spacingM
            y: 180  // Top button position
            color: playerSelectorArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.8)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            z: 100
            visible: (allPlayers?.length || 0) >= 1

            property bool playersExpanded: false

            DankIcon {
                anchors.centerIn: parent
                name: "assistant_device"
                size: 18
                color: Theme.surfaceText
            }

            MouseArea {
                id: playerSelectorArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    console.log("Player selector clicked, players:", allPlayers?.length || 0)
                    parent.playersExpanded = !parent.playersExpanded
                    console.log("Players expanded:", parent.playersExpanded)
                }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.shortDuration }
            }
        }

        Rectangle {
            id: volumeButton
            width: 40
            height: 40
            radius: 20
            x: parent.width - 40 - Theme.spacingM
            y: 235  
            color: volumeButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.8)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            z: 100

            property bool volumeExpanded: false

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
                size: 18
                color: defaultSink && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
            }

            MouseArea {
                id: volumeButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    volumeButton.volumeExpanded = !volumeButton.volumeExpanded
                }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.shortDuration }
            }
        }

        Rectangle {
            id: volumeSliderPanel
            width: 60
            height: volumeButton.volumeExpanded ? 180 : 0
            radius: Theme.cornerRadius * 2
            x: volumeButton.x - 10
            y: volumeButton.y - height - Theme.spacingS
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            visible: volumeButton.volumeExpanded
            clip: true
            z: 110

            opacity: volumeButton.volumeExpanded ? 1 : 0

            Behavior on height {
                NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.mediumDuration }
            }

            Item {
                anchors.fill: parent
                anchors.margins: Theme.spacingS

                Item {
                    width: parent.width * 0.6
                    height: parent.height - Theme.spacingXL * 2  
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    property bool dragging: false
                    property bool containsMouse: volumeSliderArea.containsMouse
                    
                    Rectangle {
                        width: parent.width
                        height: parent.height
                        anchors.centerIn: parent
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                        radius: width / 2
                    }
                    
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
                    
                    MouseArea {
                        id: volumeSliderArea
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
                        
                        onWheel: function(wheel) {
                            if (defaultSink) {
                                const delta = wheel.angleDelta.y / 120  // Standard wheel step
                                const increment = delta * 0.05  // 5% per scroll step
                                const newVolume = Math.max(0, Math.min(1, defaultSink.audio.volume + increment))
                                defaultSink.audio.volume = newVolume
                                if (newVolume > 0 && defaultSink.audio.muted) {
                                    defaultSink.audio.muted = false
                                }
                            }
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

                StyledText {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Theme.spacingL
                    text: defaultSink ? Math.round(defaultSink.audio.volume * 100) + "%" : "0%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }
            }
        }

        Rectangle {
            id: audioDevicesButton
            width: 40
            height: 40
            radius: 20
            x: parent.width - 40 - Theme.spacingM
            y: 290  
            color: audioDevicesArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.8)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            z: 100

            property bool devicesExpanded: false

            DankIcon {
                anchors.centerIn: parent
                name: parent.devicesExpanded ? "expand_less" : "speaker"
                size: 18
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

        MouseArea {
            anchors.fill: parent
            enabled: audioDevicesButton.devicesExpanded || volumeButton.volumeExpanded || playerSelectorButton.playersExpanded
            z: 50
            onClicked: function(mouse) {

                if (playerSelectorButton.playersExpanded) {
                    const playerDropdownX = playerSelectorDropdown.x
                    const playerDropdownY = playerSelectorDropdown.y
                    const playerDropdownWidth = playerSelectorDropdown.width
                    const playerDropdownHeight = playerSelectorDropdown.height

                    if (mouse.x < playerDropdownX || mouse.x > playerDropdownX + playerDropdownWidth ||
                        mouse.y < playerDropdownY || mouse.y > playerDropdownY + playerDropdownHeight) {
                        playerSelectorButton.playersExpanded = false
                    }
                }

                if (audioDevicesButton.devicesExpanded) {
                    const dropdownX = audioDevicesDropdown.x
                    const dropdownY = audioDevicesDropdown.y
                    const dropdownWidth = audioDevicesDropdown.width
                    const dropdownHeight = audioDevicesDropdown.height

                    if (mouse.x < dropdownX || mouse.x > dropdownX + dropdownWidth ||
                        mouse.y < dropdownY || mouse.y > dropdownY + dropdownHeight) {
                        audioDevicesButton.devicesExpanded = false
                    }
                }

                if (volumeButton.volumeExpanded) {
                    const volumeX = volumeSliderPanel.x
                    const volumeY = volumeSliderPanel.y
                    const volumeWidth = volumeSliderPanel.width
                    const volumeHeight = volumeSliderPanel.height

                    const buttonX = volumeButton.x
                    const buttonY = volumeButton.y
                    const buttonWidth = volumeButton.width
                    const buttonHeight = volumeButton.height

                    const clickInPanel = mouse.x >= volumeX && mouse.x <= volumeX + volumeWidth &&
                                        mouse.y >= volumeY && mouse.y <= volumeY + volumeHeight
                    const clickInButton = mouse.x >= buttonX && mouse.x <= buttonX + buttonWidth &&
                                         mouse.y >= buttonY && mouse.y <= buttonY + buttonHeight

                    if (!clickInPanel && !clickInButton) {
                        volumeButton.volumeExpanded = false
                    }
                }
            }
        }
    }
}