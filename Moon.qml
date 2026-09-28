import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  // Set by the dispatcher; the host injects bar/settings/moduleName into it, not into this file.
  property var host: null

  // Bound by the dispatcher: the poll lives in the plugin's service, so one
  // instance serves every screen and every moon entry.
  property var service: null

  readonly property string signGlyph: service ? service.signGlyph : ""
  readonly property string orb: service ? service.orb : ""
  readonly property real phaseAngle: service ? service.phaseAngle : -1
  readonly property bool phaseWaxing: service ? service.phaseWaxing : false

  readonly property real illum: phaseAngle < 0 ? -1 : Model.illuminated(phaseAngle)

  function refresh() {
    if (root.service) root.service.refreshMoon()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Mixed content means driving width from the row, so the built in label is off and fixedWidth is set explicitly
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: contentRow.implicitWidth + Style.space(17) * 2
    tooltipText: root.illum < 0
      ? "Atlas: The Moon"
      : Model.phaseName(root.illum, root.phaseWaxing) + ", " + (root.illum * 100).toFixed(0) + "% lit"
    onPressed: root.refresh()

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      // The drawn dial stands in for the moon glyph, being a picture of the same thing
      Canvas {
        id: dial
        anchors.verticalCenter: parent.verticalCenter
        visible: root.illum >= 0
        width: Style.space(12)
        height: Style.space(12)

        property real k: root.illum
        property bool waxing: root.phaseWaxing
        property color lit: button.foreground
        property color dark: Color.bar.background

        onKChanged: requestPaint()
        onWaxingChanged: requestPaint()
        onLitChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d")
          var cx = width / 2
          var cy = height / 2
          var r = Math.min(cx, cy) - 0.5
          var frac = Math.max(0, Math.min(1, dial.k))

          ctx.reset()

          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * Math.PI)
          ctx.fillStyle = dial.dark
          ctx.fill()

          // Lit limb is a semicircle on the right when waxing, the left when waning
          var from = dial.waxing ? -Math.PI / 2 : Math.PI / 2
          var to = dial.waxing ? Math.PI / 2 : 3 * Math.PI / 2
          ctx.beginPath()
          ctx.arc(cx, cy, r, from, to, false)
          ctx.closePath()
          ctx.fillStyle = dial.lit
          ctx.fill()

          // Filled dark for a crescent and light for a gibbous, which covers the whole cycle
          var rx = r * Math.abs(1 - 2 * frac)
          if (rx > 0.05) {
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(rx / r, 1)
            ctx.beginPath()
            ctx.arc(0, 0, r, 0, 2 * Math.PI)
            ctx.closePath()
            ctx.fillStyle = frac < 0.5 ? dial.dark : dial.lit
            ctx.fill()
            ctx.restore()
          }

          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * Math.PI)
          ctx.strokeStyle = Util.alpha(dial.lit, 0.45)
          ctx.lineWidth = 1
          ctx.stroke()
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.signGlyph !== ""
        text: root.signGlyph
        font.family: button.fontFamily
        font.pixelSize: Style.font.bodySmall
        color: button.foreground
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.orb !== ""
        text: root.orb
        font.family: button.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.features: ({ "tnum": 1 })
        color: button.foreground
      }

      // Illumination is derived from the phase angle, so the two read together
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.illum >= 0
        text: (root.illum * 100).toFixed(0) + "%  " + root.phaseAngle.toFixed(2) + "°"
        font.family: button.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.features: ({ "tnum": 1 })
        color: Color.muted
      }
    }
  }
}
