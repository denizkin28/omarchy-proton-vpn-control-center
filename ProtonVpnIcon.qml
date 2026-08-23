import QtQuick
import qs.Commons

// Official Proton VPN mark from Proton's media kit.
// https://proton.me/media/kit

Item {
  id: root

  property real iconSize: Style.font.icon
  property color badgeColor: Color.urgent
  property bool connected: false
  property bool warning: false
  property bool busy: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Image {
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
    source: Qt.resolvedUrl(root.connected
      ? "assets/VPN-logomark-noborder.svg"
      : "assets/proton-vpn-simple-white.svg")
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    opacity: root.busy ? 0.68 : 1.0
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
