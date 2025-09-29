.pragma library

function resolveQuickshell(explicit) {
    if (explicit && typeof explicit.iconPath === "function") {
        return explicit
    }
    const globalObj = (function() { return this; })()
    if (globalObj && typeof globalObj.Quickshell !== "undefined"
            && typeof globalObj.Quickshell.iconPath === "function") {
        return globalObj.Quickshell
    }
    return null
}

const BLOCKED_ICON_NAMES = []

const TRAY_FALLBACK_KEYBOARD_ICON = Qt.resolvedUrl("../assets/tray-icons/input-keyboard-symbolic.svg")
const TRAY_FALLBACK_REFRESH_ICON = Qt.resolvedUrl("../assets/tray-icons/view-refresh-symbolic.svg")
const TRAY_FALLBACK_EXIT_ICON = Qt.resolvedUrl("../assets/tray-icons/application-exit-symbolic.svg")

const TRAY_ICON_FALLBACKS = {
    "input-keyboard": [TRAY_FALLBACK_KEYBOARD_ICON, "input-keyboard-symbolic", "preferences-desktop-keyboard", "keyboard"],
    "input-keyboard-symbolic": [TRAY_FALLBACK_KEYBOARD_ICON, "preferences-desktop-keyboard", "keyboard"],
    "view-refresh": [TRAY_FALLBACK_REFRESH_ICON, "view-refresh-symbolic", "system-reboot", "system-reboot-symbolic"],
    "view-refresh-symbolic": [TRAY_FALLBACK_REFRESH_ICON, "view-refresh", "system-reboot", "system-reboot-symbolic"],
    "application-exit": [TRAY_FALLBACK_EXIT_ICON, "system-log-out-symbolic", "system-log-out", "system-shutdown-symbolic"],
    "application-exit-symbolic": [TRAY_FALLBACK_EXIT_ICON, "system-log-out-symbolic", "system-log-out"]
}

const TRAY_APP_FALLBACKS = {
    "fcitx": [TRAY_FALLBACK_KEYBOARD_ICON, "input-keyboard-symbolic", "preferences-desktop-keyboard"],
    "ibus": [TRAY_FALLBACK_KEYBOARD_ICON, "input-keyboard-symbolic", "preferences-desktop-keyboard"],
    "wl-keyboard": [TRAY_FALLBACK_KEYBOARD_ICON, "input-keyboard-symbolic", "preferences-desktop-keyboard"]
}

const TRAY_DEFAULT_FALLBACKS = [
    TRAY_FALLBACK_KEYBOARD_ICON,
    "applications-system-symbolic",
    "applications-system",
    "dialog-information",
    "dialog-question"
]

function normalize(name) {
    return (name || "").toString().trim().toLowerCase()
}

function iconIsBlocked(name) {
    return BLOCKED_ICON_NAMES.indexOf(normalize(name)) !== -1
}

function safeIconPath(quickshell, iconName, fallbackName, preferSymbolic) {
    const qs = resolveQuickshell(quickshell)
    if (!qs) {
        return ""
    }

    const prefer = preferSymbolic === undefined ? true : preferSymbolic

    if (iconName && !iconIsBlocked(iconName)) {
        const resolved = qs.iconPath(iconName, prefer)
        if (resolved) {
            return resolved
        }
    }

    if (fallbackName) {
        const fallbackResolved = qs.iconPath(fallbackName, prefer)
        if (fallbackResolved) {
            return fallbackResolved
        }
    }

    return ""
}

// Export symbol
var safeIconPath = safeIconPath

function fallbackGlyphForSystemTrayIcon(appId, iconValue, resolvedName) {
    const icon = normalize(iconValue)
    const resolved = normalize(resolvedName)

    if (icon.includes("keyboard") || resolved.includes("keyboard")) {
        return "keyboard"
    }

    if (icon.includes("refresh") || resolved.includes("refresh")) {
        return "autorenew"
    }

    if (icon.includes("exit") || icon.includes("logout") || resolved.includes("exit") || resolved.includes("logout")) {
        return "logout"
    }

    return "help_outline"
}

var fallbackGlyphForSystemTrayIcon = fallbackGlyphForSystemTrayIcon

function normalizeTrayIconValue(iconValue) {
    if (!iconValue) {
        return ""
    }

    const value = iconValue.toString()
    if (value === "") {
        return ""
    }

    const lower = value.toLowerCase()

    if (lower.startsWith("image://") || lower.startsWith("file://") || lower.startsWith("qrc:/") || lower.startsWith("data:")) {
        return value
    }

    if (value.includes("?path=")) {
        const split = value.split("?path=")
        if (split.length === 2) {
            const namePart = split[0]
            const pathPart = split[1]
            const fileName = namePart.substring(namePart.lastIndexOf("/") + 1)
            return `file://${pathPart}/${fileName}`
        }
        return value
    }

    if (value.startsWith("/")) {
        return value.startsWith("file://") ? value : `file://${value}`
    }

    return value
}

