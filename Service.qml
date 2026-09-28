import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Headless singleton: every atlas call the plugin makes, made once. The moon
// poll and the planets observe both lived in the widgets, so each screen (and
// each moon entry) ran its own copy of both.
Item {
  id: root

  // The host keeps a service loaded while the plugin is enabled, widget or no
  // widget, so poll only while something is actually reading. Widgets attach on
  // resolve and detach on destruction.
  property int consumers: 0

  function attach() { root.consumers++ }
  function detach() { if (root.consumers > 0) root.consumers-- }

  // ---------- the moon, for the bar face ----------
  property string signGlyph: ""
  property string orb: ""
  property real phaseAngle: -1
  property bool phaseWaxing: false

  readonly property real illum: phaseAngle < 0 ? -1 : Model.illuminated(phaseAngle)

  readonly property string atlasBin: Quickshell.env("HOME") + "/.local/bin/atlas"

  function refreshMoon() {
    if (!moonProc.running) moonProc.running = true
  }

  Process {
    id: moonProc
    command: [root.atlasBin, "observe", "moon", "-c", "-a", "zodiac", "-a", "phase"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var m = Model.parseMoon(text)
        if (!m) return
        root.signGlyph = m.signGlyph
        root.orb = m.orb
        root.phaseAngle = m.angle
        root.phaseWaxing = m.waxing
      }
    }
  }

  Timer {
    interval: 300000
    running: root.consumers > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshMoon()
  }

  // ---------- the full ephemeris, for the panel ----------
  // On demand rather than on a timer: nothing reads it until a panel opens.
  property var groups: []
  property var aspects: []
  property string stamp: ""
  property string coords: ""

  function refreshPlanets() {
    if (!observeProc.running) observeProc.running = true
  }

  // COLUMNS goes through sh because Rich truncates its table to 80 columns when stdout is not a tty.
  Process {
    id: observeProc
    command: ["sh", "-c", "COLUMNS=200 exec " + root.atlasBin + " observe " + Model.requestOrder().join(" ") + " -a zodiac -a aspects"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseObserve(text)
        if (parsed.bodies.length === 0) return
        root.groups = Model.groupedBodies(parsed.bodies)
        root.aspects = parsed.aspects
        root.stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
      }
    }
  }

  // Observer coordinates live in the atlas config, not in the observe output.
  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/atlas/atlas.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var body = text()
      var lat = body.match(/lat\s*=\s*(-?[\d.]+)/)
      var lon = body.match(/lon\s*=\s*(-?[\d.]+)/)
      if (!lat || !lon) return
      var la = parseFloat(lat[1])
      var lo = parseFloat(lon[1])
      root.coords = Math.abs(la).toFixed(4) + (la >= 0 ? "°N " : "°S ")
                  + Math.abs(lo).toFixed(4) + (lo >= 0 ? "°E" : "°W")
    }
  }
}
