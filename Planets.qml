import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// The bar face for `mode: "planets"`. The panel itself, and the open/close
// contract Bar.findPanelWidget probes for, live on the dispatcher: it is the
// item the bar slot loads, so it is the one the bar can see.
BarWidget {
  id: root

  // Set by the dispatcher, so the button can drive the panel it owns.
  property var host: null

  // U+1FA90 RINGED PLANET plus U+FE0E to force the Symbola outline instead of a colour emoji
  readonly property string icon: "🪐︎"

  readonly property bool opened: host ? host.opened === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "clairaut.atlas"

    function open(): void { if (root.host) root.host.open() }
    function close(): void { if (root.host) root.host.close() }
    function toggle(): void { if (root.host) root.host.togglePanel() }
    // Broadcasts over moduleName, which is now shared with the moon instance,
    // so a refresh reaches every atlas widget on the bar.
    function refresh(): void { if (root.host) root.host.broadcast("refresh") }
  }

  // A single glyph fits the fixed square slot, so BarIconButton is right here unlike the moon pill
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    slotSize: Style.bar.statusSlot
    tooltipText: root.opened ? "" : "Atlas: Ephemeris"
    onPressed: function (b) {
      if (!root.host) return
      if (b === Qt.MiddleButton) root.host.refresh()
      else root.host.togglePanel()
    }
  }
}
