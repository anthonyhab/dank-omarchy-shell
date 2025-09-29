pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {

    id: root

    property bool isLightMode: false
    property string wallpaperPath: ""
    property string wallpaperLastPath: ""
    property string profileLastPath: ""
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({})
    property string wallpaperControlMode: "internal"
    property bool wallpaperFallbackInProgress: false
    readonly property int wallpaperValidationRetryLimit: 5
    property bool doNotDisturb: false
    property bool nightModeEnabled: false
    property int nightModeTemperature: 4500
    property bool nightModeAutoEnabled: false
    property string nightModeAutoMode: "time"

    property bool hasTriedDefaultSession: false
    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)
    property int nightModeStartHour: 18
    property int nightModeStartMinute: 0
    property int nightModeEndHour: 6
    property int nightModeEndMinute: 0
    property real latitude: 0.0
    property real longitude: 0.0
    property string nightModeLocationProvider: ""
    property var pinnedApps: []
    property int selectedGpuIndex: 0
    property bool nvidiaGpuTempEnabled: false
    property bool nonNvidiaGpuTempEnabled: false
    property var enabledGpuPciIds: []
    property bool wallpaperCyclingEnabled: false
    property string wallpaperCyclingMode: "interval" // "interval" or "time"
    property int wallpaperCyclingInterval: 300 // seconds (5 minutes)
    property string wallpaperCyclingTime: "06:00" // HH:mm format
    property var monitorCyclingSettings: ({})
    property string lastBrightnessDevice: ""
    property string launchPrefix: ""
    property string wallpaperTransition: "fade"
    readonly property var availableWallpaperTransitions: ["none", "fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]
    property var includedTransitions: availableWallpaperTransitions.filter(t => t !== "none")

    // Power management settings - AC Power
    property int acMonitorTimeout: 0 // Never
    property int acLockTimeout: 0 // Never
    property int acSuspendTimeout: 0 // Never
    property int acHibernateTimeout: 0 // Never

    // Power management settings - Battery
    property int batteryMonitorTimeout: 0 // Never
    property int batteryLockTimeout: 0 // Never
    property int batterySuspendTimeout: 0 // Never
    property int batteryHibernateTimeout: 0 // Never

    property bool lockBeforeSuspend: false

    Component.onCompleted: {
        loadSettings()
        Qt.callLater(function () {
            handleWallpaperControlModeChange(wallpaperControlMode)
        })
    }

    function loadSettings() {
        parseSettings(settingsFile.text())
    }

    function parseSettings(content) {
        try {
            if (content && content.trim()) {
                var settings = JSON.parse(content)
                isLightMode = settings.isLightMode !== undefined ? settings.isLightMode : false
                wallpaperPath = settings.wallpaperPath !== undefined ? settings.wallpaperPath : ""
                wallpaperLastPath = settings.wallpaperLastPath !== undefined ? settings.wallpaperLastPath : ""
                profileLastPath = settings.profileLastPath !== undefined ? settings.profileLastPath : ""
                perMonitorWallpaper = settings.perMonitorWallpaper !== undefined ? settings.perMonitorWallpaper : false
                monitorWallpapers = settings.monitorWallpapers !== undefined ? settings.monitorWallpapers : {}
                doNotDisturb = settings.doNotDisturb !== undefined ? settings.doNotDisturb : false
                nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false
                nightModeTemperature = settings.nightModeTemperature !== undefined ? settings.nightModeTemperature : 4500
                nightModeAutoEnabled = settings.nightModeAutoEnabled !== undefined ? settings.nightModeAutoEnabled : false
                nightModeAutoMode = settings.nightModeAutoMode !== undefined ? settings.nightModeAutoMode : "time"
                // Handle legacy time format
                if (settings.nightModeStartTime !== undefined) {
                    const parts = settings.nightModeStartTime.split(":")
                    nightModeStartHour = parseInt(parts[0]) || 18
                    nightModeStartMinute = parseInt(parts[1]) || 0
                } else {
                    nightModeStartHour = settings.nightModeStartHour !== undefined ? settings.nightModeStartHour : 18
                    nightModeStartMinute = settings.nightModeStartMinute !== undefined ? settings.nightModeStartMinute : 0
                }
                if (settings.nightModeEndTime !== undefined) {
                    const parts = settings.nightModeEndTime.split(":")
                    nightModeEndHour = parseInt(parts[0]) || 6
                    nightModeEndMinute = parseInt(parts[1]) || 0
                } else {
                    nightModeEndHour = settings.nightModeEndHour !== undefined ? settings.nightModeEndHour : 6
                    nightModeEndMinute = settings.nightModeEndMinute !== undefined ? settings.nightModeEndMinute : 0
                }
                latitude = settings.latitude !== undefined ? settings.latitude : 0.0
                longitude = settings.longitude !== undefined ? settings.longitude : 0.0
                nightModeLocationProvider = settings.nightModeLocationProvider !== undefined ? settings.nightModeLocationProvider : ""
                pinnedApps = settings.pinnedApps !== undefined ? settings.pinnedApps : []
                selectedGpuIndex = settings.selectedGpuIndex !== undefined ? settings.selectedGpuIndex : 0
                nvidiaGpuTempEnabled = settings.nvidiaGpuTempEnabled !== undefined ? settings.nvidiaGpuTempEnabled : false
                nonNvidiaGpuTempEnabled = settings.nonNvidiaGpuTempEnabled !== undefined ? settings.nonNvidiaGpuTempEnabled : false
                enabledGpuPciIds = settings.enabledGpuPciIds !== undefined ? settings.enabledGpuPciIds : []
                wallpaperCyclingEnabled = settings.wallpaperCyclingEnabled !== undefined ? settings.wallpaperCyclingEnabled : false
                wallpaperCyclingMode = settings.wallpaperCyclingMode !== undefined ? settings.wallpaperCyclingMode : "interval"
                wallpaperCyclingInterval = settings.wallpaperCyclingInterval !== undefined ? settings.wallpaperCyclingInterval : 300
                wallpaperCyclingTime = settings.wallpaperCyclingTime !== undefined ? settings.wallpaperCyclingTime : "06:00"
                monitorCyclingSettings = settings.monitorCyclingSettings !== undefined ? settings.monitorCyclingSettings : {}
                lastBrightnessDevice = settings.lastBrightnessDevice !== undefined ? settings.lastBrightnessDevice : ""
                launchPrefix = settings.launchPrefix !== undefined ? settings.launchPrefix : ""
                wallpaperTransition = settings.wallpaperTransition !== undefined ? settings.wallpaperTransition : "fade"
                includedTransitions = settings.includedTransitions !== undefined ? settings.includedTransitions : availableWallpaperTransitions.filter(t => t !== "none")
                wallpaperControlMode = settings.wallpaperControlMode !== undefined && settings.wallpaperControlMode === "swww" ? "swww" : "internal"

                acMonitorTimeout = settings.acMonitorTimeout !== undefined ? settings.acMonitorTimeout : 0
                acLockTimeout = settings.acLockTimeout !== undefined ? settings.acLockTimeout : 0
                acSuspendTimeout = settings.acSuspendTimeout !== undefined ? settings.acSuspendTimeout : 0
                acHibernateTimeout = settings.acHibernateTimeout !== undefined ? settings.acHibernateTimeout : 0
                batteryMonitorTimeout = settings.batteryMonitorTimeout !== undefined ? settings.batteryMonitorTimeout : 0
                batteryLockTimeout = settings.batteryLockTimeout !== undefined ? settings.batteryLockTimeout : 0
                batterySuspendTimeout = settings.batterySuspendTimeout !== undefined ? settings.batterySuspendTimeout : 0
                batteryHibernateTimeout = settings.batteryHibernateTimeout !== undefined ? settings.batteryHibernateTimeout : 0
                lockBeforeSuspend = settings.lockBeforeSuspend !== undefined ? settings.lockBeforeSuspend : false

                // Generate system themes but don't override user's theme choice
                if (typeof Theme !== "undefined") {
                    Theme.generateSystemThemesFromCurrentTheme()
                }
            }
        } catch (e) {

        }
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
                                                "isLightMode": isLightMode,
                                                "wallpaperPath": wallpaperPath,
                                                "wallpaperLastPath": wallpaperLastPath,
                                                "profileLastPath": profileLastPath,
                                                "perMonitorWallpaper": perMonitorWallpaper,
                                                "monitorWallpapers": monitorWallpapers,
                                                "doNotDisturb": doNotDisturb,
                                                "nightModeEnabled": nightModeEnabled,
                                                "nightModeTemperature": nightModeTemperature,
                                                "nightModeAutoEnabled": nightModeAutoEnabled,
                                                "nightModeAutoMode": nightModeAutoMode,
                                                "nightModeStartHour": nightModeStartHour,
                                                "nightModeStartMinute": nightModeStartMinute,
                                                "nightModeEndHour": nightModeEndHour,
                                                "nightModeEndMinute": nightModeEndMinute,
                                                "latitude": latitude,
                                                "longitude": longitude,
                                                "nightModeLocationProvider": nightModeLocationProvider,
                                                "pinnedApps": pinnedApps,
                                                "selectedGpuIndex": selectedGpuIndex,
                                                "nvidiaGpuTempEnabled": nvidiaGpuTempEnabled,
                                                "nonNvidiaGpuTempEnabled": nonNvidiaGpuTempEnabled,
                                                "enabledGpuPciIds": enabledGpuPciIds,
                                                "wallpaperCyclingEnabled": wallpaperCyclingEnabled,
                                                "wallpaperCyclingMode": wallpaperCyclingMode,
                                                "wallpaperCyclingInterval": wallpaperCyclingInterval,
                                                "wallpaperCyclingTime": wallpaperCyclingTime,
                                                "monitorCyclingSettings": monitorCyclingSettings,
                                                "lastBrightnessDevice": lastBrightnessDevice,
                                                "launchPrefix": launchPrefix,
                                                "wallpaperTransition": wallpaperTransition,
                                                "includedTransitions": includedTransitions,
                                                "wallpaperControlMode": wallpaperControlMode,
                                                "acMonitorTimeout": acMonitorTimeout,
                                                "acLockTimeout": acLockTimeout,
                                                "acSuspendTimeout": acSuspendTimeout,
                                                "acHibernateTimeout": acHibernateTimeout,
                                                "batteryMonitorTimeout": batteryMonitorTimeout,
                                                "batteryLockTimeout": batteryLockTimeout,
                                                "batterySuspendTimeout": batterySuspendTimeout,
                                                "batteryHibernateTimeout": batteryHibernateTimeout,
                                                "lockBeforeSuspend": lockBeforeSuspend
                                            }, null, 2))
    }

    function setLightMode(lightMode) {
        isLightMode = lightMode
        saveSettings()
    }

    function setDoNotDisturb(enabled) {
        doNotDisturb = enabled
        saveSettings()
    }

    function setNightModeEnabled(enabled) {
        nightModeEnabled = enabled
        saveSettings()
    }

    function setNightModeTemperature(temperature) {
        nightModeTemperature = temperature
        saveSettings()
    }

    function setNightModeAutoEnabled(enabled) {
        console.log("SessionData: Setting nightModeAutoEnabled to", enabled)
        nightModeAutoEnabled = enabled
        saveSettings()
    }

    function setNightModeAutoMode(mode) {
        nightModeAutoMode = mode
        saveSettings()
    }

    function setNightModeStartHour(hour) {
        nightModeStartHour = hour
        saveSettings()
    }

    function setNightModeStartMinute(minute) {
        nightModeStartMinute = minute
        saveSettings()
    }

    function setNightModeEndHour(hour) {
        nightModeEndHour = hour
        saveSettings()
    }

    function setNightModeEndMinute(minute) {
        nightModeEndMinute = minute
        saveSettings()
    }

    function setLatitude(lat) {
        console.log("SessionData: Setting latitude to", lat)
        latitude = lat
        saveSettings()
    }

    function setLongitude(lng) {
        console.log("SessionData: Setting longitude to", lng)
        longitude = lng
        saveSettings()
    }

    function setNightModeLocationProvider(provider) {
        nightModeLocationProvider = provider
        saveSettings()
    }

    function _shq(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function normalizedWallpaperPath(path) {
        if (!path || path === "")
            return ""
        return path.startsWith("file://") ? path.substring(7) : path
    }

    function isOmarchyBackgroundPath(path) {
        if (!path || path === "")
            return false
        const normalized = normalizedWallpaperPath(path)
        return normalized.indexOf("/.config/omarchy/current/theme/backgrounds/") !== -1
    }

    function validateWallpaperPath(path) {
        if (!path || path.startsWith("#") || path.startsWith("we:"))
            return

        const target = normalizedWallpaperPath(path)
        if (!target)
            return

        if (wallpaperValidationProcess.running)
            wallpaperValidationProcess.running = false

        wallpaperValidationRetryTimer.stop()
        wallpaperValidationProcess.targetPath = target
        wallpaperValidationProcess.remainingRetries = isOmarchyBackgroundPath(target) ? wallpaperValidationRetryLimit : 0
        wallpaperValidationProcess.command = ["sh", "-c", "test -f " + _shq(target)]
        wallpaperValidationProcess.running = true
    }

    function handleMissingWallpaper(path) {
        if (!path || path.startsWith("#") || path.startsWith("we:"))
            return

        const target = normalizedWallpaperPath(path)
        if (!target)
            return

        if (isOmarchyBackgroundPath(target)) {
            const dir = target.substring(0, target.lastIndexOf("/"))
            const fileName = target.substring(target.lastIndexOf("/") + 1)
            const dashIndex = fileName.indexOf("-")
            const prefix = dashIndex > 0 ? fileName.substring(0, dashIndex + 1) : ""
            const listCommand = "ls -1 "
                + _shq(dir) + "/*.jpg "
                + _shq(dir) + "/*.jpeg "
                + _shq(dir) + "/*.png "
                + _shq(dir) + "/*.bmp "
                + _shq(dir) + "/*.gif "
                + _shq(dir) + "/*.webp 2>/dev/null | sort"

            omarchyFallbackProcess.originalPath = target
            omarchyFallbackProcess.originalPrefix = prefix
            omarchyFallbackProcess.hasOutput = false
            omarchyFallbackProcess.command = ["sh", "-c", listCommand]
            omarchyFallbackProcess.running = true
            return
        }

        console.warn("SessionData: wallpaper path not found:", target)
    }

    function handleOmarchyFallbackOutput(output, originalPath, prefix) {
        const trimmed = (output || "").trim()
        if (!trimmed) {
            handleFallbackFailure(originalPath)
            return
        }

        const files = trimmed.split("\n").map(path => path.trim()).filter(path => path.length > 0)
        if (files.length === 0) {
            handleFallbackFailure(originalPath)
            return
        }

        var chosen = ""
        if (prefix && prefix.length > 0) {
            chosen = files.find(path => {
                                    const name = path.substring(path.lastIndexOf("/") + 1)
                                    return name.startsWith(prefix)
                                }) || ""
        }

        if (!chosen)
            chosen = files[0]

        applyWallpaperFallback(chosen)
    }

    function handleFallbackFailure(originalPath) {
        if (originalPath && originalPath !== "")
            console.warn("SessionData: No fallback wallpaper found for", originalPath)
    }

    function applyWallpaperFallback(newPath) {
        if (!newPath || newPath === wallpaperPath)
            return

        wallpaperFallbackInProgress = true
        setWallpaper(newPath)
        wallpaperFallbackInProgress = false
    }

    function swwwTransitionOptions() {
        var type = "grow"
        var duration = 1

        switch (wallpaperTransition) {
        case "none":
            type = "simple"
            duration = 0
            break
        case "fade":
            type = "simple"
            duration = 0.8
            break
        case "wipe":
            type = "wipe"
            duration = 1
            break
        case "stripes":
            type = "wave"
            duration = 1
            break
        case "iris bloom":
            type = "center"
            duration = 1
            break
        case "random":
            type = "random"
            duration = 1
            break
        default:
            type = "grow"
            duration = 1
        }

        return {
            "transitionType": type,
            "transitionDuration": duration
        }
    }

    function applyWallpaperToSwwwForMonitor(screenName) {
        if (wallpaperControlMode !== "swww")
            return
        if (typeof SwwwWallpaperService === "undefined")
            return

        var sourcePath = perMonitorWallpaper ? getMonitorWallpaper(screenName) : wallpaperPath
        if (!sourcePath || sourcePath === "" || sourcePath.startsWith("#") || sourcePath.startsWith("we:")) {
            if (screenName && screenName !== "")
                SwwwWallpaperService.clearWallpaper([screenName])
            else
                SwwwWallpaperService.clearWallpaper()
            return
        }

        const target = normalizedWallpaperPath(sourcePath)
        if (!target) {
            if (screenName && screenName !== "")
                SwwwWallpaperService.clearWallpaper([screenName])
            else
                SwwwWallpaperService.clearWallpaper()
            return
        }

        var options = swwwTransitionOptions()
        if (screenName && screenName !== "")
            options.outputs = [screenName]
        SwwwWallpaperService.setWallpaper(target, options)
    }

    function applySwwwPerMonitor() {
        if (typeof Quickshell === "undefined" || !Quickshell.screens || Quickshell.screens.length === 0) {
            applyWallpaperToSwwwForMonitor("")
            return
        }

        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            applyWallpaperToSwwwForMonitor(screens[i].name)
        }
    }

    function applyWallpaperToSwww(path) {
        if (wallpaperControlMode !== "swww")
            return
        if (typeof SwwwWallpaperService === "undefined")
            return

        if (perMonitorWallpaper) {
            applySwwwPerMonitor()
            return
        }

        if (!path || path.startsWith("#") || path.startsWith("we:")) {
            SwwwWallpaperService.clearWallpaper()
            return
        }

        const target = normalizedWallpaperPath(path)
        if (!target) {
            SwwwWallpaperService.clearWallpaper()
            return
        }

        SwwwWallpaperService.setWallpaper(target, swwwTransitionOptions())
    }

    function handleWallpaperControlModeChange(mode) {
        if (mode === "swww") {
            applyWallpaperToSwww(wallpaperPath)
        } else if (typeof SwwwWallpaperService !== "undefined") {
            SwwwWallpaperService.clearWallpaper()
        }
    }

    onWallpaperControlModeChanged: {
        handleWallpaperControlModeChange(wallpaperControlMode)
    }

    onWallpaperPathChanged: {
        if (!wallpaperFallbackInProgress) {
            validateWallpaperPath(wallpaperPath)
        }
        applyWallpaperToSwww(wallpaperPath)
    }

    function setWallpaperPath(path) {
        wallpaperPath = path
        saveSettings()
    }

    function setWallpaper(imagePath) {
        var previousPath = wallpaperPath

        wallpaperPath = imagePath
        saveSettings()

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }

        if (previousPath === imagePath) {
            if (!wallpaperFallbackInProgress)
                validateWallpaperPath(imagePath)
            applyWallpaperToSwww(imagePath)
        }
    }

    function setWallpaperColor(color) {
        var previousPath = wallpaperPath

        wallpaperPath = color
        saveSettings()

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }

        if (previousPath === color) {
            applyWallpaperToSwww(color)
        }
    }

    function clearWallpaper() {
        var alreadyCleared = wallpaperPath === ""
        wallpaperPath = ""
        saveSettings()

        if (typeof Theme !== "undefined") {
            if (typeof SettingsData !== "undefined" && SettingsData.theme) {
                Theme.switchTheme(SettingsData.theme)
            } else {
                Theme.switchTheme("blue")
            }
        }

        if (alreadyCleared) {
            applyWallpaperToSwww("")
        }
    }

    function setWallpaperControlMode(mode) {
        var normalized = mode === "swww" ? "swww" : "internal"
        if (wallpaperControlMode === normalized)
            return
        wallpaperControlMode = normalized
        saveSettings()
    }

    function setWallpaperLastPath(path) {
        wallpaperLastPath = path
        saveSettings()
    }

    function setProfileLastPath(path) {
        profileLastPath = path
        saveSettings()
    }

    function setPinnedApps(apps) {
        pinnedApps = apps
        saveSettings()
    }

    function addPinnedApp(appId) {
        if (!appId)
            return
        var currentPinned = [...pinnedApps]
        if (currentPinned.indexOf(appId) === -1) {
            currentPinned.push(appId)
            setPinnedApps(currentPinned)
        }
    }

    function removePinnedApp(appId) {
        if (!appId)
            return
        var currentPinned = pinnedApps.filter(id => id !== appId)
        setPinnedApps(currentPinned)
    }

    function isPinnedApp(appId) {
        return appId && pinnedApps.indexOf(appId) !== -1
    }

    function setSelectedGpuIndex(index) {
        selectedGpuIndex = index
        saveSettings()
    }

    function setNvidiaGpuTempEnabled(enabled) {
        nvidiaGpuTempEnabled = enabled
        saveSettings()
    }

    function setNonNvidiaGpuTempEnabled(enabled) {
        nonNvidiaGpuTempEnabled = enabled
        saveSettings()
    }

    function setEnabledGpuPciIds(pciIds) {
        enabledGpuPciIds = pciIds
        saveSettings()
    }

    function setWallpaperCyclingEnabled(enabled) {
        wallpaperCyclingEnabled = enabled
        saveSettings()
    }

    function setWallpaperCyclingMode(mode) {
        wallpaperCyclingMode = mode
        saveSettings()
    }

    function setWallpaperCyclingInterval(interval) {
        wallpaperCyclingInterval = interval
        saveSettings()
    }

    function setWallpaperCyclingTime(time) {
        wallpaperCyclingTime = time
        saveSettings()
    }

    function getMonitorCyclingSettings(screenName) {
        return monitorCyclingSettings[screenName] || {
            "enabled": false,
            "mode": "interval",
            "interval": 300,
            "time": "06:00"
        }
    }

    function setMonitorCyclingEnabled(screenName, enabled) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            }
        }
        newSettings[screenName].enabled = enabled
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setMonitorCyclingMode(screenName, mode) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            }
        }
        newSettings[screenName].mode = mode
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setMonitorCyclingInterval(screenName, interval) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            }
        }
        newSettings[screenName].interval = interval
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setMonitorCyclingTime(screenName, time) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            }
        }
        newSettings[screenName].time = time
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setPerMonitorWallpaper(enabled) {
        perMonitorWallpaper = enabled
        saveSettings()

        // Refresh dynamic theming when per-monitor mode changes
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }

        if (wallpaperControlMode === "swww")
            applyWallpaperToSwww(wallpaperPath)
    }

    function setMonitorWallpaper(screenName, path) {
        var newMonitorWallpapers = Object.assign({}, monitorWallpapers)
        if (path && path !== "") {
            newMonitorWallpapers[screenName] = path
        } else {
            delete newMonitorWallpapers[screenName]
        }
        monitorWallpapers = newMonitorWallpapers
        saveSettings()

        // Trigger dynamic theming if this is the first monitor and dynamic theming is enabled
        if (typeof Theme !== "undefined" && typeof Quickshell !== "undefined") {
            var screens = Quickshell.screens
            if (screens.length > 0 && screenName === screens[0].name) {
                Theme.generateSystemThemesFromCurrentTheme()
            }
        }

        if (wallpaperControlMode === "swww")
            applyWallpaperToSwwwForMonitor(screenName)
    }

    function getMonitorWallpaper(screenName) {
        if (!perMonitorWallpaper) {
            return wallpaperPath
        }
        return monitorWallpapers[screenName] || wallpaperPath
    }

    function setLastBrightnessDevice(device) {
        lastBrightnessDevice = device
        saveSettings()
    }

    function setLaunchPrefix(prefix) {
        launchPrefix = prefix
        saveSettings()
    }

    function setWallpaperTransition(transition) {
        wallpaperTransition = transition
        saveSettings()
    }

    function setAcMonitorTimeout(timeout) {
        acMonitorTimeout = timeout
        saveSettings()
    }

    function setAcLockTimeout(timeout) {
        acLockTimeout = timeout
        saveSettings()
    }

    function setAcSuspendTimeout(timeout) {
        acSuspendTimeout = timeout
        saveSettings()
    }

    function setBatteryMonitorTimeout(timeout) {
        batteryMonitorTimeout = timeout
        saveSettings()
    }

    function setBatteryLockTimeout(timeout) {
        batteryLockTimeout = timeout
        saveSettings()
    }

    function setBatterySuspendTimeout(timeout) {
        batterySuspendTimeout = timeout
        saveSettings()
    }

    function setAcHibernateTimeout(timeout) {
        acHibernateTimeout = timeout
        saveSettings()
    }

    function setBatteryHibernateTimeout(timeout) {
        batteryHibernateTimeout = timeout
        saveSettings()
    }

    function setLockBeforeSuspend(enabled) {
        lockBeforeSuspend = enabled
        saveSettings()
    }

    FileView {
        id: settingsFile

        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell/session.json"
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onLoaded: {
            parseSettings(settingsFile.text())
            hasTriedDefaultSession = false
        }
        onLoadFailed: error => {
            if (!hasTriedDefaultSession) {
                hasTriedDefaultSession = true
                defaultSessionCheckProcess.running = true
            }
        }
    }

    Process {
        id: defaultSessionCheckProcess

        command: {
            var configDir = _stateDir + "/DankMaterialShell"
            var quotedDir = _shq(configDir)
            var defaultSessionPath = _shq(configDir + "/default-session.json")
            var sessionPath = _shq(configDir + "/session.json")
            var script = "CONFIG_DIR=" + quotedDir + "; if [ -f " + defaultSessionPath
                + " ] && [ ! -f " + sessionPath + " ]; then cp " + defaultSessionPath + " "
                + sessionPath + " && echo 'copied'; else echo 'not_found'; fi"
            return ["sh", "-c", script]
        }
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Copied default-session.json to session.json")
                settingsFile.reload()
            }
        }
    }

    Process {
        id: wallpaperValidationProcess

        property string targetPath: ""
        property int remainingRetries: 0

        command: ["sh", "-c", "true"]
        running: false
        onExited: exitCode => {
            if (targetPath === "")
                return
            if (exitCode !== 0) {
                if (remainingRetries > 0 && isOmarchyBackgroundPath(targetPath)) {
                    remainingRetries--
                    wallpaperValidationRetryTimer.stop()
                    wallpaperValidationRetryTimer.start()
                    return
                }
                handleMissingWallpaper(targetPath)
            } else {
                wallpaperValidationRetryTimer.stop()
            }
            targetPath = ""
            remainingRetries = 0
        }
    }

    Timer {
        id: wallpaperValidationRetryTimer
        interval: 250
        repeat: false
        running: false
        onTriggered: {
            if (!wallpaperValidationProcess.targetPath)
                return
            wallpaperValidationProcess.command = ["sh", "-c", "test -f " + _shq(wallpaperValidationProcess.targetPath)]
            wallpaperValidationProcess.running = true
        }
    }

    Process {
        id: omarchyFallbackProcess

        property string originalPath: ""
        property string originalPrefix: ""
        property bool hasOutput: false

        command: ["sh", "-c", "true"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                omarchyFallbackProcess.hasOutput = !!text && text.trim().length > 0
                handleOmarchyFallbackOutput(text, omarchyFallbackProcess.originalPath, omarchyFallbackProcess.originalPrefix)
            }
        }

        onRunningChanged: {
            if (running) {
                hasOutput = false
            }
        }

        onExited: exitCode => {
            if (!hasOutput) {
                handleFallbackFailure(originalPath)
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use getFor(screenName) instead."
            }
            return root.wallpaperPath || ""
        }

        function set(path: string): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use setFor(screenName, path) instead."
            }

            if (!path) {
                return "ERROR: No path provided"
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path

            try {
                root.setWallpaper(absolutePath)
                return "SUCCESS: Wallpaper set to " + absolutePath
            } catch (e) {
                return "ERROR: Failed to set wallpaper: " + e.toString()
            }
        }

        function clear(): string {
            root.setWallpaper("")
            root.setPerMonitorWallpaper(false)
            root.monitorWallpapers = {}
            root.saveSettings()
            return "SUCCESS: All wallpapers cleared"
        }

        function next(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use nextFor(screenName) instead."
            }

            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set"
            }

            try {
                WallpaperCyclingService.cycleNextManually()
                return "SUCCESS: Cycling to next wallpaper"
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString()
            }
        }

        function prev(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use prevFor(screenName) instead."
            }

            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set"
            }

            try {
                WallpaperCyclingService.cyclePrevManually()
                return "SUCCESS: Cycling to previous wallpaper"
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString()
            }
        }

        function getFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }
            return root.getMonitorWallpaper(screenName) || ""
        }

        function setFor(screenName: string, path: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }

            if (!path) {
                return "ERROR: No path provided"
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path

            try {
                if (!root.perMonitorWallpaper) {
                    root.setPerMonitorWallpaper(true)
                }
                root.setMonitorWallpaper(screenName, absolutePath)
                return "SUCCESS: Wallpaper set for " + screenName + " to " + absolutePath
            } catch (e) {
                return "ERROR: Failed to set wallpaper for " + screenName + ": " + e.toString()
            }
        }

        function nextFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }

            var currentWallpaper = root.getMonitorWallpaper(screenName)
            if (!currentWallpaper) {
                return "ERROR: No wallpaper set for " + screenName
            }

            try {
                WallpaperCyclingService.cycleNextForMonitor(screenName)
                return "SUCCESS: Cycling to next wallpaper for " + screenName
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper for " + screenName + ": " + e.toString()
            }
        }

        function prevFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }

            var currentWallpaper = root.getMonitorWallpaper(screenName)
            if (!currentWallpaper) {
                return "ERROR: No wallpaper set for " + screenName
            }

            try {
                WallpaperCyclingService.cyclePrevForMonitor(screenName)
                return "SUCCESS: Cycling to previous wallpaper for " + screenName
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper for " + screenName + ": " + e.toString()
            }
        }
    }
}
