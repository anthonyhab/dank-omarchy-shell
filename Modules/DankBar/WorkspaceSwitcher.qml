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
    property var workspaceList: {
        if (CompositorService.isNiri) {
            const baseList = getNiriWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isHyprland) {
            const baseList = getHyprlandWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        return [1]
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

    function getWorkspaceIcons(ws) {
        if (!SettingsData.showWorkspaceApps || !ws) {
            return []
        }

        let targetWorkspaceId
        if (CompositorService.isNiri) {
            const wsNumber = typeof ws === "number" ? ws : -1
            if (wsNumber <= 0) {
                return []
            }
            const workspace = NiriService.allWorkspaces.find(w => w.idx + 1 === wsNumber && w.output === root.screenName)
            if (!workspace) {
                return []
            }
            targetWorkspaceId = workspace.id
        } else if (CompositorService.isHyprland) {
            const normalized = normalizeWorkspaceId(ws.id !== undefined ? ws.id : ws, ws.name)
            if (normalized === null || normalized === undefined || normalized === -1) {
                return []
            }
            targetWorkspaceId = normalized
        } else {
            return []
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels

        const byApp = {}
        const isActiveWs = CompositorService.isNiri ? NiriService.allWorkspaces.some(ws => ws.id === targetWorkspaceId && ws.is_active) : targetWorkspaceId === root.currentWorkspace

        wins.forEach((w, i) => {
                         if (!w) {
                             return
                         }

                         let winWs = null
                         if (CompositorService.isNiri) {
                             winWs = w.workspace_id
                         } else {
                             const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || [])
                             const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w)
                             winWs = normalizeWorkspaceId(hyprToplevel?.workspace?.id, hyprToplevel?.workspace?.name)
                         }

                         if (winWs === undefined || winWs === null || winWs !== targetWorkspaceId) {
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
    property int maxWorkspaceIndex: Math.max(10, configuredPaddingMinimum())
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
        if (target === undefined || target === null) {
            return false
        }

        if (CompositorService.isHyprland) {
            return hyprlandWorkspaceMatches(entry, target)
        }

        if (entry === undefined || entry === null) {
            return false
        }

        const numericTarget = Number(target)
        const numericEntry = Number(entry)

        if (!isNaN(numericTarget) && !isNaN(numericEntry)) {
            return numericEntry === numericTarget
        }

        return entry === target
    }

    function workspaceSlotHeight() {
        return SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
    }

    function workspaceSlotWidth(entry) {
        if (!SettingsData.showWorkspaceApps) {
            return widgetHeight * 1.2
        }

        const iconTarget = CompositorService.isHyprland ? entry : (entry === -1 ? null : entry)
        const icons = root.getWorkspaceIcons(iconTarget) || []
        const numIcons = Math.min(icons.length, SettingsData.maxWorkspaceIcons)
        const iconsWidth = numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0)
        const baseWidth = widgetHeight * 1.0 + Theme.spacingXS
        return baseWidth + iconsWidth
    }

    function predictedGeometryForIndex(index) {
        const list = root.workspaceList || []
        if (index < 0 || index >= list.length) {
            return null
        }

        const rowTopLeft = workspaceRow.mapToItem(root, 0, 0)
        const spacing = workspaceRow.spacing || 0
        let x = rowTopLeft.x

        for (var i = 0; i < index; ++i) {
            const entry = list[i]
            const delegate = workspaceRepeater && workspaceRepeater.itemAt ? workspaceRepeater.itemAt(i) : null
            const width = delegate ? delegate.width : workspaceSlotWidth(entry)
            x += width + spacing
        }

        const entry = list[index]
        const delegate = workspaceRepeater && workspaceRepeater.itemAt ? workspaceRepeater.itemAt(index) : null
        const slotWidth = delegate ? delegate.width : workspaceSlotWidth(entry)
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

        const list = root.workspaceList || []
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
        // the model updates (onWorkspaceListChanged schedules another pass).
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
        return root.workspaceList.filter(ws => {
                                             if (CompositorService.isHyprland) {
                                                 return ws && ws.id !== -1
                                             }
                                             return ws !== -1
                                         })
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

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? (validIndex + 1) % realWorkspaces.length : (validIndex - 1 + realWorkspaces.length) % realWorkspaces.length

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1)
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
    onWorkspaceListChanged: updateActiveHighlight()
    onScreenNameChanged: updateActiveHighlight()
    Component.onCompleted: {
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
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
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
            model: root.workspaceList
            onItemAdded: root.scheduleHighlightUpdate()
            onItemRemoved: root.scheduleHighlightUpdate()

            Rectangle {
                id: delegateRoot

                property var workspaceEntry: modelData
                property bool isActive: CompositorService.isHyprland ? root.isHyprlandActiveWorkspace(modelData) : (modelData === root.currentWorkspace)
                property bool isPlaceholder: {
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === -1
                    }
                    return modelData === -1
                }
                property bool isHovered: mouseArea.containsMouse

                property var loadedWorkspaceData: null
                property var loadedIconData: null
                property bool loadedHasIcon: false
                property var loadedIcons: []

                Timer {
                    id: dataUpdateTimer
                    interval: 50 // Defer data calculation by 50ms
                    onTriggered: {
                        if (isPlaceholder) {
                            delegateRoot.loadedWorkspaceData = null
                            delegateRoot.loadedIconData = null
                            delegateRoot.loadedHasIcon = false
                            delegateRoot.loadedIcons = []
                            return
                        }

                        var wsData = null
                        if (CompositorService.isNiri) {
                            wsData = NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null
                        } else if (CompositorService.isHyprland) {
                            wsData = modelData
                        }
                        delegateRoot.loadedWorkspaceData = wsData

                        var icData = null
                        if (wsData?.name) {
                            icData = SettingsData.getWorkspaceNameIcon(wsData.name)
                        }
                        delegateRoot.loadedIconData = icData
                        delegateRoot.loadedHasIcon = icData !== null

                        if (SettingsData.showWorkspaceApps) {
                            delegateRoot.loadedIcons = root.getWorkspaceIcons(CompositorService.isHyprland ? modelData : (modelData === -1 ? null : modelData))
                        } else {
                            delegateRoot.loadedIcons = []
                        }

                        root.updateActiveHighlight()
                    }
                }

                function updateAllData() {
                    dataUpdateTimer.restart()
                }

                width: {
                    if (SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                        const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons)
                        const iconsWidth = numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0)
                        const baseWidth = root.widgetHeight * 1.0 + Theme.spacingXS
                        return baseWidth + iconsWidth
                    }
                    // Keep slot width stable to avoid row shifting.
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

                // No width animation for slots; stability > flourish here
                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (isPlaceholder) {
                            return
                        }

                        if (CompositorService.isNiri) {
                            NiriService.switchToWorkspace(modelData - 1)
                        } else if (CompositorService.isHyprland && modelData?.id !== undefined) {
                            const commandTarget = modelData.name && modelData.name.length > 0 ? modelData.name : modelData.id
                            const highlightTarget = root.getHyprlandWorkspaceIdentifier(modelData)
                            root.performHyprlandSwitch(commandTarget, false, highlightTarget)
                        }
                    }
                }

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

                // Loader for App Icons
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

                // Loader for Custom Name Icon
                Loader {
                    id: customIconLoader
                    anchors.fill: parent
                    active: !isPlaceholder && loadedHasIcon && loadedIconData.type === "icon" && !SettingsData.showWorkspaceApps
                    sourceComponent: Item {
                        DankIcon {
                            anchors.centerIn: parent
                            name: loadedIconData ? loadedIconData.value : "" // NULL CHECK
                            size: Theme.fontSizeSmall
                            color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                            weight: isActive && !isPlaceholder ? 500 : 400
                        }
                    }
                }

                // Loader for Custom Name Text
                Loader {
                    id: customTextLoader
                    anchors.fill: parent
                    active: !isPlaceholder && loadedHasIcon && loadedIconData.type === "text" && !SettingsData.showWorkspaceApps
                    sourceComponent: Item {
                        StyledText {
                            anchors.centerIn: parent
                            text: loadedIconData ? loadedIconData.value : "" // NULL CHECK
                            color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                // Loader for Workspace Index
                Loader {
                    id: indexLoader
                    anchors.fill: parent
                    active: SettingsData.showWorkspaceIndex && !SettingsData.showWorkspaceApps && (!loadedHasIcon || isPlaceholder)
                    sourceComponent: Item {
                        StyledText {
                            anchors.centerIn: parent
                            text: {
                                if (isPlaceholder) {
                                    if (CompositorService.isHyprland) {
                                        if (modelData?.displayIndex !== undefined && modelData.displayIndex !== null) {
                                            return modelData.displayIndex
                                        }
                                    }
                                    return index + 1
                                }

                                if (CompositorService.isHyprland) {
                                    const normalized = root.normalizeWorkspaceId(modelData?.id, modelData?.name)
                                    if (typeof normalized === "number" && !isNaN(normalized)) {
                                        return normalized
                                    }
                                    if (normalized !== undefined && normalized !== null && normalized !== -1 && normalized !== "") {
                                        return normalized
                                    }
                                    if (modelData?.displayIndex !== undefined && modelData.displayIndex !== null) {
                                        return modelData.displayIndex
                                    }
                                    if (modelData?.name) {
                                        return modelData.name
                                    }
                                    return ""
                                }

                                return modelData
                            }
                            color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                // --- LOGIC / TRIGGERS ---
                Component.onCompleted: {
                    updateAllData()
                    root.updateActiveHighlight()
                }
                Component.onDestruction: root.updateActiveHighlight()

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
    }
}
