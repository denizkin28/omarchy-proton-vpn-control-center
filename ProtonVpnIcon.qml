import QtQuick
import QtQuick.Effects
import qs.Commons

// Official Proton VPN mark from Proton's media kit.
// https://proton.me/media/kit

Item {
  id: root

  property real iconSize: Style.font.icon
  property color badgeColor: Color.urgent
  property color foreground: Color.foreground
  property bool connected: false
  property bool warning: false
  property bool busy: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Item {
    id: visual
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
    opacity: 1.0

    Image {
      anchors.fill: parent
      visible: root.connected
      source: Qt.resolvedUrl("assets/VPN-logomark-noborder.svg")
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }

    Image {
      id: disconnectedLogo
      anchors.fill: parent
      visible: false
      layer.enabled: !root.connected
      source: Qt.resolvedUrl("assets/proton-vpn-simple-white.svg")
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }

    MultiEffect {
      anchors.fill: disconnectedLogo
      source: disconnectedLogo
      visible: !root.connected
      colorization: 1.0
      colorizationColor: root.foreground
    }

    SequentialAnimation on opacity {
      running: root.busy
      loops: Animation.Infinite
      alwaysRunToEnd: false
      NumberAnimation { from: 1.0; to: 0.35; duration: 520; easing.type: Easing.InOutSine }
      NumberAnimation { from: 0.35; to: 1.0; duration: 520; easing.type: Easing.InOutSine }
    }
  }

  Rectangle {
    visible: root.busy
    anchors.centerIn: parent
    width: root.iconSize * 1.28
    height: width
    radius: width / 2
    color: "transparent"
    border.width: Math.max(1, root.iconSize * 0.08)
    border.color: Color.accent
    opacity: 0.75

    SequentialAnimation on scale {
      running: root.busy
      loops: Animation.Infinite
      NumberAnimation { from: 0.82; to: 1.08; duration: 520; easing.type: Easing.OutCubic }
      NumberAnimation { from: 1.08; to: 0.82; duration: 520; easing.type: Easing.InCubic }
    }
  }

  Rectangle {
    visible: root.warning
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: Math.max(4, root.iconSize * 0.24)
    height: width
    radius: width / 2
    color: root.badgeColor
    border.width: 1
    border.color: Color.background
  }
}
