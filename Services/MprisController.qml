pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values

    // Unified player that includes both MPRIS and HomeAssistant based on user preference
    property var activePlayer: {
        const mediaSource = SettingsData.mediaSource

        if (mediaSource === "homeassistant" && HomeAssistantService.hasActiveMedia) {
            return HomeAssistantService.mprisAdapter
        }

        if (mediaSource === "mpris") {
            return availablePlayers.find(p => p.isPlaying) ?? availablePlayers.find(p => p.canControl && p.canPlay) ?? null
        }

        // Auto mode: prefer MPRIS if available, fallback to HomeAssistant
        const mprisPlayer = availablePlayers.find(p => p.isPlaying) ?? availablePlayers.find(p => p.canControl && p.canPlay) ?? null
        if (mprisPlayer) {
            return mprisPlayer
        }

        if (HomeAssistantService.hasActiveMedia) {
            return HomeAssistantService.mprisAdapter
        }

        return null
    }

    IpcHandler {
        target: "mpris"

        function list(): string {
            return root.availablePlayers.map(p => p.identity).join("\n")
        }

        function play(): void {
            if (root.activePlayer && root.activePlayer.canPlay) {
                root.activePlayer.play()
            }
        }

        function pause(): void {
            if (root.activePlayer && root.activePlayer.canPause) {
                root.activePlayer.pause()
            }
        }

        function playPause(): void {
            if (root.activePlayer && root.activePlayer.canTogglePlaying) {
                root.activePlayer.togglePlaying()
            }
        }

        function previous(): void {
            if (root.activePlayer && root.activePlayer.canGoPrevious) {
                root.activePlayer.previous()
            }
        }

        function next(): void {
            if (root.activePlayer && root.activePlayer.canGoNext) {
                root.activePlayer.next()
            }
        }

        function stop(): void {
            if (root.activePlayer) {
                root.activePlayer.stop()
            }
        }
    }
}
