import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Details
import qs.Modules.DankBar
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Models
import "./utils/state.js" as StateUtils

DankPopout {
    id: root

    property string expandedSection: ""
    property bool powerOptionsExpanded: false
    property string triggerSection: "right"
    property var triggerScreen: null
    property bool editMode: false
    property int expandedWidgetIndex: -1
    property var expandedWidgetData: null

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    function collapseAll() {
        expandedSection = ""
        expandedWidgetIndex = -1
        expandedWidgetData = null
    }

    onEditModeChanged: {
        if (editMode) {
            collapseAll()
        }
    }

    onVisibleChanged: {
        if (!visible) {
            collapseAll()
        }
    }

    readonly property color _containerBg: Theme.surfaceContainerHigh

    function setTriggerPosition(x, y, width, section, screen) {
        StateUtils.setTriggerPosition(root, x, y, width, section, screen)
    }

    function openWithSection(section) {
        StateUtils.openWithSection(root, section)
    }

    function toggleSection(section) {
        StateUtils.toggleSection(root, section)
    }

    popupWidth: 550
    popupHeight: Math.min((triggerScreen?.height ?? 1080) - 100, contentLoader.item && contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight + 20 : 400)
    triggerX: (triggerScreen?.width ?? 1920) - 600 - Theme.spacingL
    triggerY: Theme.barHeight - 4 + SettingsData.dankBarSpacing + Theme.popupDistance
    triggerWidth: 80
    positioning: "center"
    screen: triggerScreen
    shouldBeVisible: false
    visible: shouldBeVisible

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            Qt.callLater(() => {
                NetworkService.autoRefreshEnabled = NetworkService.wifiEnabled
                if (UserInfoService)
                    UserInfoService.getUptime()
            })
        } else {
            Qt.callLater(() => {
                NetworkService.autoRefreshEnabled = false
                if (BluetoothService.adapter && BluetoothService.adapter.discovering)
                    BluetoothService.adapter.discovering = false
                editMode = false
            })
        }
    }

    WidgetModel {
        id: widgetModel
    }

    content: Component {
        Rectangle {
            id: controlContent

            implicitHeight: mainColumn.implicitHeight + Theme.spacingM
            property alias bluetoothCodecSelector: bluetoothCodecSelector

            color: {
                const transparency = Theme.popupTransparency || 0.92
                const surface = Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1)
                return Qt.rgba(surface.r, surface.g, surface.b, transparency)
            }
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                  Theme.outline.b, 0.08)
            border.width: 0
            antialiasing: true
            smooth: true

            Column {
                id: mainColumn
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingS

                HeaderPane {
                    id: headerPane
                    width: parent.width
                    powerOptionsExpanded: root.powerOptionsExpanded
                    editMode: root.editMode
                    onPowerOptionsExpandedChanged: root.powerOptionsExpanded = powerOptionsExpanded
                    onEditModeToggled: root.editMode = !root.editMode
                    onPowerActionRequested: (action, title, message) => root.powerActionRequested(action, title, message)
                    onLockRequested: {
                        root.close()
                        root.lockRequested()
                    }
                }

                PowerOptionsPane {
                    id: powerOptionsPane
                    width: parent.width
                    expanded: root.powerOptionsExpanded
                    onPowerActionRequested: (action, title, message) => {
                        root.powerOptionsExpanded = false
                        root.close()
                        root.powerActionRequested(action, title, message)
                    }
                }

                DragDropGrid {
                    id: widgetGrid
                    width: parent.width
                    editMode: root.editMode
                    expandedSection: root.expandedSection
                    expandedWidgetIndex: root.expandedWidgetIndex
                    expandedWidgetData: root.expandedWidgetData
                    model: widgetModel
                    bluetoothCodecSelector: bluetoothCodecSelector
                    onExpandClicked: (widgetData, globalIndex) => {
                        root.expandedWidgetIndex = globalIndex
                        root.expandedWidgetData = widgetData
                        if (widgetData.id === "diskUsage") {
                            root.toggleSection("diskUsage_" + (widgetData.instanceId || "default"))
                        } else {
                            root.toggleSection(widgetData.id)
                        }
                    }
                    onRemoveWidget: (index) => widgetModel.removeWidget(index)
                    onMoveWidget: (fromIndex, toIndex) => widgetModel.moveWidget(fromIndex, toIndex)
                    onToggleWidgetSize: (index) => widgetModel.toggleWidgetSize(index)
                }

                EditControls {
                    width: parent.width
<<<<<<< HEAD
                    height: audioSliderRow.implicitHeight
                    
                    Row {
                        id: audioSliderRow
                        x: -Theme.spacingS
                        width: parent.width + Theme.spacingS * 2
                        spacing: Theme.spacingM

                        AudioSliderRow {
                            width: SettingsData.hideBrightnessSlider ? parent.width - Theme.spacingS : (parent.width - Theme.spacingM) / 2
                            property color sliderTrackColor: root._containerBg
                        }

                        Item {
                            width: (parent.width - Theme.spacingM) / 2
                            height: parent.height
                            visible: !SettingsData.hideBrightnessSlider
                            
                            BrightnessSliderRow {
                                width: parent.width
                                height: parent.height
                                x: -Theme.spacingS
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    NetworkPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "network"
                        onExpandClicked: root.toggleSection("network")
                    }

                    BluetoothPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "bluetooth"
                        onExpandClicked: {
                            if (!BluetoothService.available) return
                            root.toggleSection("bluetooth")
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: root.expandedSection === "network" || root.expandedSection === "bluetooth"
                    visible: active
                    sourceComponent: DetailView {
                        width: parent.width
                        isVisible: true
                        title: {
                            switch (root.expandedSection) {
                            case "network": return "Network Settings"
                            case "bluetooth": return "Bluetooth Settings"
                            default: return ""
                            }
                        }
                        content: {
                            switch (root.expandedSection) {
                            case "network": return networkDetailComponent
                            case "bluetooth": return bluetoothDetailComponent
                            default: return null
                            }
                        }
                        contentHeight: 250
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    AudioOutputPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "audio_output"
                        onExpandClicked: root.toggleSection("audio_output")
                    }

                    AudioInputPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "audio_input"
                        onExpandClicked: root.toggleSection("audio_input")
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SettingsData.homeAssistantEnabled

                    HomeAssistantPill {
                        width: parent.width
                        expanded: root.expandedSection === "homeassistant"
                        onExpandClicked: root.toggleSection("homeassistant")
                        onDetailViewRequested: root.toggleSection("homeassistant")
                    }
                }

                Loader {
                    width: parent.width
                    active: root.expandedSection === "audio_output" || root.expandedSection === "audio_input" || root.expandedSection === "homeassistant"
                    visible: active
                    sourceComponent: DetailView {
                        width: parent.width
                        isVisible: true
                        title: {
                            switch (root.expandedSection) {
                            case "audio_output": return "Audio Output"
                            case "audio_input": return "Audio Input"
                            case "homeassistant": return "HomeAssistant"
                            default: return ""
                            }
                        }
                        content: {
                            switch (root.expandedSection) {
                            case "audio_output": return audioOutputDetailComponent
                            case "audio_input": return audioInputDetailComponent
                            case "homeassistant": return homeAssistantDetailComponent
                            default: return null
                            }
                        }
                        contentHeight: {
                            switch (root.expandedSection) {
                            case "homeassistant": return -1  // Use implicit height
                            default: return 250
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    ToggleButton {
                        width: (parent.width - Theme.spacingM) / 2
                        iconName: DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                        text: "Night Mode"
                        secondaryText: SessionData.nightModeAutoEnabled ? "Auto" : (DisplayService.nightModeEnabled ? "On" : "Off")
                        isActive: DisplayService.nightModeEnabled
                        enabled: DisplayService.automationAvailable
                        onClicked: DisplayService.toggleNightMode()

                        DankIcon {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            name: "schedule"
                            size: 12
                            color: Theme.primary
                            visible: SessionData.nightModeAutoEnabled
                            opacity: 0.8
                        }
                    }

                    ToggleButton {
                        width: (parent.width - Theme.spacingM) / 2
                        iconName: SessionData.isLightMode ? "light_mode" : "palette"
                        text: "Theme"
                        secondaryText: SessionData.isLightMode ? "Light" : "Dark"
                        isActive: true
                        onClicked: Theme.toggleLightMode()
=======
                    visible: editMode
                    availableWidgets: {
                        const existingIds = (SettingsData.controlCenterWidgets || []).map(w => w.id)
                        return widgetModel.baseWidgetDefinitions.filter(w => w.allowMultiple || !existingIds.includes(w.id))
>>>>>>> upstream/master
                    }
                    onAddWidget: (widgetId) => widgetModel.addWidget(widgetId)
                    onResetToDefault: () => widgetModel.resetToDefault()
                    onClearAll: () => widgetModel.clearAll()
                }
            }

            BluetoothCodecSelector {
                id: bluetoothCodecSelector
                anchors.fill: parent
                z: 10000
            }
        }
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {
            id: bluetoothDetail
            onShowCodecSelector: function(device) {
                if (contentLoader.item && contentLoader.item.bluetoothCodecSelector) {
                    contentLoader.item.bluetoothCodecSelector.show(device)
                    contentLoader.item.bluetoothCodecSelector.codecSelected.connect(function(deviceAddress, codecName) {
                        bluetoothDetail.updateDeviceCodecDisplay(deviceAddress, codecName)
                    })
                }
            }
        }
    }

    Component {
        id: audioOutputDetailComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputDetailComponent
        AudioInputDetail {}
    }

    Component {
<<<<<<< HEAD
        id: homeAssistantDetailComponent
        HomeAssistantDetailView {}
    }
}
=======
        id: batteryDetailComponent
        BatteryDetail {}
    }
}
>>>>>>> upstream/master
