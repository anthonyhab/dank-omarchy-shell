import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/IconUtils.js" as IconUtils

Rectangle {
    id: root

    property string screenName: ""
    property real widgetHeight: 30
    property int currentWorkspace: {
        if (CompositorService.isNiri) {
            return getNiriActiveWorkspace()
        } else if (CompositorService.isHyprland) {
            return getHyprlandActiveWorkspace()
        }
        return 1
    }
    property var workspaceSlots: []
    onWorkspaceSlotsChanged: updateActiveHighlight()

    function refreshWorkspaceSlots() {
        let slots = []

        if (CompositorService.isNiri) {
            const baseList = getNiriWorkspaces()
            const resolved = SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
            slots = resolved.map((value, index) => createNiriSlot(value, index))
        } else if (CompositorService.isHyprland) {
            const baseList = getHyprlandWorkspaces()
            const resolved = SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
            slots = resolved.map((entry, index) => createHyprlandSlot(entry, index))
        }

        workspaceSlots = slots
    }

    function normalizeWorkspaceId(rawId, fallbackName) {
        const numeric = Number(rawId)
        if (!isNaN(numeric)) {
            return numeric
        }
        const fromName = Number(fallbackName)
        if (!isNaN(fromName)) {
            return fromName
        }
        return rawId
    }

    function createNiriSlot(value, index) {
        const isPlaceholder = value === -1
        const workspaceNumber = isPlaceholder ? index + 1 : value

        let workspaceObject = null
        if (!isPlaceholder) {
            for (let i = 0; i < NiriService.allWorkspaces.length; ++i) {
                const candidate = NiriService.allWorkspaces[i]
                if (!candidate) {
                    continue
                }
                if (candidate.idx + 1 !== workspaceNumber) {
                    continue
                }
                if (SettingsData.workspacesPerMonitor && root.screenName && root.screenName.length > 0) {
                    if (candidate.output !== root.screenName) {
                        continue
                    }
                }
                workspaceObject = candidate
                break
            }
        }

        const labelValue = workspaceNumber

        return {
            "key": `niri-${isPlaceholder ? `placeholder-${labelValue}` : labelValue}`,
            "kind": "niri",
            "placeholder": isPlaceholder,
            "identifier": workspaceNumber,
            "numericIdentifier": Number(workspaceNumber),
            "displayIndex": workspaceNumber,
            "label": String(labelValue),
            "command": workspaceNumber,
            "iconWorkspaceId": workspaceObject && workspaceObject.id !== undefined ? workspaceObject.id : null,
            "source": workspaceObject,
            "name": workspaceObject && workspaceObject.name ? workspaceObject.name : String(labelValue)
        }
    }

    function createHyprlandSlot(entry, index) {
        const isPlaceholder = !entry || entry.id === -1

        const normalizedId = !isPlaceholder ? normalizeWorkspaceId(entry.id, entry.name) : null
        const numericNormalized = normalizedId !== null && normalizedId !== undefined ? Number(normalizedId) : NaN
        const hasNumeric = !isNaN(numericNormalized)

        let identifier
        if (isPlaceholder) {
            const displayCandidate = entry && entry.displayIndex !== undefined && entry.displayIndex !== null ? entry.displayIndex : (index + 1)
            const numericDisplay = Number(displayCandidate)
            identifier = isNaN(numericDisplay) ? displayCandidate : numericDisplay
        } else if (hasNumeric) {
            identifier = numericNormalized
        } else if (normalizedId !== undefined && normalizedId !== null) {
            identifier = normalizedId
        } else if (entry && entry.name !== undefined && entry.name !== null) {
            identifier = entry.name
        } else {
            identifier = index + 1
        }

        const numericIdentifier = Number(identifier)
        const identifierIsNumeric = !isNaN(numericIdentifier)

        let displayIndex = identifierIsNumeric ? numericIdentifier : null
        if (displayIndex === null || displayIndex === undefined) {
            if (entry && entry.displayIndex !== undefined && entry.displayIndex !== null) {
                displayIndex = entry.displayIndex
            } else if (entry && entry.name !== undefined && entry.name !== null) {
                displayIndex = entry.name
            } else {
                displayIndex = index + 1
            }
        }

        const labelValue = displayIndex !== undefined && displayIndex !== null ? displayIndex : identifier
        const commandTarget = !isPlaceholder && entry && entry.name && entry.name.length > 0 ? entry.name : identifier

        let keyToken
        if (isPlaceholder) {
            keyToken = `placeholder-${labelValue}`
        } else if (entry && entry.id !== undefined && entry.id !== null) {
            keyToken = `id-${entry.id}`
        } else if (entry && entry.name !== undefined && entry.name !== null) {
            keyToken = `name-${entry.name}`
        } else {
            keyToken = `idx-${index}`
        }

        return {
            "key": `hypr-${keyToken}`,
            "kind": "hyprland",
            "placeholder": isPlaceholder,
            "identifier": identifier,
            "numericIdentifier": identifierIsNumeric ? numericIdentifier : NaN,
            "displayIndex": displayIndex,
            "label": String(labelValue),
            "command": commandTarget,
            "iconWorkspaceId": identifierIsNumeric ? numericIdentifier : null,
            "name": entry && entry.name ? entry.name : String(labelValue),
            "source": isPlaceholder ? null : entry,
            "persistent": entry && entry.persistent === true
        }
    }

    function slotDisplayLabel(slot) {
        if (!slot) {
            return ""
        }
        if (slot.label !== undefined && slot.label !== null) {
            return slot.label
        }
        if (slot.identifier !== undefined && slot.identifier !== null) {
            return String(slot.identifier)
        }
        return ""
    }

    function workspaceSortValue(ws) {
        if (!ws) {
            return Number.MAX_SAFE_INTEGER
        }

        if (ws.id !== undefined && ws.id !== -1) {
            const normalized = normalizeWorkspaceId(ws.id, ws.name)
            const numeric = Number(normalized)
            if (!isNaN(numeric)) {
                return numeric
            }
            return Number.MAX_SAFE_INTEGER - 1
        }

        if (ws.displayIndex !== undefined) {
            return ws.displayIndex
        }

        return Number.MAX_SAFE_INTEGER
    }

    function getWorkspaceIcons(slot) {
        if (!SettingsData.showWorkspaceApps || !slot || slot.placeholder) {
            return []
        }

        let targetWorkspaceId = null
        let isActiveWs = false

        if (slot.kind === "niri") {
            const workspaceObject = slot.source
            if (!workspaceObject) {
                return []
            }
            targetWorkspaceId = workspaceObject.id
            isActiveWs = !!workspaceObject.is_active
        } else if (slot.kind === "hyprland") {
            if (slot.iconWorkspaceId === null || slot.iconWorkspaceId === undefined || slot.iconWorkspaceId === -1) {
                return []
            }
            targetWorkspaceId = slot.iconWorkspaceId
            isActiveWs = workspaceEntryMatchesTarget(slot, root.currentWorkspace)
        } else {
            return []
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels
        const hyprlandToplevels = slot.kind === "hyprland" ? Array.from(Hyprland.toplevels?.values || []) : []

        const byApp = {}

        wins.forEach((w, i) => {
                         if (!w) {
                             return
                         }

                         let belongsToSlot = false
                         if (slot.kind === "niri") {
                             belongsToSlot = w.workspace_id === targetWorkspaceId
                         } else if (slot.kind === "hyprland") {
                             const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w)
                             const winWorkspace = normalizeWorkspaceId(hyprToplevel && hyprToplevel.workspace ? hyprToplevel.workspace.id : undefined,
                                                                      hyprToplevel && hyprToplevel.workspace ? hyprToplevel.workspace.name : undefined)
                             belongsToSlot = workspaceEntryMatchesTarget(slot, winWorkspace)
                         }

                         if (!belongsToSlot) {
                             return
                         }

                         const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown").toLowerCase()
                         const key = isActiveWs ? `${keyBase}_${i}` : keyBase

                         if (!byApp[key]) {
                             const moddedId = Paths.moddedAppId(keyBase)
                             const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                             const icon = isSteamApp ? "" : IconUtils.safeIconPath(Quickshell, DesktopEntries.heuristicLookup(moddedId)?.icon, "application-x-executable")
                             byApp[key] = {
                                 "type": "icon",
                                 "icon": icon,
                                 "isSteamApp": isSteamApp,
                                 "active": !!(w.activated || (CompositorService.isNiri && w.is_focused)),
                                 "count": 1,
                                 "windowId": w.address || w.id,
                                 "fallbackText": w.appId || w.class || w.title || ""
                             }
                         } else {
                             byApp[key].count++
                             if (w.activated || (CompositorService.isNiri && w.is_focused)) {
                                 byApp[key].active = true
                             }
                         }
                     })

        return Object.values(byApp)
    }

    function configuredPaddingMinimum() {
        const rawValue = SettingsData.workspacePaddingSlots !== undefined ? SettingsData.workspacePaddingSlots : 3
        const numericValue = Number(rawValue)
        if (isNaN(numericValue)) {
            return 3
        }
        return Math.max(1, Math.round(numericValue))
    }

    function padWorkspaces(list) {
        const padded = list.slice()

        if (CompositorService.isHyprland) {
            const numericIds = new Set()

            const registerNumeric = value => {
                const numeric = Number(value)
                if (!isNaN(numeric)) {
                    numericIds.add(numeric)
                }
            }

            // Collect existing indices
            padded.forEach(ws => {
                               if (!ws) {
                                   return
                               }

                               if (ws.id !== undefined && ws.id !== -1) {
                                   const normalized = normalizeWorkspaceId(ws.id, ws.name)
                                   registerNumeric(normalized)
                               } else if (ws.displayIndex !== undefined) {
                                   registerNumeric(ws.displayIndex)
                               }
                           })

            // Ensure target indices (current, highlight, desired) are present
            const ensureIndices = []
            const cur = Number(root.currentWorkspace)
            const desired = Number(root.desiredWorkspaceTarget)
            const highlight = Number(root.highlightWorkspaceTarget)
            if (!isNaN(cur))
                ensureIndices.push(cur)
            if (!isNaN(desired))
                ensureIndices.push(desired)
            if (!isNaN(highlight))
                ensureIndices.push(highlight)

            let highestExisting = 0
            numericIds.forEach(value => {
                                   if (value > highestExisting)
                                   highestExisting = value
                               })

            let highestEnsure = 0
            ensureIndices.forEach(value => {
                                      const clamped = Math.max(1, Math.min(root.maxWorkspaceIndex, value))
                                      if (clamped > highestEnsure)
                                      highestEnsure = clamped
                                  })

            const minimumVisible = configuredPaddingMinimum()
            const targetMax = Math.max(minimumVisible, highestExisting, highestEnsure)

            for (var idx = 1; idx <= targetMax; idx++) {
                if (numericIds.has(idx)) {
                    continue
                }

                padded.push({
                                "id": -1,
                                "name": String(idx),
                                "displayIndex": idx
                            })
                numericIds.add(idx)
            }

            padded.sort((a, b) => workspaceSortValue(a) - workspaceSortValue(b))
        } else {
            // Niri: ensure at least current and target indices are representable
            const ensureIndices = []
            const cur = Number(root.currentWorkspace)
            const desired = Number(root.desiredWorkspaceTarget)
            const highlight = Number(root.highlightWorkspaceTarget)
            if (!isNaN(cur))
                ensureIndices.push(cur)
            if (!isNaN(desired))
                ensureIndices.push(desired)
            if (!isNaN(highlight))
                ensureIndices.push(highlight)

            const ensureMax = ensureIndices.length > 0 ? Math.max.apply(null, ensureIndices.map(v => Math.max(1, Math.min(root.maxWorkspaceIndex, v)))) : 0
            const minimumVisible = configuredPaddingMinimum()
            let targetLen = Math.max(minimumVisible, Math.max(ensureMax, padded.length))
            while (padded.length < targetLen) {
                padded.push(-1)
            }
        }

        return padded
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0) {
            return [1, 2]
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentOutputWorkspaceNumbers()
        }

        const displayWorkspaces = NiriService.allWorkspaces.filter(ws => ws.output === root.screenName).map(ws => ws.idx + 1)
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2]
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0) {
            return 1
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentWorkspaceNumber()
        }

        const activeWs = NiriService.allWorkspaces.find(ws => ws.output === root.screenName && ws.is_active)
        return activeWs ? activeWs.idx + 1 : 1
    }

    function getHyprlandWorkspaces() {
        const workspaces = Hyprland.workspaces?.values || []

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            const sorted = workspaces.slice().sort((a, b) => workspaceSortValue(a) - workspaceSortValue(b))
            return sorted.length > 0 ? sorted : [{
                                                     "id": 1,
                                                     "name": "1"
                                                 }]
        }

        const monitor = (Hyprland.monitors?.values || []).find(m => m && m.name === root.screenName)

        const monitorName = monitor ? monitor.name : root.screenName
        const monitorId = monitor && monitor.id !== undefined ? monitor.id : undefined
        const assignedIds = []

        if (monitor && monitor.workspaces !== undefined) {
            const workspacesList = Array.isArray(monitor.workspaces) ? monitor.workspaces : (typeof monitor.workspaces === "object" && monitor.workspaces.values) ? monitor.workspaces.values : []

            workspacesList.forEach(item => {
                                       const normalized = normalizeWorkspaceId(item && item.id !== undefined ? item.id : item, item?.name)
                                       if (normalized !== undefined && normalized !== null) {
                                           assignedIds.push(normalized)
                                       }
                                   })
        }

        const monitorWorkspaces = workspaces.filter(ws => {
                                                        return ws.lastIpcObject && ws.lastIpcObject.monitor === root.screenName
                                                    })

        if (monitorWorkspaces.length === 0) {
            // Fallback if no workspaces exist for this monitor
            return [{
                        "id": 1,
                        "name": "1"
                    }]
        }

        let sorted = monitorWorkspaces.slice().sort((a, b) => workspaceSortValue(a) - workspaceSortValue(b))

        if (assignedIds.length > 0) {
            const numericAssigned = assignedIds.map(id => Number(id)).filter(id => !isNaN(id)).sort((a, b) => a - b)

            if (numericAssigned.length > 0) {
                const existingNumeric = new Set()
                sorted.forEach(ws => {
                                   const normalized = normalizeWorkspaceId(ws.id, ws.name)
                                   const numeric = Number(normalized)
                                   if (!isNaN(numeric)) {
                                       existingNumeric.add(numeric)
                                   }
                               })

                numericAssigned.forEach(id => {
                                            if (existingNumeric.has(id)) {
                                                return
                                            }

                                            sorted.push({
                                                            "id": -1,
                                                            "name": String(id),
                                                            "displayIndex": id,
                                                            "persistent": true
                                                        })
                                        })

                sorted = sorted.sort((a, b) => workspaceSortValue(a) - workspaceSortValue(b))
            }
        }

        return sorted.length > 0 ? sorted : [{
                                                 "id": 1,
                                                 "name": "1"
                                             }]
    }

    function getHyprlandActiveWorkspace() {
        let candidate = null

        const monitors = Hyprland.monitors?.values || []
        if (root.screenName && monitors.length > 0) {
            const currentMonitor = monitors.find(monitor => monitor && monitor.name === root.screenName)
            if (currentMonitor) {
                const monitorWorkspace = normalizeWorkspaceId(currentMonitor.activeWorkspace?.id, currentMonitor.activeWorkspace?.name)
                if (monitorWorkspace !== undefined && monitorWorkspace !== null) {
                    candidate = monitorWorkspace
                }
            }
        }

        if (candidate === null || candidate === undefined) {
            const focused = Hyprland.focusedWorkspace
            if (focused) {
                const focusedWorkspace = normalizeWorkspaceId(focused.id, focused.name)
                if (focusedWorkspace !== undefined && focusedWorkspace !== null) {
                    candidate = focusedWorkspace
                }
            }
        }

        if (candidate === null || candidate === undefined) {
            candidate = hyprlandWorkspaceCache
        }

        if (candidate === null || candidate === undefined) {
            candidate = 1
        }

        return candidate
    }

    readonly property real padding: (widgetHeight - workspaceRow.implicitHeight) / 2
    property int maxWorkspaceIndex: {
        let maxValue = Math.max(10, configuredPaddingMinimum())
        for (let i = 0; i < workspaceSlots.length; ++i) {
            const slot = workspaceSlots[i]
            if (!slot) {
                continue
            }
            const numericIdentifier = Number(slot.identifier)
            if (!isNaN(numericIdentifier)) {
                if (numericIdentifier > maxValue) {
                    maxValue = numericIdentifier
                }
            } else if (slot.displayIndex !== undefined && slot.displayIndex !== null) {
                const displayNumeric = Number(slot.displayIndex)
                if (!isNaN(displayNumeric) && displayNumeric > maxValue) {
                    maxValue = displayNumeric
                }
            }
        }
        return maxValue
    }
    property var desiredWorkspaceTarget: null
    property var highlightWorkspaceTarget: currentWorkspace
    property var hyprlandWorkspaceCache: 1
    property int lastHighlightIndex: -1

    Timer {
        id: highlightUpdateTimer
        interval: 0
        repeat: false
        onTriggered: root._applyHighlightGeometry()
    }

    function scheduleHighlightUpdate() {
        highlightUpdateTimer.restart()
    }

    function resolveWorkspaceTarget(target, clampToLimit) {
        if (target === undefined || target === null || target === "") {
            return null
        }

        const numericTarget = Number(target)
        if (!isNaN(numericTarget)) {
            let value = Math.round(numericTarget)
            if (clampToLimit) {
                value = Math.max(1, Math.min(root.maxWorkspaceIndex, value))
            }
            return value
        }

        return target
    }

    function setDesiredWorkspaceTarget(target, clampToLimit) {
        desiredWorkspaceTarget = resolveWorkspaceTarget(target, clampToLimit)
        syncHighlightTarget()
    }

    function clearDesiredWorkspaceTarget() {
        desiredWorkspaceTarget = null
        syncHighlightTarget()
    }

    function syncHighlightTarget() {
        const desired = desiredWorkspaceTarget
        const resolved = desired !== null && desired !== undefined ? desired : root.currentWorkspace
        if (highlightWorkspaceTarget !== resolved) {
            highlightWorkspaceTarget = resolved
        }
        scheduleHighlightUpdate()
    }

    function updateActiveHighlight() {
        scheduleHighlightUpdate()
    }

    function getHyprlandWorkspaceIdentifier(entry) {
        if (!entry) {
            return null
        }

        if (entry.kind === "hyprland") {
            if (entry.identifier !== undefined && entry.identifier !== null) {
                return entry.identifier
            }
            if (entry.source) {
                return getHyprlandWorkspaceIdentifier(entry.source)
            }
        }

        if (entry.id !== undefined && entry.id !== -1) {
            return normalizeWorkspaceId(entry.id, entry.name)
        }

        if (entry.displayIndex !== undefined && entry.displayIndex !== null) {
            return entry.displayIndex
        }

        if (entry.name !== undefined && entry.name !== null) {
            const numericName = Number(entry.name)
            if (!isNaN(numericName)) {
                return numericName
            }
            return entry.name
        }

        return null
    }

    function hyprlandWorkspaceMatches(entry, target) {
        if (!entry || target === undefined || target === null) {
            return false
        }

        const identifier = getHyprlandWorkspaceIdentifier(entry)
        if (identifier === null || identifier === undefined) {
            return false
        }

        const numericTarget = Number(target)
        const numericIdentifier = Number(identifier)

        if (!isNaN(numericTarget) && !isNaN(numericIdentifier)) {
            if (numericIdentifier === numericTarget) {
                return true
            }
        }

        if (identifier === target) {
            return true
        }

        return String(identifier) === String(target)
    }

    function isHyprlandActiveWorkspace(entry) {
        if (!entry) {
            return false
        }

        return hyprlandWorkspaceMatches(entry, root.currentWorkspace)
    }

    function workspaceEntryMatchesTarget(entry, target) {
        if (target === undefined || target === null || entry === undefined || entry === null) {
            return false
        }

        if (entry.kind === "hyprland" || CompositorService.isHyprland) {
            return hyprlandWorkspaceMatches(entry, target)
        }

        const candidate = entry.identifier !== undefined ? entry.identifier : entry
        const numericTarget = Number(target)
        const numericEntry = Number(candidate)

        if (!isNaN(numericTarget) && !isNaN(numericEntry)) {
            return numericEntry === numericTarget
        }

        if (candidate !== undefined && candidate !== null) {
            if (candidate === target) {
                return true
            }
            return String(candidate) === String(target)
        }

        return false
    }

    function workspaceSlotHeight() {
        return SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
    }

    function workspaceSlotWidth(slot) {
        if (!slot || slot.placeholder || !SettingsData.showWorkspaceApps) {
            return widgetHeight * 1.2
        }

        const icons = root.getWorkspaceIcons(slot) || []
        const numIcons = Math.min(icons.length, SettingsData.maxWorkspaceIcons)
        const iconsWidth = numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0)
        const baseWidth = widgetHeight * 1.0 + Theme.spacingXS
        return baseWidth + iconsWidth
    }

    function predictedGeometryForIndex(index) {
        const list = root.workspaceSlots || []
        if (index < 0 || index >= list.length) {
            return null
        }

        const rowTopLeft = workspaceRow.mapToItem(root, 0, 0)
        const spacing = workspaceRow.spacing || 0
        let x = rowTopLeft.x

        for (var i = 0; i < index; ++i) {
            const slot = list[i]
            const delegate = workspaceRepeater && workspaceRepeater.itemAt ? workspaceRepeater.itemAt(i) : null
            const width = delegate ? delegate.width : workspaceSlotWidth(slot)
            x += width + spacing
        }

        const slot = list[index]
        const delegate = workspaceRepeater && workspaceRepeater.itemAt ? workspaceRepeater.itemAt(index) : null
        const slotWidth = delegate ? delegate.width : workspaceSlotWidth(slot)
        const slotHeight = delegate ? delegate.height : workspaceSlotHeight()
        const rowHeight = workspaceRow.height > 0 ? workspaceRow.height : workspaceRow.implicitHeight
        const baseHeight = rowHeight > 0 ? rowHeight : slotHeight
        const yOffset = Math.max(0, (baseHeight - slotHeight) / 2)
        const y = rowTopLeft.y + yOffset

        return {
            "x": x,
            "y": y,
            "width": slotWidth,
            "height": slotHeight
        }
    }

    function workspaceIndexForTarget(target) {
        if (target === undefined || target === null) {
            return -1
        }

        const list = root.workspaceSlots || []
        for (var i = 0; i < list.length; ++i) {
            if (workspaceEntryMatchesTarget(list[i], target)) {
                return i
            }
        }

        return -1
    }

    function delegateInfoForTarget(target) {
        const index = workspaceIndexForTarget(target)
        if (index < 0) {
            return {
                "index": -1,
                "delegate": null
            }
        }

        if (!workspaceRepeater || !workspaceRepeater.itemAt) {
            return {
                "index": index,
                "delegate": null
            }
        }

        const delegate = workspaceRepeater.itemAt(index)
        if (!delegate) {
            scheduleHighlightUpdate()
        }

        return {
            "index": index,
            "delegate": delegate
        }
    }

    function _applyHighlightGeometry() {
        const targetInfo = delegateInfoForTarget(highlightWorkspaceTarget)
        var activeDelegate = targetInfo.delegate
        var activeIndex = targetInfo.index

        // If the target is not present in the model yet, avoid snapping
        // back to the current workspace. Keep the previous highlight until
        // the model updates (refreshWorkspaceSlots schedules another pass).
        if (activeIndex < 0) {
            return
        }

        if (!activeDelegate && targetInfo.index >= 0) {
            const predicted = predictedGeometryForIndex(targetInfo.index)
            if (predicted) {
                activeHighlight.visible = true
                activeHighlight.width = predicted.width
                activeHighlight.height = predicted.height
                activeHighlight.x = predicted.x
                activeHighlight.y = predicted.y
                activeHighlight.radius = Math.min(Theme.cornerRadius, predicted.height / 2)
                lastHighlightIndex = targetInfo.index
                return
            }
        }

        if (!activeDelegate) {
            const currentInfo = delegateInfoForTarget(root.currentWorkspace)
            activeDelegate = currentInfo.delegate
            activeIndex = currentInfo.index
        }

        if (!activeDelegate && lastHighlightIndex >= 0 && workspaceRepeater && workspaceRepeater.itemAt) {
            const fallbackDelegate = workspaceRepeater.itemAt(lastHighlightIndex)
            if (fallbackDelegate) {
                activeDelegate = fallbackDelegate
                activeIndex = lastHighlightIndex
            }
        }

        if (!activeDelegate) {
            if (targetInfo.index === -1 && lastHighlightIndex === -1) {
                activeHighlight.visible = false
                lastHighlightIndex = -1
            }
            return
        }

        const topLeft = activeDelegate.mapToItem(root, 0, 0)
        activeHighlight.visible = true
        activeHighlight.width = activeDelegate.width
        activeHighlight.height = activeDelegate.height
        activeHighlight.x = topLeft.x
        activeHighlight.y = topLeft.y
        activeHighlight.radius = Math.min(Theme.cornerRadius, activeHighlight.height / 2)
        lastHighlightIndex = activeIndex
    }

    function getRealWorkspaces() {
        return root.workspaceSlots.filter(slot => slot && !slot.placeholder)
    }

    function nextHyprlandTarget(direction) {
        const cur = Number(root.currentWorkspace)
        if (isNaN(cur)) {
            return null
        }

        const next = cur + (direction > 0 ? 1 : -1)
        if (next < 1 || next > root.maxWorkspaceIndex) {
            return null
        }

        return next
    }

    function performHyprlandSwitch(target, clampToLimit, highlightOverride) {
        const resolvedCommand = resolveWorkspaceTarget(target, clampToLimit)
        const highlightValue = highlightOverride !== undefined && highlightOverride !== null ? resolveWorkspaceTarget(highlightOverride, clampToLimit) : resolvedCommand

        if (highlightValue === null || highlightValue === undefined) {
            return
        }

        const highlightUnchanged = (highlightValue === root.currentWorkspace && desiredWorkspaceTarget === null)
        const commandUnavailable = resolvedCommand === null || resolvedCommand === undefined

        setDesiredWorkspaceTarget(highlightValue, clampToLimit)

        if (highlightUnchanged || commandUnavailable) {
            return
        }

        Hyprland.dispatch(`workspace ${resolvedCommand}`)
    }

    function switchWorkspace(direction) {
        if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(slot => workspaceEntryMatchesTarget(slot, root.currentWorkspace))
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? (validIndex + 1) % realWorkspaces.length : (validIndex - 1 + realWorkspaces.length) % realWorkspaces.length
            const targetSlot = realWorkspaces[nextIndex]
            const workspaceNumber = Number(targetSlot.identifier)
            if (!isNaN(workspaceNumber)) {
                NiriService.switchToWorkspace(workspaceNumber - 1)
            }
        } else if (CompositorService.isHyprland) {
            const target = nextHyprlandTarget(direction)
            performHyprlandSwitch(target, true)
        }
    }

    width: workspaceRow.implicitWidth + padding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground)
            return "transparent"
        const baseColor = Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland
    clip: true
    onCurrentWorkspaceChanged: {
        if (CompositorService.isHyprland && root.currentWorkspace !== undefined && root.currentWorkspace !== null) {
            if (hyprlandWorkspaceCache !== root.currentWorkspace) {
                hyprlandWorkspaceCache = root.currentWorkspace
            }
        }
        if (desiredWorkspaceTarget !== null && desiredWorkspaceTarget !== undefined) {
            const desiredNumeric = Number(desiredWorkspaceTarget)
            const currentNumeric = Number(root.currentWorkspace)

            if ((!isNaN(desiredNumeric) && !isNaN(currentNumeric) && desiredNumeric === currentNumeric) || desiredWorkspaceTarget === root.currentWorkspace) {
                clearDesiredWorkspaceTarget()
            } else {
                syncHighlightTarget()
            }
        } else {
            syncHighlightTarget()
        }
    }
    onWidgetHeightChanged: updateActiveHighlight()
    onScreenNameChanged: {
        refreshWorkspaceSlots()
        updateActiveHighlight()
    }
    Component.onCompleted: {
        refreshWorkspaceSlots()
        hyprlandWorkspaceCache = root.currentWorkspace
        highlightWorkspaceTarget = root.currentWorkspace
        syncHighlightTarget()
        updateActiveHighlight()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        property real scrollAccumulator: 0
        property real touchpadThreshold: 500

        onWheel: wheel => {
                     const deltaY = wheel.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0
                     const direction = deltaY < 0 ? 1 : -1

                     if (isMouseWheel) {
                         switchWorkspace(direction)
                     } else {
                         scrollAccumulator += deltaY

                         if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                             const touchDirection = scrollAccumulator < 0 ? 1 : -1
                             switchWorkspace(touchDirection)
                             scrollAccumulator = 0
                         }
                     }

                     wheel.accepted = true
                 }
    }

    Rectangle {
        id: activeHighlight

        z: 0
        visible: false
        color: Theme.primary
        radius: Math.min(Theme.cornerRadius, height / 2)
        antialiasing: true

        Behavior on x {
            SpringAnimation {
                spring: 4.5
                damping: 0.5
                epsilon: 0.25
            }
        }

        Behavior on y {
            SpringAnimation {
                spring: 4.5
                damping: 0.5
                epsilon: 0.25
            }
        }

        Behavior on width {
            SpringAnimation {
                spring: 5
                damping: 0.55
                epsilon: 0.3
            }
        }

        Behavior on height {
            SpringAnimation {
                spring: 5
                damping: 0.55
                epsilon: 0.3
            }
        }

        Behavior on radius {
            SpringAnimation {
                spring: 5
                damping: 0.55
                epsilon: 0.3
            }
        }
    }

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        z: 1

        Repeater {
            id: workspaceRepeater
            model: root.workspaceSlots
            onItemAdded: root.scheduleHighlightUpdate()
            onItemRemoved: root.scheduleHighlightUpdate()

            Rectangle {
                id: delegateRoot

                property var slot: modelData || null
                property bool isPlaceholder: slot ? !!slot.placeholder : false
                property bool isActive: slot ? root.workspaceEntryMatchesTarget(slot, root.currentWorkspace) : false
                property bool isHovered: mouseArea.containsMouse

                property var loadedWorkspaceData: null
                property var loadedIconData: null
                property bool loadedHasIcon: false
                property var loadedIcons: []

                function updateAllData() {
                    if (isPlaceholder || !slot) {
                        loadedWorkspaceData = null
                        loadedIconData = null
                        loadedHasIcon = false
                        loadedIcons = []
                        return
                    }

                    loadedWorkspaceData = slot.source || null

                    var iconData = null
                    if (slot.name) {
                        iconData = SettingsData.getWorkspaceNameIcon(slot.name)
                    }
                    loadedIconData = iconData
                    loadedHasIcon = iconData !== null && iconData !== undefined

                    if (SettingsData.showWorkspaceApps) {
                        loadedIcons = root.getWorkspaceIcons(slot)
                    } else {
                        loadedIcons = []
                    }
                }

                Timer {
                    id: dataUpdateTimer
                    interval: 50
                    onTriggered: {
                        delegateRoot.updateAllData()
                        root.updateActiveHighlight()
                    }
                }

                Component.onCompleted: dataUpdateTimer.restart()
                Component.onDestruction: root.updateActiveHighlight()
                onSlotChanged: dataUpdateTimer.restart()
                onIsActiveChanged: root.updateActiveHighlight()
                onWidthChanged: {
                    if (isActive) {
                        root.updateActiveHighlight()
                    }
                }
                onHeightChanged: {
                    if (isActive) {
                        root.updateActiveHighlight()
                    }
                }

                width: {
                    if (SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                        const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons)
                        const iconsWidth = numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0)
                        const baseWidth = root.widgetHeight * 1.0 + Theme.spacingXS
                        return baseWidth + iconsWidth
                    }
                    return root.widgetHeight * 1.2
                }
                height: SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
                radius: Math.min(Theme.cornerRadius, height / 2)
                color: {
                    if (isActive) {
                        return "transparent"
                    }
                    if (isPlaceholder) {
                        return Theme.surfaceTextLight
                    }
                    return isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (isPlaceholder || !slot) {
                            return
                        }

                        if (slot.kind === "niri") {
                            const workspaceNumber = Number(slot.identifier)
                            if (!isNaN(workspaceNumber)) {
                                NiriService.switchToWorkspace(workspaceNumber - 1)
                            }
                        } else if (slot.kind === "hyprland") {
                            root.performHyprlandSwitch(slot.command, false, slot.identifier)
                        }
                    }
                }

                Loader {
                    id: appIconsLoader
                    anchors.fill: parent
                    active: SettingsData.showWorkspaceApps
                    sourceComponent: Item {
                        Row {
                            id: contentRow
                            anchors.centerIn: parent
                            spacing: 4
                            visible: loadedIcons.length > 0

                            Repeater {
                                model: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
                                delegate: Item {
                                    width: 18
                                    height: 18

                                    IconImage {
                                        id: appIcon
                                        property var windowId: modelData.windowId
                                        anchors.fill: parent
                                        source: modelData.icon
                                        opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                        visible: !modelData.isSteamApp
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        size: 18
                                        name: "sports_esports"
                                        color: Theme.surfaceText
                                        opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                        visible: modelData.isSteamApp
                                    }

                                    MouseArea {
                                        id: appMouseArea
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        enabled: isActive
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (CompositorService.isHyprland) {
                                                Hyprland.dispatch(`focuswindow address:${appIcon.windowId}`)
                                            } else if (CompositorService.isNiri) {
                                                NiriService.focusWindow(appIcon.windowId)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.count > 1 && !isActive
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: "black"
                                        border.color: "white"
                                        border.width: 1
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        z: 2

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.count
                                            font.pixelSize: 8
                                            color: "white"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: customIconLoader
                    anchors.fill: parent
                    active: !isPlaceholder && loadedHasIcon && loadedIconData.type === "icon" && !SettingsData.showWorkspaceApps
                    sourceComponent: Item {
                        DankIcon {
                            anchors.centerIn: parent
                            name: loadedIconData ? loadedIconData.value : ""
                            size: Theme.fontSizeSmall
                            color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                            weight: isActive && !isPlaceholder ? 500 : 400
                        }
                    }
                }

                Loader {
                    id: customTextLoader
                    anchors.fill: parent
                    active: !isPlaceholder && loadedHasIcon && loadedIconData.type === "text" && !SettingsData.showWorkspaceApps
                    sourceComponent: Item {
                        StyledText {
                            anchors.centerIn: parent
                            text: loadedIconData ? loadedIconData.value : ""
                            color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                Loader {
                    id: indexLoader
                    anchors.fill: parent
                    active: SettingsData.showWorkspaceIndex && !SettingsData.showWorkspaceApps && (!loadedHasIcon || isPlaceholder)
                    sourceComponent: Item {
                        StyledText {
                            anchors.centerIn: parent
                            text: root.slotDisplayLabel(slot)
                            color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                Connections {
                    target: CompositorService
                    function onSortedToplevelsChanged() {
                        delegateRoot.updateAllData()
                        root.updateActiveHighlight()
                    }
                }
                Connections {
                    target: NiriService
                    enabled: CompositorService.isNiri
                    function onAllWorkspacesChanged() {
                        delegateRoot.updateAllData()
                        root.updateActiveHighlight()
                    }
                }
                Connections {
                    target: SettingsData
                    function onShowWorkspaceAppsChanged() {
                        delegateRoot.updateAllData()
                        root.updateActiveHighlight()
                    }
                    function onWorkspaceNameIconsChanged() {
                        delegateRoot.updateAllData()
                    }
                }
            }
        }
    }
    Connections {
        target: SettingsData
        function onCornerRadiusChanged() {
            root.updateActiveHighlight()
        }
        function onShowWorkspacePaddingChanged() {
            root.refreshWorkspaceSlots()
        }
        function onWorkspacesPerMonitorChanged() {
            root.refreshWorkspaceSlots()
        }
    }
    Connections {
        target: CompositorService
        function onIsHyprlandChanged() {
            root.refreshWorkspaceSlots()
        }
        function onIsNiriChanged() {
            root.refreshWorkspaceSlots()
        }
    }
    Connections {
        target: Hyprland
        enabled: CompositorService.isHyprland
        function onWorkspacesChanged() {
            root.refreshWorkspaceSlots()
        }
        function onMonitorsChanged() {
            root.refreshWorkspaceSlots()
        }
        function onFocusedWorkspaceChanged() {
            root.refreshWorkspaceSlots()
        }
    }
    Connections {
        target: NiriService
        enabled: CompositorService.isNiri
        function onAllWorkspacesChanged() {
            root.refreshWorkspaceSlots()
        }
    }
}
