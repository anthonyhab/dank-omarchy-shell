import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash.Overview

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 410

    Item {
        anchors.fill: parent
        // Weather - top left (narrower)
        WeatherOverviewCard {
            x: 0
            y: 0
            width: SettingsData.weatherEnabled ? parent.width * 0.3 : 0
            height: 100
            visible: SettingsData.weatherEnabled
        }

        // UserInfo - top middle (extend to system)
        UserInfoCard {
            x: SettingsData.weatherEnabled ? parent.width * 0.3 + Theme.spacingM : 0
            y: 0
            width: SettingsData.weatherEnabled ? parent.width * 0.45 : parent.width * 0.75 + Theme.spacingM
            height: 100
        }

        // Clock - top right (narrower and shorter)
        ClockCard {
            x: parent.width * 0.75 + Theme.spacingM * 2
            y: 0
            width: parent.width * 0.25 - Theme.spacingM * 2
            height: 180
        }

        // Calendar - bottom left (wider and taller)
        CalendarOverviewCard {
            x: 0
            y: 100 + Theme.spacingM
            width: parent.width * 0.55
            height: 300
        }

        // SystemMonitor - bottom middle (narrow and taller)
        SystemMonitorCard {
            x: parent.width * 0.55 + Theme.spacingM
            y: 100 + Theme.spacingM
            width: parent.width * 0.2
            height: 300
        }

        // Media - bottom right (match clock width)
        MediaOverviewCard {
            x: parent.width * 0.75 + Theme.spacingM * 2
            y: 180 + Theme.spacingM
            width: parent.width * 0.25 - Theme.spacingM * 2
            height: 220
        }
    }
}