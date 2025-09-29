pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool connected: false
    property bool connecting: false
    property bool haAvailable: false

    readonly property string haUrl: SettingsData.homeAssistantUrl || ""
    readonly property string haToken: SettingsData.homeAssistantToken || ""
    readonly property bool configValid: haUrl !== "" && haToken !== ""

    property var entities: ({})
    property var mediaPlayers: ({})

    readonly property var activeMediaPlayer: getActiveMediaPlayer()
    readonly property bool hasActiveMedia: activeMediaPlayer && activeMediaPlayer.state && ["playing", "paused"].includes(activeMediaPlayer.state)

    readonly property var appletvEntity: entities["media_player.anttv"] || null
    readonly property bool appletvAvailable: appletvEntity !== null
    readonly property string appletvState: appletvEntity?.state || "unknown"
    readonly property string appletvTitle: appletvEntity?.attributes?.media_title || ""
    readonly property string appletvArtist: appletvEntity?.attributes?.media_artist || ""
    readonly property string appletvApp: appletvEntity?.attributes?.app_name || "Apple TV"
    readonly property real appletvPosition: appletvEntity?.attributes?.media_position || 0
    readonly property real appletvDuration: appletvEntity?.attributes?.media_duration || 0
    readonly property real appletvVolume: appletvEntity?.attributes?.volume_level || 0
    readonly property bool appletvMuted: appletvEntity?.attributes?.is_volume_muted || false

    signal entityUpdated(string entityId, var entity)
    signal connectionStatusChanged(bool connected)
    signal commandResult(string command, bool success, string message)

    Timer {
        id: reconnectTimer
        interval: 30000
        running: configValid && SettingsData.homeAssistantEnabled && !connected && !connecting
        repeat: true
        onTriggered: {
            if (SettingsData.homeAssistantEnabled) {
                root.testConnection()
            }
        }
    }

    Timer {
        id: initDelay
        interval: 2000
        repeat: false
        running: false
        onTriggered: {
            if (configValid && SettingsData.homeAssistantEnabled) {
                testConnection()
            } else {
                resetConnectionState(true)
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 5000
        running: connected
        repeat: true
        onTriggered: root.refreshEntities()
    }

    Timer {
        id: credentialChangeDebounce
        interval: 750
        repeat: false
        onTriggered: {
            if (!SettingsData.homeAssistantEnabled || !configValid) {
                resetConnectionState(true)
                return
            }
            testConnection()
        }
    }

    Connections {
        target: SettingsData

        function handleConfigurationChange() {
            if (!SettingsData.homeAssistantEnabled || !configValid) {
                credentialChangeDebounce.stop()
                resetConnectionState(true)
                return
            }

            credentialChangeDebounce.restart()
        }

        function onHomeAssistantUrlChanged() {
            handleConfigurationChange()
        }

        function onHomeAssistantTokenChanged() {
            handleConfigurationChange()
        }

        function onHomeAssistantEnabledChanged() {
            handleConfigurationChange()
        }
    }

    Process {
        id: testProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response && response.message === "API running.") {
                        connected = true
                        haAvailable = true
                        connectionStatusChanged(true)
                        refreshEntities()
                        console.log("HomeAssistant: Connected successfully")
                        return
                    }
                } catch (e) {
                    console.warn("HomeAssistant: Invalid API response:", text)
                }

                connected = false
                haAvailable = false
                connectionStatusChanged(false)
                console.warn("HomeAssistant: Connection failed - invalid response")
            }
        }

        onExited: exitCode => {
            connecting = false
            console.log("HomeAssistant: Test process exited with code:", exitCode)
            if (exitCode !== 0) {
                connected = false
                haAvailable = false
                connectionStatusChanged(false)
                console.warn("HomeAssistant: Connection failed - curl error")
            }
        }
    }

    Process {
        id: statesProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const states = JSON.parse(text)
                    if (Array.isArray(states)) {
                        const newEntities = {}
                        const newMediaPlayers = {}

                        states.forEach(entity => {
                            newEntities[entity.entity_id] = entity
                            if (entity.entity_id.startsWith("media_player.")) {
                                newMediaPlayers[entity.entity_id] = entity
                            }
                        })

                        entities = newEntities
                        mediaPlayers = newMediaPlayers
                        console.log(`HomeAssistant: Refreshed ${states.length} entities`)
                    }
                } catch (e) {
                    console.warn("HomeAssistant: Failed to parse states response:", text)
                }
            }
        }

        onExited: exitCode => {
            console.log("HomeAssistant: States process exited with code:", exitCode)
            if (exitCode !== 0) {
                console.warn("HomeAssistant: Failed to refresh entities - curl error")
            }
        }
    }

    Process {
        id: serviceProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const success = serviceProcess.exitCode === 0
                commandResult(serviceProcess._currentCommand, success, success ? "Success" : text)

                if (success) {
                    Qt.callLater(() => refreshEntities())
                }
            }
        }

        onExited: exitCode => {
            console.log("HomeAssistant: Service process exited with code:", exitCode)
            if (exitCode !== 0) {
                console.warn("HomeAssistant: Service call failed - curl error")
            }
        }

        property string _currentCommand: ""
    }

    function resetConnectionState(clearEntities) {
        if (testProcess.running) {
            testProcess.running = false
        }
        if (statesProcess.running) {
            statesProcess.running = false
        }
        if (serviceProcess.running) {
            serviceProcess.running = false
        }

        const wasConnected = connected
        const wasConnecting = connecting

        connecting = false
        connected = false
        haAvailable = false

        if (clearEntities) {
            entities = ({})
            mediaPlayers = ({})
        }

        if (wasConnected || wasConnecting) {
            connectionStatusChanged(false)
        }
    }

    Component.onCompleted: {
        // Delay connection test to avoid crashes during shell initialization
        initDelay.start()
    }

    function testConnection() {
        if (!configValid || connecting) {
            console.log("HomeAssistant: Skipping connection test - configValid:", configValid, "connecting:", connecting)
            return
        }

        console.log("HomeAssistant: Testing connection to", haUrl, "with token length:", haToken.length)
        connecting = true
        const command = ["curl", "-s", "--connect-timeout", "5", "--max-time", "10",
                        "-H", `Authorization: Bearer ${haToken}`,
                        `${haUrl}/api/`]
        console.log("HomeAssistant: Running command:", command.join(" "))
        testProcess.command = command
        testProcess.running = true
    }

    function refreshEntities() {
        if (!connected) return

        statesProcess.command = ["curl", "-s", "--connect-timeout", "5", "--max-time", "10",
                                "-H", `Authorization: Bearer ${haToken}`,
                                `${haUrl}/api/states`]
        statesProcess.running = true
    }

    function getActiveMediaPlayer() {
        for (const [entityId, entity] of Object.entries(mediaPlayers)) {
            if (entity.state === "playing") {
                return entity
            }
        }

        for (const [entityId, entity] of Object.entries(mediaPlayers)) {
            if (entity.state === "paused") {
                return entity
            }
        }

        return appletvEntity || null
    }

    function callService(domain, service, entityId, serviceData = {}) {
        if (!connected) {
            commandResult("call_service", false, "Not connected to HomeAssistant")
            return
        }

        if (serviceProcess.running) {
            console.warn("HomeAssistant: Service call already in progress")
            return
        }

        const data = {
            entity_id: entityId
        }

        for (const key in serviceData) {
            data[key] = serviceData[key]
        }

        serviceProcess._currentCommand = `${domain}.${service}`
        serviceProcess.command = ["curl", "-s", "--connect-timeout", "5", "--max-time", "10",
                                 "-X", "POST",
                                 "-H", `Authorization: Bearer ${haToken}`,
                                 "-H", "Content-Type: application/json",
                                 "-d", JSON.stringify(data),
                                 `${haUrl}/api/services/${domain}/${service}`]
        serviceProcess.running = true
    }

    function mediaPlay(entityId = "media_player.anttv") {
        callService("media_player", "media_play", entityId)
    }

    function mediaPause(entityId = "media_player.anttv") {
        callService("media_player", "media_pause", entityId)
    }

    function mediaPlayPause(entityId = "media_player.anttv") {
        callService("media_player", "media_play_pause", entityId)
    }

    function mediaNext(entityId = "media_player.anttv") {
        callService("media_player", "media_next_track", entityId)
    }

    function mediaPrevious(entityId = "media_player.anttv") {
        callService("media_player", "media_previous_track", entityId)
    }

    function mediaSeek(position, entityId = "media_player.anttv") {
        callService("media_player", "media_seek", entityId, { seek_position: position })
    }

    function mediaSeekForward(seconds = 30, entityId = "media_player.anttv") {
        const currentPos = appletvPosition || 0
        const newPos = Math.min(currentPos + seconds, appletvDuration || currentPos + seconds)
        mediaSeek(newPos, entityId)
    }

    function mediaSeekBackward(seconds = 30, entityId = "media_player.anttv") {
        const currentPos = appletvPosition || 0
        const newPos = Math.max(currentPos - seconds, 0)
        mediaSeek(newPos, entityId)
    }

    function setVolume(level, entityId = "media_player.anttv") {
        callService("media_player", "volume_set", entityId, { volume_level: level })
    }

    function volumeUp(entityId = "media_player.anttv") {
        callService("media_player", "volume_up", entityId)
    }

    function volumeDown(entityId = "media_player.anttv") {
        callService("media_player", "volume_down", entityId)
    }

    function toggleMute(entityId = "media_player.anttv") {
        callService("media_player", "volume_mute", entityId)
    }

    function turnOn(entityId = "media_player.anttv") {
        callService("media_player", "turn_on", entityId)
    }

    function turnOff(entityId = "media_player.anttv") {
        callService("media_player", "turn_off", entityId)
    }

    function toggleLight(entityId) {
        callService("light", "toggle", entityId)
    }

    function toggleSwitch(entityId) {
        callService("switch", "toggle", entityId)
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "0:00"
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return `${mins}:${secs.toString().padStart(2, '0')}`
    }

    function getMediaIcon(state) {
        switch (state) {
        case "playing": return "play_arrow"
        case "paused": return "pause"
        case "idle": return "stop"
        case "off": return "power_settings_new"
        default: return "music_note"
        }
    }

    function getEntityIcon(entityId, entity) {
        const domain = entityId.split('.')[0]
        const deviceClass = entity?.attributes?.device_class

        switch (domain) {
        case "media_player":
            return getMediaIcon(entity?.state)
        case "light":
            return entity?.state === "on" ? "lightbulb" : "lightbulb_outline"
        case "switch":
            return entity?.state === "on" ? "toggle_on" : "toggle_off"
        case "climate":
            return "thermostat"
        case "cover":
            return entity?.state === "open" ? "window" : "window"
        case "lock":
            return entity?.state === "locked" ? "lock" : "lock_open"
        default:
            return "home"
        }
    }

    // MPRIS-compatible player adapter
    readonly property var mprisAdapter: QtObject {
        readonly property string identity: "HomeAssistant Apple TV"
        readonly property bool canControl: appletvAvailable
        readonly property bool canPlay: appletvAvailable
        readonly property bool canPause: appletvAvailable
        readonly property bool canGoPrevious: appletvAvailable
        readonly property bool canGoNext: appletvAvailable
        readonly property bool canTogglePlaying: appletvAvailable
        readonly property string trackTitle: appletvTitle
        readonly property string trackArtist: appletvArtist
        readonly property int playbackState: {
            if (appletvState === "playing") return 1  // Playing
            if (appletvState === "paused") return 0   // Paused
            return 2  // Stopped
        }
        readonly property bool isPlaying: appletvState === "playing"
        readonly property real position: appletvPosition
        readonly property real length: appletvDuration

        function play() { root.mediaPlayPause() }
        function pause() { root.mediaPlayPause() }
        function togglePlaying() { root.mediaPlayPause() }
        function previous() { root.mediaPrevious() }
        function next() { root.mediaNext() }
        function stop() { root.turnOff() }
    }

    IpcHandler {
        target: "homeassistant"

        function status(): string {
            if (!haAvailable) return "unavailable"
            if (!connected) return "disconnected"
            return "connected"
        }

        function play(): void {
            root.mediaPlay()
        }

        function pause(): void {
            root.mediaPause()
        }

        function playPause(): void {
            root.mediaPlayPause()
        }

        function next(): void {
            root.mediaNext()
        }

        function previous(): void {
            root.mediaPrevious()
        }

        function seekForward(): void {
            root.mediaSeekForward()
        }

        function seekBackward(): void {
            root.mediaSeekBackward()
        }

        function volumeUp(): void {
            root.volumeUp()
        }

        function volumeDown(): void {
            root.volumeDown()
        }

        function toggleMute(): void {
            root.toggleMute()
        }
    }
}