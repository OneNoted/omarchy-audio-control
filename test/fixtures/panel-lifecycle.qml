import QtQuick
import Quickshell

ShellRoot {
  id: root
  property var service: null
  property bool mixerOpen: false
  property var advanced: null
  property var advancedWindow: null
  property var dropdown: null
  property int phase: 0
  property int hostCloses: 0
  property bool failed: false

  function check(condition, message) {
    if (condition) return true
    failed = true
    console.log("PANEL_LIFECYCLE_FAILURE", message)
    Qt.callLater(Qt.quit)
    return false
  }
  function create(path, properties) {
    var component = Qt.createComponent(ROOT_URL + path)
    if (!check(component.status === Component.Ready, component.errorString())) return null
    var item = component.createObject(root, properties)
    check(!!item, "Could not create " + path)
    return item
  }
  function descendants(item) {
    var found = [], pending = [item]
    while (pending.length) {
      var next = pending.pop()
      if (!next || found.indexOf(next) !== -1) continue
      found.push(next)
      var children = next.data || next.children || []
      for (var i = 0; i < children.length; i++) pending.push(children[i])
      if (next.contentItem) pending.push(next.contentItem)
    }
    return found
  }
  QtObject {
    id: host
    property var bar: testBar
    function hide(id) { root.hostCloses++; root.advanced.close() }
  }
  QtObject {
    id: testBar
    function isBarWidgetOpen(id) { return root.mixerOpen }
    function summonBarWidget(id) {
      root.mixerOpen = true
      root.service.quickPanelOpened()
      return true
    }
    function hideBarWidget(id) { root.mixerOpen = false; return true }
  }
  Component.onCompleted: {
    // Exercise the shared service signal and the real advanced window/menu
    // without audio commands or a compositor for the mixer's layer surface.
    service = create("qml/core/Service.qml", { backendPreparationCommand: ["/bin/false"] })
    if (!service) return
    advanced = create("qml/panels/AdvancedAudio.qml", { service: service, shell: host })
    if (!advanced) return
    advancedWindow = descendants(advanced).find(function(item) {
      return item.title === "Notes Audio Control"
    })
    if (!check(!!advancedWindow, "Advanced window missing")) return
    advanced.activeTab = 1
    dropdown = descendants(advanced).find(function(item) {
      return item.popupOpen !== undefined && typeof item.toggle === "function"
        && item.options && item.options.some(function(option) { return option.value === "quality" })
    })
    if (!check(!!dropdown, "Advanced preference menu missing")) return
  }
  Timer {
    interval: 100; running: !root.failed; repeat: true
    onTriggered: {
      if (root.phase === 0) {
        root.advanced.openRequested = true
        root.advancedWindow.visible = true
        root.dropdown.enabled = true
        root.dropdown.toggle()
      } else if (root.phase === 1) {
        if (!root.check(root.advanced.opened && root.dropdown.popupOpen,
            "Advanced window and menu did not open")) return
        // A stale proxy flag must not close the mixer that is replacing it.
        root.advanced.quickPanelProxyOpen = true
        testBar.summonBarWidget("onenoted.audio-control")
      } else if (root.phase === 2) {
        if (!root.check(root.mixerOpen && !root.advanced.opened
            && !root.dropdown.popupOpen && root.advanced.profileMenuCount === 0
            && root.hostCloses === 0, "Opening the mixer left an advanced window or menu active")) return
        root.mixerOpen = false
        root.advancedWindow.visible = true
        root.advanced.open("{}")
      } else {
        if (!root.check(root.mixerOpen && !root.advanced.opened && root.hostCloses === 0,
            "The advanced quick-panel proxy hid the new mixer")) return
        console.log("PANEL_LIFECYCLE_SUCCESS")
        Qt.quit()
      }
      root.phase++
    }
  }
  Timer { interval: 5000; running: true; onTriggered: root.check(false, "Window lifecycle timed out") }
}
