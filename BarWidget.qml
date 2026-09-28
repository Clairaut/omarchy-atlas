import QtQuick
import qs.Ui

// One plugin, two bar faces, chosen per layout entry by `mode`. The bar loads
// this file for every entry, so everything the bar host looks for has to be
// here rather than in the file this loads:
//   - injectProps() (Bar.qml) writes bar/moduleName/settings into this item only
//   - implicitWidth/Height on the slot read from this item
//   - findPanelWidget() probes this item for open/close/opened
//   - activePopout is compared against this item, so Panel.hostWidget is root
BarWidget {
  id: root
  moduleName: "clairaut.atlas"

  readonly property string mode: setting("mode", "moon")
  readonly property var modes: ({ "moon": "Moon.qml", "planets": "Planets.qml" })

  // Both faces read one service: the polls live there, so every screen and every
  // entry shares a single atlas process. The host injects `bar` on a later tick
  // and creates services on its own schedule, so resolve on both and retry.
  property var service: null

  function resolveService() {
    var shellApi = root.bar ? root.bar.shell : null
    var next = (shellApi && typeof shellApi.serviceFor === "function")
      ? shellApi.serviceFor(root.moduleName) : null
    if (next === root.service) return
    if (root.service) root.service.detach()
    root.service = next
    if (root.service) root.service.attach()
  }

  onBarChanged: resolveService()
  Component.onCompleted: resolveService()
  Component.onDestruction: if (root.service) root.service.detach()

  Timer {
    interval: 500
    repeat: true
    running: root.service === null
    onTriggered: root.resolveService()
  }

  readonly property bool hasPanel: root.mode === "planets"
  readonly property var panelItem: panelLoader.item

  implicitWidth: view.item ? view.item.implicitWidth : 0
  implicitHeight: view.item ? view.item.implicitHeight : 0

  // findPanelWidget accepts any instance sharing this moduleName, so the moon
  // entry is a candidate for a hotkey it cannot service. Rather than fail
  // silently, hand the call to whichever peer actually owns the panel.
  function panelHost() {
    if (panelLoader.item) return root
    var peers = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : []
    for (var i = 0; i < peers.length; i++)
      if (peers[i] !== root && peers[i].hasPanel === true && peers[i].panelItem) return peers[i]
    return null
  }

  // Shape contract the bar needs on a panel host: open, close and opened.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    var h = panelHost()
    if (h && h.panelItem) h.panelItem.openFromHotkey()
  }

  function close() {
    var h = panelHost()
    if (h && h.panelItem) h.panelItem.close()
  }

  function togglePanel() {
    var h = panelHost()
    if (h && h.panelItem) h.panelItem.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // Planets reloads through its panel, moon through its own process.
  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
    else if (view.item && view.item.refresh) view.item.refresh()
  }

  Loader {
    id: view
    anchors.fill: parent
    source: Qt.resolvedUrl(root.modes[root.mode] || root.modes["moon"])
  }

  // injectProps() reaches this file only, and runs again on a later tick, so
  // bind these downward instead of assigning once in onLoaded.
  Binding { target: view.item; property: "bar";        value: root.bar;        when: view.item }
  Binding { target: view.item; property: "settings";   value: root.settings;   when: view.item }
  Binding { target: view.item; property: "moduleName"; value: root.moduleName; when: view.item }
  Binding { target: view.item; property: "host";       value: root;            when: view.item }
  Binding { target: view.item; property: "service";    value: root.service;    when: view.item }

  Loader {
    id: panelLoader
    active: root.hasPanel
    source: root.hasPanel ? Qt.resolvedUrl("Panel.qml") : ""
    visible: false
  }

  // anchorItem is this item rather than the button inside view: view fills root,
  // so the geometry is identical and the panel needs no reach into the mode file.
  Binding { target: panelLoader.item; property: "bar";        value: root.bar;      when: panelLoader.item }
  Binding { target: panelLoader.item; property: "settings";   value: root.settings; when: panelLoader.item }
  Binding { target: panelLoader.item; property: "anchorItem"; value: root;          when: panelLoader.item }
  Binding { target: panelLoader.item; property: "hostWidget"; value: root;          when: panelLoader.item }
  Binding { target: panelLoader.item; property: "service";    value: root.service;  when: panelLoader.item }
}
