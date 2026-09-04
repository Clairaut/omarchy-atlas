import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color backdrop: Color.bar.background

  readonly property real tilt: -20
  readonly property real ringRx: iconSize * 0.47
  readonly property real ringRy: iconSize * 0.148
  readonly property real discR: iconSize * 0.285
  readonly property real strokeW: Math.max(1, iconSize * 0.062)

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    id: shape
    anchors.fill: parent
    antialiasing: true
    // All curves in a tiny slot, so the curve renderer beats vertex AA — and it
    // needs no layer, which would soften the tilt into a rotated texture.
    preferredRendererType: Shape.CurveRenderer
    rotation: root.tilt

    readonly property real cx: width / 2
    readonly property real cy: height / 2

    // 0° is three o'clock sweeping clockwise, so 180° is the half tilted away.
    component Ansa: PathAngleArc {
      centerX: shape.cx
      centerY: shape.cy
      radiusX: root.ringRx
      radiusY: root.ringRy
      sweepAngle: 180
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.strokeW
      capStyle: ShapePath.RoundCap
      Ansa { startAngle: 180 }
    }

    ShapePath {
      fillColor: root.color
      strokeWidth: 0
      PathAngleArc {
        centerX: shape.cx
        centerY: shape.cy
        radiusX: root.discR
        radiusY: root.discR
        startAngle: 0
        sweepAngle: 360
      }
    }

    // Near half twice: a backdrop casing to clear a gap, then the ring inside it.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.backdrop
      strokeWidth: root.strokeW * 2.0
      capStyle: ShapePath.FlatCap
      Ansa { startAngle: 0 }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.strokeW
      capStyle: ShapePath.RoundCap
      Ansa { startAngle: 0 }
    }
  }
}
