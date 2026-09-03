import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "clairaut.atlas"
  ipcTarget: "clairaut.atlas"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var groups: []
  property var aspects: []
  property string stamp: ""
  property string coords: ""

  readonly property string atlasBin: Quickshell.env("HOME") + "/.local/bin/atlas"

  function refresh() {
    if (!observeProc.running) observeProc.running = true
  }

  function open() {
    root.controller.show()
    refresh()
  }

  function openFromHotkey() { open() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? close() : open() }

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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: 0

        // Header
        Item {
          width: parent.width
          height: headerCol.implicitHeight + Style.space(20)

          Column {
            id: headerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Text {
              text: root.stamp !== "" ? root.stamp : "reading ephemeris"
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.popups.text
            }

            Text {
              text: root.coords !== "" ? root.coords + "  ·  tropical" : "tropical"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.text, 0.14)
        }

        // Ephemeris on the left, aspects on the right
        Row {
          width: parent.width
          spacing: 0

          Column {
            id: bodiesCol
            width: parent.width - aspectsCol.width - 1
            spacing: 0
            bottomPadding: Style.space(10)

            Repeater {
              model: root.groups

              Column {
                required property var modelData
                width: bodiesCol.width
                spacing: 0

                Text {
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1.4
                  color: Color.muted
                  leftPadding: Style.space(14)
                  topPadding: Style.space(11)
                  bottomPadding: Style.space(4)
                }

                Repeater {
                  model: modelData.rows

                  Item {
                    required property var modelData
                    width: bodiesCol.width
                    height: Style.space(19)

                    Text {
                      id: bodyGlyph
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(14)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.glyph
                      font.family: Style.font.family
                      font.pixelSize: Style.font.subtitle
                      color: Color.popups.text
                    }

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(38)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      color: Color.muted
                    }

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(104)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.signGlyph
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      color: Color.popups.text
                    }

                    Text {
                      anchors.right: retroMark.left
                      anchors.rightMargin: Style.space(6)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.orb
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.features: ({ "tnum": 1 })
                      color: Color.popups.text
                    }

                    Text {
                      id: retroMark
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(12)
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(10)
                      text: modelData.retro ? "℞" : ""
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      color: Color.urgent
                    }
                  }
                }
              }
            }

          }

          Rectangle {
            width: 1
            height: bodiesCol.implicitHeight
            color: Util.alpha(Color.popups.text, 0.14)
          }

          Column {
            id: aspectsCol
            width: Style.space(178)
            spacing: 0
            bottomPadding: Style.space(10)

            Text {
              text: "ASPECTS"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1.4
              color: Color.muted
              leftPadding: Style.space(12)
              topPadding: Style.space(11)
              bottomPadding: Style.space(4)
            }

            Repeater {
              model: root.aspects

              Item {
                required property var modelData
                width: aspectsCol.width
                height: Style.space(19)

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.aGlyph + " " + modelData.bGlyph
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  color: Color.popups.text
                }

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(52)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.glyph
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  color: modelData.exact ? Color.popups.text : Color.muted
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.orbText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.features: ({ "tnum": 1 })
                  color: modelData.exact ? Color.popups.text : Color.muted
                }
              }
            }

            Text {
              visible: root.aspects.length === 0
              text: "none in orb"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
              leftPadding: Style.space(12)
              topPadding: Style.space(2)
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.text, 0.14)
        }

        // Footer
        Item {
          width: parent.width
          height: Style.space(28)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            text: root.bodyCount + " bodies  ·  " + root.aspects.length + " aspects"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.muted
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            text: "click to refresh"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.muted, 0.7)
          }
        }
      }
    }
  }

  readonly property int bodyCount: {
    var n = 0
    for (var i = 0; i < groups.length; i++) n += groups[i].rows.length
    return n
  }
}
