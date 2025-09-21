import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var parentWindow: null
    property var parentScreen: null
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS
    readonly property int calculatedWidth: SystemTray.items.values.length > 0 ? SystemTray.items.values.length * 24 + horizontalPadding * 2 : 0

    width: calculatedWidth
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SystemTray.items.values.length === 0) {
            return "transparent";
        }

        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: SystemTray.items.values.length > 0

    Row {
        id: systemTrayRow

        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: SystemTray.items.values

            delegate: Item {
                property var trayItem: modelData
                property string appId: trayItem?.id || ""
                property string rawIcon: trayItem?.icon || ""

                property string iconSource: {
                    let icon = trayItem && trayItem.icon;
                    if (typeof icon === 'string' || icon instanceof String) {
                        if (icon.includes("?path=")) {
                            const split = icon.split("?path=");
                            if (split.length !== 2) {
                                return icon;
                            }

                            const name = split[0];
                            const path = split[1];
                            const fileName = name.substring(name.lastIndexOf("/") + 1);
                            return `file://${path}/${fileName}`;
                        }

                        if (icon === "image://icon/input-keyboard-symbolic" && appId === "Fcitx") {
                            return "file:///usr/share/icons/Adwaita/symbolic/devices/input-keyboard-symbolic.svg";
                        }

                        return icon;
                    }
                    return "";
                }

                Component.onCompleted: {
                    console.log("SystemTray item:", JSON.stringify({
                        id: appId,
                        rawIcon: rawIcon,
                        resolvedIcon: iconSource,
                        title: trayItem?.title || ""
                    }))
                }

                width: 24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"


                }

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: parent.iconSource
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    id: trayItemArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (!trayItem) {
                            return;
                        }

                        if (mouse.button === Qt.LeftButton && !trayItem.onlyMenu) {
                            trayItem.activate();
                            return ;
                        }
                        if (trayItem.hasMenu) {
                            const globalPos = mapToGlobal(0, 0);
                            const currentScreen = parentScreen || Screen;
                            const screenX = currentScreen.x || 0;
                            const relativeX = globalPos.x - screenX;
                            menuAnchor.menu = trayItem.menu;
                            menuAnchor.anchor.window = parentWindow;
                            menuAnchor.anchor.rect = Qt.rect(relativeX, parentWindow.effectiveBarHeight + SettingsData.topBarSpacing, parent.width, 1);
                            menuAnchor.open();
                        }
                    }
                }

            }

        }

    }

    QsMenuAnchor {
        id: menuAnchor

        property string menuStyle: "
            QMenu {
                background-color: " + Theme.popupBackground() + ";
                border: 1px solid rgba(" + Math.round(Theme.outline.r * 255) + ", " + Math.round(Theme.outline.g * 255) + ", " + Math.round(Theme.outline.b * 255) + ", 0.2);
                border-radius: " + Theme.cornerRadius + "px;
                padding: " + Theme.spacingS + "px;
                margin: 0px;
                font-family: '" + Theme.fontFamily + "';
                font-size: " + Theme.fontSizeSmall + "px;
                color: " + Theme.surfaceText + ";
                selection-background-color: rgba(" + Math.round(Theme.primary.r * 255) + ", " + Math.round(Theme.primary.g * 255) + ", " + Math.round(Theme.primary.b * 255) + ", 0.15);
                selection-color: " + Theme.surfaceText + ";
            }
            QMenu::item {
                background-color: transparent;
                padding: 8px " + Theme.spacingM + "px;
                margin: 1px " + Theme.spacingXS + "px;
                border-radius: " + (Theme.cornerRadius - 2) + "px;
                color: " + Theme.surfaceText + ";
                min-height: 20px;
                font-weight: 400;
                transition: all 150ms ease;
            }
            QMenu::item:selected {
                background-color: rgba(" + Math.round(Theme.primary.r * 255) + ", " + Math.round(Theme.primary.g * 255) + ", " + Math.round(Theme.primary.b * 255) + ", 0.12);
                color: " + Theme.surfaceText + ";
            }
            QMenu::item:pressed {
                background-color: rgba(" + Math.round(Theme.primary.r * 255) + ", " + Math.round(Theme.primary.g * 255) + ", " + Math.round(Theme.primary.b * 255) + ", 0.18);
            }
            QMenu::item:disabled {
                color: " + Theme.surfaceTextSecondary + ";
                background-color: transparent;
            }
            QMenu::item:disabled:selected {
                background-color: rgba(" + Math.round(Theme.outline.r * 255) + ", " + Math.round(Theme.outline.g * 255) + ", " + Math.round(Theme.outline.b * 255) + ", 0.05);
            }
            QMenu::separator {
                height: 1px;
                background-color: rgba(" + Math.round(Theme.outline.r * 255) + ", " + Math.round(Theme.outline.g * 255) + ", " + Math.round(Theme.outline.b * 255) + ", 0.2);
                margin: " + Theme.spacingXS + "px " + Theme.spacingS + "px;
            }
            QMenu::indicator {
                width: 16px;
                height: 16px;
                margin-right: " + Theme.spacingXS + "px;
            }
            QMenu::indicator:checked {
                image: url(data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTYiIGhlaWdodD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTYuNSAxMUwzIDcuNUw0LjQxIDYuMDlMNi41IDguMTdMMTEuNTkgMy4wOUwxMyA0LjVMNi41IDExWiIgZmlsbD0iIiArIFRoZW1lLnByaW1hcnkgKyAiIi8+Cjwvc3ZnPgo=);
            }
            QMenu::indicator:unchecked {
                image: none;
                border: 1px solid rgba(" + Math.round(Theme.outline.r * 255) + ", " + Math.round(Theme.outline.g * 255) + ", " + Math.round(Theme.outline.b * 255) + ", 0.4);
                border-radius: 2px;
            }
        "

        Component.onCompleted: {
            if (menuStyle && typeof setStyleSheet === 'function') {
                setStyleSheet(menuStyle)
            }
        }
    }

}
