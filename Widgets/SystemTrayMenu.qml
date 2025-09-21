import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Common
import qs.Widgets

PanelWindow {
    id: root

    property var menu: null
    property var anchorRect: Qt.rect(0, 0, 0, 0)
    property var parentWindow: null
    readonly property bool isVisible: menu !== null

    function show(systemTrayMenu, anchor, window) {
        menu = systemTrayMenu
        anchorRect = anchor
        parentWindow = window

        console.log("SystemTrayMenu: Menu properties:", Object.keys(systemTrayMenu || {}))
        if (systemTrayMenu) {
            console.log("SystemTrayMenu: Menu entries available:", systemTrayMenu.entries !== undefined)
            if (systemTrayMenu.entries) {
                console.log("SystemTrayMenu: Menu entries length:", systemTrayMenu.entries.length)
            }
        }

        if (parentWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                if (parentWindow.x >= s.x && parentWindow.x < s.x + s.width) {
                    root.screen = s
                    break
                }
            }
        }

        visible = true
    }

    function hide() {
        visible = false
        menu = null
    }

    screen: Quickshell.screens[0]
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Rectangle {
        id: menuContainer

        readonly property real maxMenuWidth: 300
        readonly property real menuItemHeight: 32
        readonly property int menuItemCount: menu && menu.entries ? menu.entries.length : 0

        width: Math.min(maxMenuWidth, Math.max(150, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(40, menuColumn.implicitHeight + Theme.spacingS * 2)

        x: {
            if (!root.parentWindow || !root.anchorRect) return 0

            const screenRelativeX = root.anchorRect.x
            const left = Theme.spacingS
            const right = root.width - width - Theme.spacingS
            const centerAlign = screenRelativeX + root.anchorRect.width / 2 - width / 2

            return Math.max(left, Math.min(right, centerAlign))
        }

        y: {
            if (!root.parentWindow || !root.anchorRect) return 0

            const topBarBottom = root.anchorRect.y + root.anchorRect.height + Theme.spacingS
            const screenBottom = root.height - height - Theme.spacingS

            return Math.min(topBarBottom, screenBottom)
        }

        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.85

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }

        Column {
            id: menuColumn

            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            spacing: 1

            Repeater {
                model: root.menu && root.menu.entries ? root.menu.entries : []

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool isCheckbox: modelData.checkboxState !== undefined
                    readonly property bool isChecked: modelData.checkboxState === SystemTrayMenuEntry.Checked
                    readonly property bool isRadio: modelData.radioState !== undefined
                    readonly property bool isSelected: modelData.radioState === SystemTrayMenuEntry.RadioSelected
                    readonly property bool isSeparator: modelData.isSeparator
                    readonly property bool isEnabled: modelData.enabled

                    width: parent.width
                    height: isSeparator ? 9 : 32
                    radius: isSeparator ? 0 : Theme.cornerRadius
                    color: (!isSeparator && isEnabled && itemArea.containsMouse) ?
                           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Rectangle {
                        visible: isSeparator
                        width: parent.width - Theme.spacingS * 2
                        height: 1
                        anchors.centerIn: parent
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    }

                    Row {
                        visible: !isSeparator
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankIcon {
                            visible: isCheckbox || isRadio
                            anchors.verticalCenter: parent.verticalCenter
                            name: {
                                if (isCheckbox) {
                                    return isChecked ? "check_box" : "check_box_outline_blank"
                                } else if (isRadio) {
                                    return isSelected ? "radio_button_checked" : "radio_button_unchecked"
                                }
                                return ""
                            }
                            color: isEnabled ? Theme.surfaceText : Theme.surfaceTextSecondary
                            size: Theme.fontSizeSmall
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: isEnabled ? Theme.surfaceText : Theme.surfaceTextSecondary
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            width: parent.width - (isCheckbox || isRadio ? Theme.fontSizeSmall + Theme.spacingXS : 0)
                        }
                    }

                    MouseArea {
                        id: itemArea

                        anchors.fill: parent
                        enabled: !isSeparator && isEnabled
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (modelData && modelData.activated) {
                                modelData.activated()
                            }
                            root.hide()
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.hide()
    }
}