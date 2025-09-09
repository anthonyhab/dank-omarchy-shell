import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash

DankPopout {
    id: root

    property bool calendarVisible: false
    property string triggerSection: "center"
    property var triggerScreen: null
    property int currentTabIndex: 0

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    popupWidth: 700
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 500
    triggerX: Screen.width - 620 - Theme.spacingL
    triggerY: Theme.barHeight - 4 + SettingsData.topBarSpacing + Theme.spacingS
    triggerWidth: 80
    positioning: "center"
    screen: triggerScreen
    shouldBeVisible: calendarVisible
    visible: shouldBeVisible

    onCalendarVisibleChanged: {
        if (calendarVisible) {
            open()
        } else {
            close()
        }
    }

    onBackgroundClicked: {
        calendarVisible = false
    }

    content: Component {
        Rectangle {
            id: mainContainer

            implicitHeight: contentColumn.height + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus()
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(function() {
                            mainContainer.forceActiveFocus()
                        })
                    }
                }
                target: root
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                radius: parent.radius

                SequentialAnimation on opacity {
                    running: root.shouldBeVisible
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.08
                        duration: Theme.extraLongDuration
                        easing.type: Theme.standardEasing
                    }

                    NumberAnimation {
                        to: 0.02
                        duration: Theme.extraLongDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                DankTabBar {
                    id: tabBar

                    width: parent.width
                    height: 48
                    currentIndex: root.currentTabIndex
                    spacing: Theme.spacingS
                    equalWidthTabs: true

                    model: {
                        let tabs = [
                            { icon: "dashboard", text: "Overview" },
                            { icon: "music_note", text: "Media" }
                        ]
                        
                        if (SettingsData.weatherEnabled) {
                            tabs.push({ icon: "wb_sunny", text: "Weather" })
                        }
                        
                        tabs.push({ icon: "settings", text: "Settings", isAction: true })
                        return tabs
                    }

                    onTabClicked: function(index) {
                        root.currentTabIndex = index
                    }

                    onActionTriggered: function(index) {
                        let settingsIndex = SettingsData.weatherEnabled ? 3 : 2
                        if (index === settingsIndex) {
                            root.close()
                            settingsModal.show()
                        }
                    }

                }

                Item {
                    width: parent.width
                    height: Theme.spacingXS
                }

                StackLayout {
                    id: pages
                    width: parent.width
                    implicitHeight: {
                        if (currentIndex === 0) return overviewTab.implicitHeight
                        if (currentIndex === 1) return mediaTab.implicitHeight
                        if (SettingsData.weatherEnabled && currentIndex === 2) return weatherTab.implicitHeight
                        return overviewTab.implicitHeight
                    }
                    currentIndex: root.currentTabIndex

                    OverviewTab {
                        id: overviewTab
                    }

                    MediaPlayerTab {
                        id: mediaTab
                    }

                    WeatherTab {
                        id: weatherTab
                        visible: SettingsData.weatherEnabled
                    }
                }
            }
        }
    }
}