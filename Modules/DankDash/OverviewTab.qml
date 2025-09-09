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
        // Clock - top left (narrower and shorter)
        ClockCard {
            x: 0
            y: 0
            width: parent.width * 0.25 - Theme.spacingM * 2
            height: 180
        }

        // UserInfo - top middle (extend to weather)
        UserInfoCard {
            x: parent.width * 0.25 - Theme.spacingM
            y: 0
            width: SettingsData.weatherEnabled ? parent.width * 0.5 : parent.width * 0.75 + Theme.spacingM
            height: 100
        }

        // Weather - top right (narrower)
        WeatherOverviewCard {
            x: SettingsData.weatherEnabled ? parent.width * 0.75 : 0
            y: 0
            width: SettingsData.weatherEnabled ? parent.width * 0.25 : 0
            height: 100
            visible: SettingsData.weatherEnabled
        }

        // Media - middle left (match clock width)
        MediaOverviewCard {
            x: 0
            y: 180 + Theme.spacingM
            width: parent.width * 0.25 - Theme.spacingM * 2
            height: 220
        }

        // Calendar - bottom middle (wider and taller)
        CalendarOverviewCard {
            x: parent.width * 0.25 - Theme.spacingM
            y: 100 + Theme.spacingM
            width: parent.width * 0.55
            height: 300
        }

        // SystemMonitor - bottom right (narrow and taller)
        SystemMonitorCard {
            x: parent.width * 0.8
            y: 100 + Theme.spacingM
            width: parent.width * 0.2
            height: 300
        }
    }
}