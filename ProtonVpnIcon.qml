import QtQuick
import QtQuick.Shapes
import qs.Commons

// Proton VPN mark from Proton's media kit via Simple Icons.
// https://proton.me/media/kit
// https://simpleicons.org/?q=protonvpn

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color accentColor: Color.accent
  property color badgeColor: Color.urgent
  property bool connected: false
  property bool warning: false
  property bool busy: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    anchors.centerIn: parent
    width: 24
    height: 24
    scale: root.iconSize / 24
    opacity: root.connected ? 1.0 : 0.48
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    ShapePath {
      fillColor: root.color
      strokeWidth: 0
      PathSvg {
        path: "m10.176 20.058.858-1.28 6.513-9.838c.57-.86.026-2.014-1.005-2.131L.378 4.95l8.373 15.055a.84.84 0 0 0 1.424.052h.001zM23.586 7.14l-9.662 14.61c-1.036 1.567-3.38 1.478-4.293-.162l-.093-.168c.3-.01.594-.086.855-.235a1.85 1.85 0 0 0 .612-.57l.86-1.28 6.516-9.844c.46-.694.525-1.56.173-2.314a2.375 2.375 0 0 0-1.899-1.364L.493 3.956l-.476-.054C-.163 2.392 1.101.95 2.784 1.143l18.991 2.16c1.856.21 2.835 2.289 1.812 3.838z"
      }
    }
  }

  Rectangle {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: Math.max(4, root.iconSize * 0.3)
    height: width
    radius: width / 2
    color: root.warning ? root.badgeColor : (root.connected ? root.accentColor : root.color)
    opacity: root.busy ? 0.45 : 1.0
  }
}
