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

const BLOCKED_ICON_NAMES = ["discord"]

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
