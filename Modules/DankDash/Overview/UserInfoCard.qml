import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingL

        Item {
            id: avatarContainer
            
            property bool hasImage: profileImageLoader.status === Image.Ready
            
            width: 77
            height: 77
            anchors.verticalCenter: parent.verticalCenter
            
            Rectangle {
                anchors.fill: parent
                radius: 36
                color: Theme.primary
                visible: !avatarContainer.hasImage
                
                StyledText {
                    anchors.centerIn: parent
                    text: UserInfoService.username.length > 0 ? UserInfoService.username.charAt(0).toUpperCase() : "b"
                    font.pixelSize: Theme.fontSizeXLarge + 4
                    font.weight: Font.Bold
                    color: Theme.background
                }
            }
            
            Image {
                id: profileImageLoader
                
                source: {
                    if (PortalService.profileImage === "")
                        return ""
                    
                    if (PortalService.profileImage.startsWith("/"))
                        return "file://" + PortalService.profileImage
                    
                    return PortalService.profileImage
                }
                smooth: true
                asynchronous: true
                mipmap: true
                cache: true
                visible: false
            }
            
            MultiEffect {
                anchors.fill: parent
                anchors.margins: 2
                source: profileImageLoader
                maskEnabled: true
                maskSource: circularMask
                visible: avatarContainer.hasImage
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            
            Item {
                id: circularMask
                width: 77 - 4
                height: 77 - 4
                layer.enabled: true
                layer.smooth: true
                visible: false
                
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                    antialiasing: true
                }
            }
            
            DankIcon {
                anchors.centerIn: parent
                name: "person"
                size: Theme.iconSize + 8
                color: Theme.error
                visible: PortalService.profileImage !== "" && profileImageLoader.status === Image.Error
            }
        }

        Column {
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: UserInfoService.username || "brandon"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            
            Row {
                spacing: Theme.spacingS

                SystemLogo {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    colorOverride: Theme.primary
                }

                StyledText {
                    text: {
                        if (CompositorService.isNiri) return "on niri"
                        if (CompositorService.isHyprland) return "on Hyprland"
                        return ""
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            Row {
                spacing: Theme.spacingS

                DankIcon {
                    name: "schedule"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: UserInfoService.uptime || "up 1 hour, 23 minutes"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}