function resolveCandidateIcon(quickshell, candidate, preferSymbolic) {
    if (!candidate) {
        return ""
    }

    const value = candidate.toString()
    if (value === "") {
        return ""
    }

    const lower = value.toLowerCase()

    if (lower.startsWith("image://") || lower.startsWith("file://") || lower.startsWith("qrc:/") || lower.startsWith("data:")) {
        return value
    }

    if (value.startsWith("/")) {
        return value.startsWith("file://") ? value : `file://${value}`
    }

    const qs = resolveQuickshell(quickshell)
    if (!qs) {
        return ""
    }

    let resolved = qs.iconPath(value, preferSymbolic !== false)
    if (!resolved && preferSymbolic !== false) {
        resolved = qs.iconPath(value, false)
    }
    if (!resolved) {
        resolved = safeIconPath(qs, value, value, preferSymbolic !== false)
    }
    if (!resolved && preferSymbolic !== false) {
        resolved = safeIconPath(qs, value, value, false)
    }
    return resolved || ""
}

function getSystemTrayFallbackIcons(iconValue, appId) {
    const results = []
    const normalizedName = iconValue ? normalize(iconValue) : ""
    const normalizedApp = appId ? normalize(appId) : ""

    if (normalizedApp && TRAY_APP_FALLBACKS[normalizedApp]) {
        results.push(...TRAY_APP_FALLBACKS[normalizedApp])
    }

    if (normalizedName && TRAY_ICON_FALLBACKS[normalizedName]) {
        results.push(...TRAY_ICON_FALLBACKS[normalizedName])
    }

    for (let i = 0; i < TRAY_DEFAULT_FALLBACKS.length; i++) {
        results.push(TRAY_DEFAULT_FALLBACKS[i])
    }

    const seen = {}
    const unique = []
    for (let i = 0; i < results.length; i++) {
        const icon = results[i]
        if (!icon)
            continue
        const key = icon.toString().toLowerCase()
        if (seen[key])
            continue
        seen[key] = true
        unique.push(icon)
    }

    return unique
}

function resolveSystemTrayIcon(quickshell, appId, iconValue, options) {
    const opts = options || {}
    const preferSymbolic = opts.preferSymbolic !== undefined ? opts.preferSymbolic : false
    const overrideValue = opts.override || ""
    const fallbackList = opts.fallbacks || getSystemTrayFallbackIcons(iconValue, appId)

    const seen = {}
    const candidates = []

    function pushCandidate(name, origin) {
        if (!name)
            return
        const key = name.toString()
        if (key === "")
            return
        if (seen[key])
            return
        seen[key] = true
        candidates.push({
            name: name,
            origin: origin
        })
    }

    const normalizedOverride = normalizeTrayIconValue(overrideValue)
    if (overrideValue && normalizedOverride && normalizedOverride !== overrideValue) {
        pushCandidate(normalizedOverride, "override-path")
    }
    if (overrideValue) {
        pushCandidate(overrideValue, "override")
    }

    const normalizedIcon = normalizeTrayIconValue(iconValue)
    if (normalizedIcon && normalizedIcon !== iconValue) {
        pushCandidate(normalizedIcon, "base-path")
    }
    if (iconValue) {
        pushCandidate(iconValue, "base")
    }

    if (fallbackList && fallbackList.length) {
        for (let i = 0; i < fallbackList.length; i++) {
            pushCandidate(fallbackList[i], "fallback")
        }
    }

    for (let i = 0; i < candidates.length; i++) {
        const candidate = candidates[i]
        const resolved = resolveCandidateIcon(quickshell, candidate.name, preferSymbolic)
        if (resolved && resolved.length > 0) {
            return {
                name: candidate.name,
                path: resolved,
                origin: candidate.origin
            }
        }
    }

    if (preferSymbolic) {
        for (let i = 0; i < candidates.length; i++) {
            const candidate = candidates[i]
            const resolved = resolveCandidateIcon(quickshell, candidate.name, false)
            if (resolved && resolved.length > 0) {
                return {
                    name: candidate.name,
                    path: resolved,
                    origin: candidate.origin
                }
            }
        }
    }

    return {
        name: candidates.length ? candidates[0].name : "",
        path: "",
        origin: candidates.length ? candidates[0].origin : ""
    }
}

var normalizeTrayIconValue = normalizeTrayIconValue
var getSystemTrayFallbackIcons = getSystemTrayFallbackIcons
var resolveSystemTrayIcon = resolveSystemTrayIcon
