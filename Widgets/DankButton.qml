import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string text: ""
    property string iconName: ""
    property bool enabled: true
    property bool outlined: false
    property bool destructive: false
    property int horizontalPadding: Theme.spacingL
    property int verticalPadding: Theme.spacingS
    property int minWidth: 96
    property int minHeight: 36

    readonly property color _accentColor: destructive ? Theme.error : Theme.primary
    readonly property color _contentOnAccent: Theme.primaryText

    signal clicked()
    signal pressed()
    signal released()

    implicitHeight: Math.max(minHeight, contentRow.implicitHeight + verticalPadding * 2)
    implicitWidth: Math.max(minWidth, contentRow.implicitWidth + horizontalPadding * 2)
    radius: Theme.cornerRadius
    color: outlined ? Theme.surfaceContainerHigh : _accentColor
    border.width: outlined ? 1 : 0
    border.color: outlined ? _accentColor : "transparent"
    opacity: enabled ? 1.0 : 0.5

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        DankIcon {
            id: icon
            visible: root.iconName !== ""
            name: root.iconName
            size: Theme.iconSizeSmall
            color: outlined ? _accentColor : _contentOnAccent
        }

        StyledText {
            id: label
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: outlined ? _accentColor : _contentOnAccent
            visible: text.length > 0
        }
    }

    StateLayer {
        id: stateLayer

        disabled: !root.enabled
        stateColor: outlined ? _accentColor : _contentOnAccent
        cornerRadius: root.radius
        onPressed: {
            if (!root.enabled)
                return
            root.pressed()
        }
        onReleased: {
            if (!root.enabled)
                return
            root.released()
        }
        onClicked: {
            if (!root.enabled)
                return
            root.clicked()
        }
    }
}
