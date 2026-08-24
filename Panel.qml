import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "." as ProtonPlugin

Panel {
  id: root
  moduleName: "denizkin.protonvpn"
  ipcTarget: "denizkin.protonvpn"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var favorites: settings && settings.favorites instanceof Array ? settings.favorites : []
  readonly property var profiles: settings && settings.profiles instanceof Array ? settings.profiles : []
  readonly property var serverHistory: settings && settings.serverHistory instanceof Array ? settings.serverHistory : []
  readonly property var vpn: ProtonPlugin.VpnService
  property bool settingsExpanded: false
  property bool exitIpVisible: false
  property bool exitIpCopied: false
  property bool confirmOpen: false
  property string confirmKind: ""
  property int confirmIndex: -1
  property string confirmLabel: ""

  function requestConfirmation(kind, index, label) {
    confirmKind = kind
    confirmIndex = index === undefined ? -1 : Number(index)
    confirmLabel = String(label || "")
    confirmOpen = true
  }

  function cancelConfirmation() {
    confirmOpen = false
    confirmKind = ""
    confirmIndex = -1
    confirmLabel = ""
  }

  function confirmPendingAction() {
    var kind = confirmKind
    var index = confirmIndex
    cancelConfirmation()
    if (kind === "favorite") removeFavorite(index)
    else if (kind === "profile") removeProfile(index)
    else if (kind === "history") persistPluginSetting("serverHistory", [])
    else if (kind === "logout") vpn.signOut()
    else if (kind === "disconnect") vpn.disconnect()
  }

  function confirmationMessage() {
    if (confirmKind === "favorite") return "Remove favorite “" + confirmLabel + "”?"
    if (confirmKind === "profile") return "Delete profile “" + confirmLabel + "”?"
    if (confirmKind === "history") return "Clear all recent Proton VPN servers?"
    if (confirmKind === "logout") return "Sign out of Proton VPN on this computer?"
    if (confirmKind === "disconnect") return "Disconnect Proton VPN and return traffic to the regular network?"
    return "Continue?"
  }

  function selectedCountryCode() {
    return String(countryBox.value || "")
  }

  function selectedCityName() {
    return String(cityBox.value || "")
  }

  function selectedCityFeatures() {
    var options = root.filteredCities()
    for (var i = 0; i < options.length; i++)
      if (String(options[i].name || "") === cityBox.value) return String(options[i].features || "")
    return ""
  }

  function filteredCountries() {
    var query = String(countrySearch.text || "").trim().toLowerCase()
    if (query === "") return vpn.countries
    var result = []
    for (var i = 0; i < vpn.countries.length; i++) {
      var country = vpn.countries[i]
      var searchable = (String(country.name || "") + " " + String(country.code || "")).toLowerCase()
      if (searchable.indexOf(query) !== -1) result.push(country)
    }
    return result
  }

  function filteredCities() {
    var query = String(citySearch.text || "").trim().toLowerCase()
    if (query === "") return vpn.cities
    var result = []
    for (var i = 0; i < vpn.cities.length; i++) {
      var city = vpn.cities[i]
      var searchable = (String(city.name || "") + " " + String(city.features || "")).toLowerCase()
      if (searchable.indexOf(query) !== -1) result.push(city)
    }
    return result
  }

  function selectFirstFilteredCity() {
    var options = filteredCities()
    cityBox.value = options.length > 0 ? String(options[0].name || "") : ""
  }

  function selectDefaultCountry() {
    if (vpn.countries.length === 0) return
    var preferred = String((root.settings && root.settings.defaultCountryCode) || "AE").toUpperCase()
    var selected = String(vpn.countries[0].code || "")
    for (var i = 0; i < vpn.countries.length; i++) {
      if (String(vpn.countries[i].code) === preferred) {
        selected = preferred
        break
      }
    }
    countryBox.value = selected
    if (modeBox.value === "City") vpn.loadCities(root.selectedCountryCode())
  }

  function submitConnection() {
    var target = ""
    if (modeBox.value === "Country") target = selectedCountryCode()
    else if (modeBox.value === "City") target = selectedCityName()
    else if (modeBox.value === "Server") target = serverField.text
    if (vpn.connect(modeBox.value, target, featureBox.value)) serverField.focus = false
  }

  function showServerConnect() {
    modeBox.value = "Server"
    Qt.callLater(function() {
      root.scheduleServerRefresh()
      serverSearch.forceActiveFocus()
      serverSearch.selectAll()
    })
  }

  function scheduleServerRefresh() {
    if (modeBox.value !== "Server") return
    serverSearchDebounce.restart()
  }

  function refreshServerBrowser() {
    vpn.refreshServers(serverSearch.text, serverFeatureBox.value, serverLoadBox.value, availableServersOnly.checked,
      serverCountryBox.value, serverRegionBox.value)
  }

  function serverSelectionOptions() {
    return vpn.serverResults.map(function(server) {
      var place = String(server.region || server.city || server.exitCountry || "")
      var route = server.entryCountry !== server.exitCountry ? " via " + String(server.entryCountry || "") : ""
      var features = server.features && server.features.length > 0 ? " · " + server.features.join(", ") : ""
      return {
        value: String(server.id || ""),
        label: String(server.id || "") + " · " + Number(server.load || 0) + "% · " + String(server.exitCountry || ""),
        description: place + route + features + " · " + String(server.tierName || "")
      }
    })
  }

  function selectedCountryName() {
    var options = root.filteredCountries()
    for (var i = 0; i < options.length; i++)
      if (String(options[i].code || "") === countryBox.value) return String(options[i].name || "")
    return ""
  }

  function currentFavorite() {
    var mode = modeBox.value
    var target = ""
    var label = mode + " server"
    if (mode === "Country") {
      target = selectedCountryCode()
      label = selectedCountryName()
    } else if (mode === "City") {
      target = selectedCityName()
      label = target + (selectedCountryName() !== "" ? ", " + selectedCountryName() : "")
    } else if (mode === "Server") {
      target = String(serverField.text || "").trim()
      label = target
    } else if (mode === "Random") {
      label = "Random server"
    } else {
      label = "Fastest server"
    }
    return { mode: mode, target: target, feature: featureBox.value, label: label }
  }

  function currentFavoriteIndex() {
    return Model.favoriteIndex(favorites, currentFavorite())
  }

  function persistPluginSetting(name, value) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var entry = { id: root.moduleName }
    for (var key in settings) if (key !== "id" && key !== name) entry[key] = settings[key]
    entry[name] = value
    root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function migratePluginSettings() {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var migration = Model.migrateSettings(root.settings || {})
    if (!migration.changed) return
    var entry = migration.settings
    entry.id = root.moduleName
    root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  Component.onCompleted: {
    vpn.acquire(root.settings)
    Qt.callLater(root.migratePluginSettings)
  }
  Component.onDestruction: vpn.release()
  onSettingsChanged: vpn.settings = root.settings || ({})

  function persistFavorites(next) {
    persistPluginSetting("favorites", next)
  }

  function configValue(settingName) {
    var value = vpn.configValues ? vpn.configValues[settingName] : undefined
    return value === undefined || value === null ? "" : String(value)
  }

  function configLocked(settingName) {
    return /upgrade to enable/i.test(configValue(settingName))
  }

  function syncConfigControls() {
    netshieldBox.value = configValue("netshield")
  }

  function toggleSettings() {
    settingsExpanded = !settingsExpanded
    if (settingsExpanded) {
      vpn.refreshConfig()
      vpn.refreshPortForward()
      vpn.refreshSplitTunneling()
      vpn.refreshNetwork()
      vpn.refreshApplications()
      vpn.refreshCoreSettings()
    }
  }

  function applyCustomDns() {
    var servers = String(customDnsField.text || "").trim()
    if (servers === "") {
      vpn.configError = "Enter at least one DNS server"
      vpn.lastError = vpn.configError
      customDnsField.forceActiveFocus()
      return
    }
    persistPluginSetting("customDnsServers", servers)
    vpn.setConfig("custom-dns", "on", servers)
  }

  function toggleCustomDns() {
    if (configValue("custom-dns") === "on") {
      vpn.setConfig("custom-dns", "off", "")
    } else {
      applyCustomDns()
    }
  }

  function toggleCurrentFavorite() {
    var favorite = currentFavorite()
    if ((favorite.mode === "Country" || favorite.mode === "City" || favorite.mode === "Server") && favorite.target === "") {
      vpn.lastError = "Choose a location before adding a favorite"
      return
    }
    var existing = Model.favoriteIndex(favorites, favorite)
    persistFavorites(existing >= 0 ? Model.removeFavorite(favorites, existing) : Model.addFavorite(favorites, favorite, 12))
  }

  function removeFavorite(index) {
    persistFavorites(Model.removeFavorite(favorites, index))
  }

  function connectFavorite(favorite) {
    if (!favorite) return
    vpn.connect(String(favorite.mode || "Fastest"), String(favorite.target || ""), String(favorite.feature || "None"))
  }

  function copyExitIp() {
    if (ipCopyProcess.running) return
    var plan = Model.copyIpPlan("wl-copy", vpn.exitIp)
    if (!plan.ok) {
      vpn.reportError = plan.error
      return
    }
    exitIpCopied = false
    ipCopyProcess.command = plan.command
    ipCopyProcess.running = true
  }

  function favoriteDescription(favorite) {
    if (!favorite) return ""
    var mode = String(favorite.mode || "")
    var feature = String(favorite.feature || "None")
    return feature === "None" ? mode : mode + " · " + feature
  }

  function saveCurrentProfile() {
    var name = String(profileNameField.text || "").trim()
    if (name === "") { vpn.profileError = "Enter a profile name"; return }
    var favorite = currentFavorite()
    var values = {}
    for (var key in vpn.configValues) values[key] = String(vpn.configValues[key])
    var profile = { name: name, mode: favorite.mode, target: favorite.target,
      feature: favorite.feature, settings: values,
      customDns: String((root.settings && root.settings.customDnsServers) || "") }
    var next = [profile]
    for (var i = 0; i < profiles.length && next.length < 12; i++)
      if (String(profiles[i].name || "") !== name) next.push(profiles[i])
    persistPluginSetting("profiles", next)
    profileNameField.text = ""
    vpn.profileError = ""
  }

  function removeProfile(index) {
    var next = []
    for (var i = 0; i < profiles.length; i++) if (i !== index) next.push(profiles[i])
    persistPluginSetting("profiles", next)
  }

  function recordConnectedServer() {
    if (!root.isAutomaticSettingsWriter()) return
    if (!vpn.connected || vpn.server === "") return
    if (serverHistory.length > 0 && String(serverHistory[0].server || "") === vpn.server) return
    var record = { server: vpn.server, location: vpn.location, load: vpn.load, protocol: vpn.protocol }
    var next = [record]
    for (var i = 0; i < serverHistory.length && next.length < 20; i++)
      if (String(serverHistory[i].server || "") !== vpn.server) next.push(serverHistory[i])
    persistPluginSetting("serverHistory", next)
  }

  function isAutomaticSettingsWriter() {
    if (!root.bar || typeof root.bar.moduleWidgets !== "function") return true
    var widgets = root.bar.moduleWidgets(root.moduleName)
    return widgets.length === 0 || widgets[0] === root
  }

  function toggleCurrentNetworkTrusted() {
    var name = String(vpn.activeNetwork.connection || "")
    if (name === "") return
    var values = root.settings && root.settings.trustedNetworks instanceof Array ? root.settings.trustedNetworks : []
    var next = [], found = false
    for (var i = 0; i < values.length; i++) {
      if (String(values[i]) === name) found = true
      else next.push(values[i])
    }
    if (!found) next.unshift(name)
    persistPluginSetting("trustedNetworks", next)
  }

  function currentNetworkTrusted() { return vpn.networkIsTrusted(vpn.activeNetwork.connection) }
  function splitList(text) {
    return String(text || "").split(/[\n,]+/).map(function(value) { return value.trim() }).filter(function(value) { return value !== "" })
  }

  function splitApplicationOptions() {
    var result = []
    for (var i = 0; i < vpn.installedApplications.length; i++) {
      var app = vpn.installedApplications[i]
      if (!splitApplicationSelected(String(app.executable || ""))) result.push({
        value: String(app.executable || ""), label: String(app.name || "Application"),
        description: String(app.executable || "")
      })
    }
    return result
  }

  function selectedSplitApplications() {
    var selected = splitList(splitAppsField.text), result = []
    for (var i = 0; i < selected.length; i++) {
      var executable = selected[i], application = null
      for (var j = 0; j < vpn.installedApplications.length; j++)
        if (String(vpn.installedApplications[j].executable || "") === executable) {
          application = vpn.installedApplications[j]
          break
        }
      result.push(application || ({ name: executable.split("/").pop() || executable,
        executable: executable, icon: "" }))
    }
    return result
  }

  function toggleSplitApplication(executable) {
    var selected = splitList(splitAppsField.text), next = [], found = false
    for (var i = 0; i < selected.length; i++) {
      if (selected[i] === executable) found = true
      else next.push(selected[i])
    }
    if (!found) next.push(executable)
    splitAppsField.text = next.join(", ")
  }

  function splitApplicationSelected(executable) { return splitList(splitAppsField.text).indexOf(executable) !== -1 }

  function formatBytes(value) {
    var bytes = Number(value || 0)
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KiB"
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MiB"
    return (bytes / 1073741824).toFixed(2) + " GiB"
  }

  function shortcutToggle() {
    if (vpn.connected) {
      root.open()
      root.requestConfirmation("disconnect", -1, "")
    } else {
      vpn.connect("fastest", "", "none")
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    vpn.refresh()
    if (vpn.countries.length === 0) vpn.refreshLocations()
    if (!vpn.configLoaded) vpn.refreshConfig()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Connections {
    target: vpn
    function onCountriesChanged() { root.selectDefaultCountry() }
    function onCitiesChanged() { Qt.callLater(root.selectFirstFilteredCity) }
    function onConfigValuesChanged() { root.syncConfigControls() }
    function onExitIpChanged() {
      root.exitIpVisible = false
      root.exitIpCopied = false
    }
    function onServerChanged() { root.recordConnectedServer() }
    function onConnectedChanged() { root.recordConnectedServer() }
    function onSplitTunnelingChanged() {
      var mode = String(vpn.splitTunneling.mode || "exclude")
      splitModeBox.value = mode
      var config = vpn.splitTunneling[mode] || ({ app_paths: [], ip_ranges: [] })
      splitAppsField.text = (config.app_paths || []).join(", ")
      splitIpsField.text = (config.ip_ranges || []).join(", ")
    }
  }

  Process {
    id: ipCopyProcess
    running: false
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.exitIpCopied = true
        copyFeedbackTimer.restart()
      } else {
        root.exitIpCopied = false
        vpn.reportError = "Could not copy the exit IP"
      }
    }
  }

  Timer {
    id: copyFeedbackTimer
    interval: 1800
    repeat: false
    onTriggered: root.exitIpCopied = false
  }

  Timer {
    id: serverSearchDebounce
    interval: 300
    repeat: false
    onTriggered: root.refreshServerBrowser()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function openSettings(): void {
      if (!root.settingsExpanded) root.toggleSettings()
      root.open()
      Qt.callLater(function() {
        contentFlick.contentY = Math.max(0, settingsSection.mapToItem(content, 0, 0).y)
      })
    }
    function openServerMap(): void {
      root.settingsExpanded = false
      modeBox.value = "Server"
      root.scheduleServerRefresh()
      root.open()
      Qt.callLater(function() {
        contentFlick.contentY = Math.max(0, quickSection.mapToItem(content, 0, 0).y)
      })
    }
    function refresh(): string { vpn.refresh(); return "ok" }
    function refreshLocations(): string { vpn.refreshLocations(); return "ok" }
    function loadCities(countryCode: string): string { vpn.loadCities(countryCode); return "ok" }
    function locationStatus(): string { return vpn.countries.length + " countries; " + vpn.cities.length + " cities for " + vpn.citiesCountryCode }
    function refreshServers(query: string, feature: string, maxLoad: int): string {
      return vpn.refreshServers(query, feature, maxLoad, true) ? "ok" : "unavailable"
    }
    function serverStatus(): string {
      return JSON.stringify({ available: vpn.enhancedServersAvailable, shown: vpn.serverResults.length,
        total: vpn.serverResultTotal, cacheTotal: vpn.serverCacheTotal, helperVersion: vpn.enhancedHelperVersion,
        protonVersion: vpn.enhancedProtonVersion, error: vpn.enhancedServersError })
    }
    function refreshConfig(): string { vpn.refreshConfig(); return "ok" }
    function configStatus(): string { return JSON.stringify(vpn.configValues) }
    function advancedStatus(): string {
      return JSON.stringify({ splitResolved: vpn.splitTunnelingResolved,
        splitAvailable: vpn.splitTunneling.available,
        applications: vpn.installedApplications.length,
        protocols: (vpn.coreSettings.protocols || []).length })
    }
    function checkExitIp(): string { return vpn.openIpReport() ? "ok" : vpn.reportError }
    function exitIpStatus(): string {
      return JSON.stringify({ ip: vpn.exitIp, status: vpn.reportStatus, error: vpn.reportError, busy: vpn.reportBusy })
    }
    function up(): string { vpn.connect("fastest", "", "none"); return "ok" }
    function disconnect(): string { vpn.disconnect(); return "ok" }
    function status(): string { return vpn.statusText }
    function accountStatus(): string {
      return JSON.stringify({ installationResolved: vpn.installationResolved,
        authResolved: vpn.authResolved, needsLogin: vpn.needsLogin, status: vpn.statusText })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    Accessible.name: vpn.connected ? "Proton VPN connected" : "Proton VPN disconnected"
    Accessible.role: Accessible.Button
    iconComponent: Component {
      ProtonVpnIcon {
        iconSize: Style.space(11)
        badgeColor: root.urgent
        foreground: root.foreground
        connected: vpn.connected
        warning: vpn.needsLogin || vpn.lastError !== "" || vpn.healthDegraded
        busy: vpn.indicatorBusy
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.shortcutToggle()
      else if (buttonCode === Qt.MiddleButton) vpn.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Math.max(content.implicitHeight, Style.space(420)),
      root.settingsExpanded ? Style.space(900) : Style.space(540))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: countrySearch.activeFocus || citySearch.activeFocus || serverField.activeFocus || serverSearch.activeFocus
        || customDnsField.activeFocus || profileNameField.activeFocus || splitAppsField.activeFocus || splitIpsField.activeFocus
        || splitAppPicker.activeFocus || protonUsernameField.activeFocus || root.confirmOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") vpn.refresh()
        else if (text === "t" || text === "T") root.shortcutToggle()
      }

      Flickable {
        id: contentFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          Item {
            width: parent.width
            implicitHeight: hero.implicitHeight

            PanelHero {
              id: hero
              width: parent.width
              title: vpn.server || "Proton VPN Control Center"
              meta: vpn.indicatorBusy ? (vpn.actionStatus || "Working…")
                : vpn.connected && vpn.location !== "" ? vpn.location : vpn.statusText
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: 1.0
              iconComponent: Component {
                ProtonVpnIcon {
                  iconSize: Style.font.display
                  badgeColor: root.urgent
                  foreground: root.foreground
                  connected: vpn.connected
                  warning: vpn.needsLogin || vpn.lastError !== "" || vpn.healthDegraded
                  busy: vpn.indicatorBusy
                }
              }
              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: vpn.installed && vpn.authResolved && !vpn.needsLogin
                  checked: vpn.connected
                  busy: vpn.busy
                  foreground: hero.foreground
                  Accessible.name: vpn.connected ? "Disconnect Proton VPN" : "Connect Proton VPN"
                  Accessible.role: Accessible.CheckBox
                  onToggled: vpn.toggle()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: vpn.connectionAction === "disconnect" ? "Disconnecting…"
                      : vpn.connectionAction === "connect" ? "Connecting…"
                      : vpn.connected ? "Disconnect Proton VPN" : "Quick connect"
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          RowLayout {
            visible: vpn.actionStatus !== "" || vpn.lastError !== ""
            width: parent.width
            spacing: Style.space(8)

            Text {
              Layout.fillWidth: true
              text: vpn.actionStatus !== "" ? vpn.actionStatus : vpn.lastError
              color: vpn.lastError !== "" && vpn.actionStatus === "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            ActionButton {
              visible: vpn.lastErrorRetryable && vpn.actionStatus === ""
              text: "Retry"
              enabled: !vpn.busy
              onClicked: vpn.retryLastAction()
            }
          }

          Column {
            visible: vpn.installationResolved && !vpn.installed
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SETUP"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              text: "The official Proton VPN CLI is missing. Omarchy can install proton-vpn-cli in a floating terminal; you may be asked for your sudo password. The CLI cannot run alongside Proton VPN GUI."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            ActionButton {
              width: parent.width
              text: vpn.onboardingBusy ? "Opening installer…" : "Install Proton VPN CLI"
              enabled: !vpn.onboardingBusy
              onClicked: vpn.installCli()
            }

            ActionButton {
              width: parent.width
              text: vpn.refreshing ? "Checking…" : "Refresh detection"
              enabled: !vpn.refreshing && !vpn.onboardingBusy
              onClicked: vpn.refresh()
            }
          }

          Column {
            visible: vpn.installed && vpn.authResolved && vpn.needsLogin
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SIGN IN"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              text: "Enter only your Proton username here. Authentication opens in a terminal so this plugin never handles your password."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            TextField {
              id: protonUsernameField
              width: parent.width
              placeholderText: "username or user@proton.me"
              foreground: root.foreground
              selectByMouse: true
              onAccepted: vpn.signIn(text)
            }

            ActionButton {
              width: parent.width
              text: vpn.onboardingBusy ? "Opening sign-in…" : "Sign in with Proton"
              enabled: !vpn.onboardingBusy && protonUsernameField.text.trim() !== ""
              onClicked: vpn.signIn(protonUsernameField.text)
            }

            ActionButton {
              width: parent.width
              text: vpn.refreshing ? "Checking…" : "Refresh sign-in status"
              enabled: !vpn.refreshing && !vpn.onboardingBusy
              onClicked: vpn.refreshStatus()
            }
          }

          Text {
            visible: (!vpn.installed || vpn.needsLogin) && (vpn.onboardingStatus !== "" || vpn.onboardingError !== "")
            width: parent.width
            text: vpn.onboardingError !== "" ? vpn.onboardingError : vpn.onboardingStatus
            color: vpn.onboardingError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: !vpn.installationResolved || (vpn.installed && !vpn.authResolved)
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader { text: "PROTON VPN"; foreground: root.foreground; fontFamily: root.fontFamily }
            Text {
              width: parent.width
              text: vpn.installationResolved ? "Checking Proton VPN account…" : "Loading Proton VPN…"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }
          }

          // Stable declarative slots keep the source components reusable while
          // presenting the control centre in task order.
          Column { id: connectionSlot; visible: vpn.authResolved; width: parent.width; spacing: Style.space(12) }
          Column { id: quickSlot; visible: vpn.authResolved; width: parent.width; spacing: Style.space(12) }
          Column { id: favoritesSlot; visible: vpn.authResolved; width: parent.width; spacing: Style.space(12) }
          Column { id: recentSlot; visible: vpn.authResolved; width: parent.width; spacing: Style.space(12) }
          Column { id: profilesSlot; visible: vpn.authResolved; width: parent.width; spacing: Style.space(12) }
          Column { id: settingsSlot; visible: vpn.authResolved; width: parent.width; spacing: Style.space(12) }

          Column {
            id: connectionSection
            parent: connectionSlot
            visible: vpn.installed && vpn.connected
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "CONNECTION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            DetailRow { label: "Server"; value: vpn.server }
            DetailRow { label: "Location"; value: vpn.location }
            DetailRow { label: "Load"; value: vpn.load }
            DetailRow { label: "Protocol"; value: vpn.protocol }
            DetailRow {
              label: "Health"
              value: !vpn.healthResolved ? "Verifying…" : (vpn.health.healthy ? "Protected" : "Needs attention")
              valueColor: !vpn.healthResolved || vpn.health.healthy ? root.foreground : root.urgent
            }
            Text {
              visible: vpn.healthResolved && !vpn.health.healthy
              width: parent.width
              text: "Tunnel interface: " + (vpn.health.interfaceUp ? "OK" : "missing")
                + " · VPN route: " + (vpn.health.routeThroughVpn ? "OK" : "missing")
                + " · Proton DNS: " + (vpn.health.protonDns ? "OK" : "missing")
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            DetailRow { label: "Traffic"; value: "↓ " + root.formatBytes(vpn.health.rxBytes) + "  ↑ " + root.formatBytes(vpn.health.txBytes) }
            RowLayout {
              width: parent.width
              spacing: Style.space(4)

              Text {
                text: "Exit IP"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                Layout.fillWidth: true
                text: vpn.exitIp !== ""
                  ? (root.exitIpVisible ? vpn.exitIp : "••••••••••••")
                  : (vpn.exitIpBusy ? "Checking…" : "Unavailable")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
              }

              PanelActionButton {
                visible: vpn.exitIp !== ""
                iconText: root.exitIpVisible ? "󰈉" : "󰈈"
                tooltipText: root.exitIpVisible ? "Hide exit IP" : "Show exit IP"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                size: Style.space(22)
                onClicked: root.exitIpVisible = !root.exitIpVisible
              }

              PanelActionButton {
                visible: vpn.exitIp !== ""
                iconText: root.exitIpCopied ? "󰄬" : "󰆏"
                tooltipText: root.exitIpCopied ? "Copied" : "Copy exit IP"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                size: Style.space(22)
                enabled: !ipCopyProcess.running
                onClicked: root.copyExitIp()
              }
            }

            Text {
              visible: vpn.dnsCompatibilityError !== ""
              width: parent.width
              text: vpn.dnsCompatibilityError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Column {
              visible: vpn.dnsCompatibilityNeeded || vpn.dnsCompatibilityStatus !== ""
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: vpn.dnsCompatibilityNeeded
                  ? "Strict DNS-over-TLS may block Proton DNS. Allow a temporary exception for proton0?"
                  : vpn.dnsCompatibilityStatus
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              ActionButton {
                visible: vpn.dnsCompatibilityNeeded
                width: parent.width
                text: vpn.dnsCompatibilityBusy ? "Applying DNS exception…" : "Allow Proton DNS"
                enabled: !vpn.dnsCompatibilityBusy
                onClicked: vpn.allowProtonDnsCompatibility()
              }
            }

            Text {
              visible: vpn.reportError !== ""
              width: parent.width
              text: vpn.reportError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              visible: vpn.reportStatus !== ""
              width: parent.width
              text: vpn.reportStatus
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

            ActionButton {
              width: parent.width
              text: vpn.reportBusy
                ? (vpn.openingReport ? "Opening AbuseIPDB…" : "Finding exit IP…")
                : "Check IP reputation"
              enabled: !vpn.reportBusy && !vpn.busy
              onClicked: vpn.openIpReport()
            }

            Text {
              width: parent.width
              text: "The exit IPv4 is fetched once per VPN server through proton0. The button opens its AbuseIPDB page; no API key is required."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }
          }

          PanelSeparator {
            id: profilesSeparator
            parent: profilesSlot
            visible: vpn.installed && !vpn.needsLogin
            foreground: root.foreground
          }

          Column {
            id: profilesSection
            parent: profilesSlot
            visible: vpn.installed && !vpn.needsLogin
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader { text: "PROFILES"; foreground: root.foreground; fontFamily: root.fontFamily }

            Repeater {
              model: root.profiles
              ProfileRow {
                required property var modelData
                required property int index
                width: parent.width
                profile: modelData
                rowIndex: index
              }
            }

            TextField {
              id: profileNameField
              width: parent.width
              placeholderText: "New profile name"
              foreground: root.foreground
              selectByMouse: true
              onAccepted: root.saveCurrentProfile()
            }

            ActionButton {
              width: parent.width
              text: "Save current target and VPN settings"
              enabled: vpn.configLoaded && !vpn.busy
              onClicked: root.saveCurrentProfile()
            }

            Text {
              visible: vpn.profileStatus !== "" || vpn.profileError !== ""
              width: parent.width
              text: vpn.profileError !== "" ? vpn.profileError : vpn.profileStatus
              color: vpn.profileError !== "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }

          Column {
            id: recentSection
            parent: recentSlot
            visible: vpn.installed && !vpn.needsLogin && root.serverHistory.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader { text: "RECENT SERVERS"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.serverHistory.slice(0, 5)
              HistoryRow { required property var modelData; width: parent.width; record: modelData }
            }
            ActionButton {
              width: parent.width
              text: "Clear recent servers"
              onClicked: root.requestConfirmation("history", -1, "")
            }
          }

          Column {
            id: advancedSection
            parent: advancedSlot
            visible: vpn.installed && !vpn.needsLogin && root.settingsExpanded
            width: parent.width
            spacing: Style.space(9)

            Column {
              visible: true
              width: parent.width
              spacing: Style.space(10)

              PanelSectionHeader { text: "AUTOMATION AND ADVANCED CONTROLS"; foreground: root.foreground; fontFamily: root.fontFamily }

              HelpSectionHeader {
                title: "NETWORK AUTOMATION"
                helpText: "Automatically protects selected networks and can recover an unexpected VPN drop. Manual disconnects remain respected."
              }

              Toggle {
                width: parent.width
                checked: Boolean(root.settings && root.settings.autoConnectUntrusted)
                label: "Protect untrusted networks"
                description: "Automatically connect after joining a NetworkManager connection name not marked trusted. Retries are rate-limited."
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                onClicked: root.persistPluginSetting("autoConnectUntrusted", !checked)
              }

              Toggle {
                width: parent.width
                checked: Boolean(root.settings && root.settings.recoverUnexpectedDrops)
                label: "Recover unexpected VPN drops"
                description: "Retry the last server, then fall back to Proton's fastest server. Manual disconnects are respected."
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                onClicked: root.persistPluginSetting("recoverUnexpectedDrops", !checked)
              }

              Toggle {
                width: parent.width
                checked: Boolean(root.settings && root.settings.vpnNotifications)
                label: "VPN notifications"
                description: "Notify when recovery succeeds or fails and when the forwarded port changes."
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                onClicked: root.persistPluginSetting("vpnNotifications", !checked)
              }

              Text { visible: vpn.recoveryStatus !== ""; width: parent.width; text: vpn.recoveryStatus; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }

              ActionButton {
                width: parent.width
                text: "Export redacted diagnostic report"
                onClicked: vpn.exportDiagnostics()
              }
              Text { visible: vpn.diagnosticsStatus !== "" || vpn.diagnosticsError !== ""; width: parent.width; text: vpn.diagnosticsError !== "" ? vpn.diagnosticsError : vpn.diagnosticsStatus; color: vpn.diagnosticsError !== "" ? root.urgent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Text { visible: vpn.diagnosticsPath !== ""; width: parent.width; text: vpn.diagnosticsPath; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle }
              RowLayout {
                visible: vpn.diagnosticsPath !== ""
                width: parent.width
                spacing: Style.space(8)
                ActionButton { Layout.fillWidth: true; text: "Copy report path"; onClicked: vpn.copyDiagnosticsPath() }
                ActionButton { Layout.fillWidth: true; text: "Open report folder"; onClicked: vpn.openDiagnosticsFolder() }
              }

              StableDropdown {
                width: parent.width
                showLabel: false
                value: String((root.settings && root.settings.autoConnectProfile) || "")
                options: [{ value: "", label: "Auto-connect: Fastest" }].concat(root.profiles.map(function(profile) {
                  return { value: String(profile.name || ""), label: "Auto-connect: " + String(profile.name || "Profile") }
                }))
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(nextValue) { root.persistPluginSetting("autoConnectProfile", nextValue) }
              }

              Text { width: parent.width; text: "Current: " + String(vpn.activeNetwork.connection || "Offline"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }

              ActionButton {
                width: parent.width
                text: root.currentNetworkTrusted() ? "Remove current network from trusted" : "Trust current network"
                enabled: vpn.activeNetwork.online
                onClicked: root.toggleCurrentNetworkTrusted()
              }

              HelpSectionHeader {
                title: "PORT FORWARDING"
                helpText: "Requests a temporary incoming port from Proton and keeps its lease renewed. It requires a supported P2P server and cannot run with Moderate NAT."
              }
              Text { visible: root.configValue("moderate-nat") === "on"; width: parent.width; text: "Moderate NAT is enabled. Disable it before enabling port forwarding."; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
              DetailRow { label: "Lease service"; value: vpn.portForward.active ? "Running" : "Stopped" }
              DetailRow { label: "Forwarded port"; value: Number(vpn.portForward.port || 0) > 0 ? String(vpn.portForward.port) : "Unavailable" }
              Text { width: parent.width; text: String(vpn.portForward.requirements || "Paid Proton plan, port forwarding enabled, and a connected P2P-capable server"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Text { visible: !vpn.portForward.serviceInstalled || !vpn.portForward.natPmpInstalled; width: parent.width; text: !vpn.portForward.serviceInstalled ? "Lease service is not installed on this machine." : "natpmpc is required to obtain and renew a forwarded port."; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Text { visible: Boolean(vpn.portForward.message); width: parent.width; text: String(vpn.portForward.message || ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              ActionButton {
                width: parent.width
                text: vpn.portForward.active ? "Stop forwarding lease" : "Start forwarding lease"
                enabled: vpn.connected && root.configValue("port-forwarding") === "on" && root.configValue("moderate-nat") !== "on"
                onClicked: vpn.setPortForwardRunning(!vpn.portForward.active)
              }
              Text { visible: vpn.portForwardError !== ""; width: parent.width; text: vpn.portForwardError; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }

              HelpSectionHeader {
                title: "PROTOCOL AND KILL SWITCH"
                helpText: "Protocol controls how the tunnel is transported. Standard kill switch blocks traffic during VPN loss; Advanced also blocks traffic when Proton VPN is not connected."
              }
              Text { width: parent.width; text: "Only protocols validated by the installed Proton backend are shown."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Text { visible: (vpn.coreSettings.unavailableProtocols || []).length > 0; width: parent.width; text: "Stealth is hidden because Proton's installed CLI does not expose it safely."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              StableDropdown { id: coreProtocolBox; width: parent.width; showLabel: false; value: String(vpn.coreSettings.protocol || ""); options: vpn.coreSettings.protocols || []; foreground: root.foreground; fontFamily: root.fontFamily }
              ActionButton { width: parent.width; text: "Apply protocol safely"; enabled: coreProtocolBox.value !== "" && coreProtocolBox.value !== vpn.coreSettings.protocol; onClicked: vpn.setCoreSetting("protocol", coreProtocolBox.value) }
              StableDropdown { id: advancedKillSwitchBox; width: parent.width; showLabel: false; value: Number(vpn.coreSettings.killSwitch || 0) === 2 ? "advanced" : (Number(vpn.coreSettings.killSwitch || 0) === 1 ? "standard" : "off"); options: [{ value: "off", label: "Kill switch: Off" }, { value: "standard", label: "Kill switch: Standard" }, { value: "advanced", label: "Kill switch: Advanced (persistent)" }]; foreground: root.foreground; fontFamily: root.fontFamily }
              ActionButton { width: parent.width; text: "Apply kill-switch mode safely"; enabled: vpn.coreSettings.advancedKillSwitchAvailable; onClicked: vpn.setCoreSetting("kill-switch", advancedKillSwitchBox.value) }
              Text { width: parent.width; text: "The current server is restored automatically; failed changes are rolled back."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Text { visible: vpn.coreSettingsError !== ""; width: parent.width; text: vpn.coreSettingsError; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }

              HelpSectionHeader {
                title: "SPLIT TUNNELLING"
                helpText: "Exclude mode sends listed apps and IP ranges outside the VPN. Include mode sends only the listed entries through the VPN."
              }
              Text { width: parent.width; text: !vpn.splitTunnelingResolved ? "Checking official Proton split-tunnelling backend…" : (vpn.splitTunneling.available ? "Official Proton split-tunnelling backend detected." : String(vpn.splitTunneling.availabilityReason || "Split-tunnelling backend unavailable.")); color: !vpn.splitTunnelingResolved || vpn.splitTunneling.available ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
              StableDropdown { id: splitModeBox; width: parent.width; showLabel: false; value: "exclude"; options: [{ value: "exclude", label: "Exclude listed apps/IPs" }, { value: "include", label: "Only listed apps/IPs use VPN" }]; foreground: root.foreground; fontFamily: root.fontFamily }
              StableSearchableDropdown {
                id: splitAppPicker
                width: parent.width
                showLabel: false
                value: ""
                triggerLabel: "Add application…"
                placeholderText: "Search installed applications…"
                emptyText: "No additional applications"
                options: root.splitApplicationOptions()
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(executable) {
                  if (executable !== "" && !root.splitApplicationSelected(executable))
                    root.toggleSplitApplication(executable)
                  value = ""
                }
              }
              Text { visible: root.selectedSplitApplications().length > 0; width: parent.width; text: "Selected applications · click one to remove"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Repeater {
                model: root.selectedSplitApplications()
                SplitAppRow { required property var modelData; width: parent.width; application: modelData }
              }
              TextField { id: splitAppsField; width: parent.width; placeholderText: "Executable paths, comma separated"; foreground: root.foreground; selectByMouse: true }
              TextField { id: splitIpsField; width: parent.width; placeholderText: "IP ranges, comma separated"; foreground: root.foreground; selectByMouse: true }
              RowLayout {
                width: parent.width
                spacing: Style.space(8)
                ActionButton { Layout.fillWidth: true; text: "Save and enable"; enabled: vpn.splitTunnelingResolved && vpn.splitTunneling.available; onClicked: vpn.setSplitTunneling(true, splitModeBox.value, root.splitList(splitAppsField.text), root.splitList(splitIpsField.text)) }
                ActionButton { Layout.fillWidth: true; text: "Disable"; enabled: vpn.splitTunnelingResolved && vpn.splitTunneling.available; onClicked: vpn.setSplitTunneling(false, splitModeBox.value, root.splitList(splitAppsField.text), root.splitList(splitIpsField.text)) }
              }
              Text { visible: vpn.connected; width: parent.width; text: "The current server will be restored automatically after this change."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Text { visible: vpn.splitTunnelingError !== ""; width: parent.width; text: vpn.splitTunnelingError; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
            }
          }

          PanelSeparator {
            id: favoritesSeparator
            parent: favoritesSlot
            visible: vpn.installed && !vpn.needsLogin
            foreground: root.foreground
          }

          Column {
            id: favoritesSection
            parent: favoritesSlot
            visible: vpn.installed && !vpn.needsLogin
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "FAVORITES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.favorites.length === 0
              width: parent.width
              text: "Choose a quick-connect target and press the star to save it here."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.favorites
              FavoriteRow {
                required property var modelData
                required property int index
                width: parent.width
                favorite: modelData
                rowIndex: index
              }
            }
          }

          PanelSeparator {
            id: quickSeparator
            parent: quickSlot
            visible: vpn.installed && !vpn.needsLogin
            foreground: root.foreground
          }

          Column {
            id: quickSection
            parent: quickSlot
            visible: vpn.installed && !vpn.needsLogin
            width: parent.width
            spacing: Style.space(9)

            PanelSectionHeader {
              text: "QUICK CONNECT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ActionButton {
              visible: modeBox.value !== "Server"
              width: parent.width
              text: vpn.connected
                ? "Switch by server ID (e.g. CH#242)"
                : "Connect by server ID (e.g. CH#242)"
              enabled: !vpn.busy
              onClicked: root.showServerConnect()
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              StableDropdown {
                id: modeBox
                Layout.fillWidth: true
                showLabel: false
                value: "Fastest"
                options: ["Fastest", "Random", "Country", "City", "Server"]
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(nextValue) {
                  if (nextValue === "City") vpn.loadCities(root.selectedCountryCode())
                  else if (nextValue === "Server") root.scheduleServerRefresh()
                }
              }

              StableDropdown {
                id: featureBox
                Layout.fillWidth: true
                showLabel: false
                value: "None"
                options: ["None", "P2P", "Secure Core", "Tor"]
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
            }

            TextField {
              id: countrySearch
              visible: modeBox.value === "Country" || modeBox.value === "City"
              width: parent.width
              placeholderText: "Search countries by name or code…"
              foreground: root.foreground
              selectByMouse: true
              onTextChanged: Qt.callLater(function() {
                var options = root.filteredCountries()
                countryBox.value = options.length > 0 ? String(options[0].code || "") : ""
              })
            }

            StableDropdown {
              id: countryBox
              visible: modeBox.value === "Country" || modeBox.value === "City"
              width: parent.width
              showLabel: false
              options: root.filteredCountries().map(function(country) {
                return { value: String(country.code || ""), label: String(country.name || country.code || "") }
              })
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !vpn.locationsBusy && vpn.countries.length > 0
              onChanged: function(nextValue) {
                if (modeBox.value === "City") vpn.loadCities(nextValue)
              }
            }

            TextField {
              id: citySearch
              visible: modeBox.value === "City"
              width: parent.width
              placeholderText: "Search cities or features…"
              foreground: root.foreground
              selectByMouse: true
              onTextChanged: Qt.callLater(root.selectFirstFilteredCity)
            }

            StableDropdown {
              id: cityBox
              visible: modeBox.value === "City"
              width: parent.width
              showLabel: false
              options: root.filteredCities().map(function(city) {
                return { value: String(city.name || ""), label: String(city.name || "") }
              })
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !vpn.locationsBusy && vpn.cities.length > 0
            }

            Text {
              visible: modeBox.value === "City" && root.selectedCityFeatures() !== ""
              width: parent.width
              text: "Available features: " + root.selectedCityFeatures()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            TextField {
              id: serverField
              visible: modeBox.value === "Server"
              width: parent.width
              placeholderText: "Server ID, for example CH#242"
              foreground: root.foreground
              selectByMouse: true
              onAccepted: root.submitConnection()
            }

            Text {
              visible: modeBox.value === "Server" && !vpn.enhancedServersAvailable && vpn.enhancedServersError !== ""
              width: parent.width
              text: vpn.enhancedServersError + ". Manual server entry remains available."
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            TextField {
              id: serverSearch
              visible: modeBox.value === "Server"
              width: parent.width
              placeholderText: "Search server, city, country or feature…"
              foreground: root.foreground
              selectByMouse: true
              onTextChanged: root.scheduleServerRefresh()
            }

            RowLayout {
              visible: modeBox.value === "Server"
              width: parent.width
              spacing: Style.space(8)
              StableDropdown {
                id: serverCountryBox
                Layout.fillWidth: true
                showLabel: false
                value: ""
                options: [{ value: "", label: "All countries" }].concat(vpn.countries.map(function(country) {
                  return { value: String(country.code || ""), label: String(country.name || country.code || "") }
                }))
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: { serverRegionBox.value = ""; root.scheduleServerRefresh() }
              }
              StableDropdown {
                id: serverRegionBox
                Layout.fillWidth: true
                showLabel: false
                value: ""
                options: [{ value: "", label: "All states/regions" }].concat(vpn.serverRegions.map(function(region) {
                  return { value: String(region), label: String(region) }
                }))
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: root.scheduleServerRefresh()
              }
            }

            RowLayout {
              visible: modeBox.value === "Server"
              width: parent.width
              spacing: Style.space(8)

              StableDropdown {
                id: serverFeatureBox
                Layout.fillWidth: true
                showLabel: false
                value: "Any"
                options: ["Any", "P2P", "Secure Core", "Tor", "Streaming", "IPv6"]
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: root.scheduleServerRefresh()
              }

              StableDropdown {
                id: serverLoadBox
                Layout.fillWidth: true
                showLabel: false
                value: "100"
                options: [
                  { value: "25", label: "Load ≤25%" },
                  { value: "50", label: "Load ≤50%" },
                  { value: "75", label: "Load ≤75%" },
                  { value: "100", label: "Any load" }
                ]
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: root.scheduleServerRefresh()
              }
            }

            Toggle {
              id: availableServersOnly
              visible: modeBox.value === "Server"
              width: parent.width
              checked: true
              label: "Available servers only"
              description: "Hide offline servers and servers under maintenance."
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              onClicked: root.scheduleServerRefresh()
            }

            Text {
              visible: modeBox.value === "Server" && vpn.serverDataBusy
              width: parent.width
              text: "Reading Proton's local server cache…"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            ServerMap {
              visible: modeBox.value === "Server" && vpn.enhancedServersAvailable
                && vpn.serverMapCountries.length > 0
              width: parent.width
              countries: vpn.serverMapCountries
              selectedCode: String(serverCountryBox.value || "")
              onSelected: function(code) {
                serverCountryBox.value = code
                serverRegionBox.value = ""
                root.scheduleServerRefresh()
              }
            }

            Text {
              visible: modeBox.value === "Server" && vpn.enhancedServersAvailable
              width: parent.width
              text: vpn.serverResultTotal + " matching servers · showing " + vpn.serverResults.length
                + " · cache " + vpn.serverCacheTotal
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            ActionButton {
              readonly property var bestServer: vpn.serverResults.length > 0 ? vpn.serverResults[0] : ({})
              visible: modeBox.value === "Server" && vpn.serverResults.length > 0
              width: parent.width
              text: "Smart connect · " + String(bestServer.id || "")
                + " at " + Number(bestServer.load || 0) + "% load"
              enabled: !vpn.busy && Boolean(bestServer.online) && !Boolean(bestServer.maintenance)
              onClicked: vpn.connect("Server", String(bestServer.id || ""), "None")
            }

            StableSearchableDropdown {
              id: serverPicker
              visible: modeBox.value === "Server" && vpn.serverResults.length > 0
              width: parent.width
              showLabel: false
              value: serverField.text
              triggerLabel: "Select server…"
              placeholderText: "Search these server results…"
              emptyText: "No matching servers"
              options: root.serverSelectionOptions()
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(serverId) {
                serverField.text = serverId
                value = serverId
              }
            }

            Text {
              visible: vpn.locationError !== ""
              width: parent.width
              text: vpn.locationError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              visible: modeBox.value === "City" && cityBox.value !== ""
              width: parent.width
              text: "Proton CLI will choose the fastest available server in " + cityBox.value + ". Individual server lists are not exposed by the official CLI."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              ActionButton {
                Layout.fillWidth: true
                text: vpn.connectionAction === "connect" ? "Connecting…"
                  : vpn.connectionAction === "disconnect" ? "Disconnecting…"
                  : modeBox.value === "Server"
                    ? (vpn.connected ? "Switch server" : "Connect to server")
                    : (vpn.connected ? "Connect elsewhere" : "Connect")
                enabled: !vpn.busy
                onClicked: root.submitConnection()
              }

              PanelActionButton {
                iconText: root.currentFavoriteIndex() >= 0 ? "★" : "☆"
                tooltipText: root.currentFavoriteIndex() >= 0 ? "Remove from favorites" : "Add to favorites"
                foreground: root.foreground
                hoverColor: Color.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.subtitle
                size: Style.space(36)
                bordered: true
                enabled: !vpn.busy
                onClicked: root.toggleCurrentFavorite()
              }
            }
          }

          PanelSeparator {
            id: settingsSeparator
            parent: settingsSlot
            visible: vpn.installed && !vpn.needsLogin
            foreground: root.foreground
          }

          Column {
            id: settingsSection
            parent: settingsSlot
            visible: vpn.installed && !vpn.needsLogin
            width: parent.width
            spacing: Style.space(9)

            ActionButton {
              width: parent.width
              text: root.settingsExpanded ? "Hide VPN settings and advanced controls" : "VPN settings and advanced controls"
              enabled: !vpn.configBusy
              onClicked: root.toggleSettings()
            }

            Column {
              visible: root.settingsExpanded
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "SETTINGS"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                visible: vpn.configBusy && !vpn.configLoaded
                width: parent.width
                text: "Loading current Proton VPN configuration…"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                visible: vpn.configError !== ""
                width: parent.width
                text: vpn.configError
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              Column {
                width: parent.width
                spacing: Style.spacing.xs

                SettingTitleHelp {
                  width: parent.width
                  title: "NetShield"
                  helpText: "Filters domains on Proton's DNS servers. Malware-only blocks known threats; the full mode also blocks many advertising and tracking domains. Custom DNS disables NetShield."
                }

                Text {
                  width: parent.width
                  text: "Block malware, ads, and trackers at the VPN level."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                StableDropdown {
                  id: netshieldBox
                  width: parent.width
                  showLabel: false
                  options: [
                    { value: "off", label: "Off" },
                    { value: "malware-only", label: "Block malware" },
                    { value: "malware-ads-trackers", label: "Block malware, ads & trackers" }
                  ]
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: vpn.configLoaded && !vpn.configBusy && !root.configLocked("netshield")
                  onChanged: function(nextValue) { vpn.setConfig("netshield", nextValue, "") }
                }
              }

              ConfigToggle {
                width: parent.width
                settingKey: "kill-switch"
                enabledValue: "standard"
                label: "Kill switch"
                description: vpn.connected ? "Disconnect before changing this setting." : "Block internet traffic if the VPN connection drops."
                helpText: "Standard mode blocks traffic when an active VPN connection fails. Advanced persistent protection is available farther below when supported by Proton."
                extraLocked: vpn.connected
              }

              ConfigToggle {
                width: parent.width
                settingKey: "ipv6"
                label: "IPv6"
                description: "Route IPv6 traffic through Proton VPN."
                helpText: "When enabled, IPv6 traffic uses the VPN tunnel instead of being disabled. Leave this on unless a network has incompatible IPv6 routing."
              }

              Column {
                width: parent.width
                spacing: Style.space(8)

                HelpToggle {
                  width: parent.width
                  checked: root.configValue("custom-dns") === "on"
                  label: "Custom DNS"
                  description: "Normally leave disabled to use Proton DNS and NetShield."
                  helpText: "Sends DNS requests to the addresses entered below instead of Proton DNS. This can disable NetShield filtering and may expose DNS requests if the selected resolver is unsuitable."
                  controlEnabled: vpn.configLoaded && !vpn.configBusy && !root.configLocked("custom-dns")
                  onClicked: root.toggleCustomDns()
                }

                TextField {
                  id: customDnsField
                  width: parent.width
                  text: String((root.settings && root.settings.customDnsServers) || "")
                  placeholderText: "1.1.1.1,8.8.8.8"
                  foreground: root.foreground
                  selectByMouse: true
                  onAccepted: root.applyCustomDns()
                }

                Text {
                  width: parent.width
                  text: root.configValue("custom-dns") === "on"
                    ? "Press Enter after editing to apply new addresses."
                    : "Enabling this overrides Proton DNS and NetShield."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }

              ConfigToggle {
                width: parent.width
                settingKey: "port-forwarding"
                label: "Port forwarding"
                description: root.configValue("moderate-nat") === "on" ? "Disable Moderate NAT first; Proton does not allow both." : "Request a forwarded port; the lease supervisor displays and renews it."
                helpText: "Allows incoming connections through a temporary Proton-assigned port. This is mainly useful for peer-to-peer clients and requires a supported P2P server."
                extraLocked: root.configValue("moderate-nat") === "on"
              }

              ConfigToggle {
                width: parent.width
                settingKey: "moderate-nat"
                label: "Moderate NAT (NAT Type 2)"
                description: root.configValue("port-forwarding") === "on" ? "Disable port forwarding first; Proton does not allow both." : "Improve peer-to-peer connectivity with a less restrictive NAT."
                helpText: "Uses a less restrictive NAT mapping for games, calls, and peer-to-peer connections. It cannot be enabled together with port forwarding."
                extraLocked: root.configValue("port-forwarding") === "on"
              }

              ConfigToggle {
                width: parent.width
                settingKey: "vpn-accelerator"
                label: "VPN Accelerator"
                description: "Use Proton's connection speed optimization."
                helpText: "Proton optimizes packet handling and routing to improve throughput, particularly on distant or unstable connections."
              }

              ConfigToggle {
                width: parent.width
                settingKey: "anonymous-crash-reports"
                label: "Anonymous crash reports"
                description: "Allow anonymous CLI crash reports."
                helpText: "Allows Proton's CLI to submit anonymous technical crash information. It does not include your password or two-factor code."
              }

              Text {
                width: parent.width
                text: "Values are read from protonvpn config list. Changes use protonvpn config set."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
              }

            }

            Column {
              id: advancedSlot
              visible: root.settingsExpanded
              width: parent.width
              spacing: Style.space(12)
            }
          }

          Column {
            visible: vpn.installed && vpn.authResolved && !vpn.needsLogin
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { width: parent.width; foreground: root.foreground }
            PanelSectionHeader { text: "ACCOUNT"; foreground: root.foreground; fontFamily: root.fontFamily }
            ActionButton {
              width: parent.width
              text: vpn.connected ? "Disconnect before signing out" : "Sign out of Proton VPN"
              enabled: !vpn.connected && !vpn.busy
              onClicked: root.requestConfirmation("logout", -1, "")
            }
          }

          Text {
            visible: vpn.installed
            width: parent.width
            text: "Left click: panel   Right click: connect / confirm disconnect   Middle click: refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      ConfirmDialog {
        id: actionConfirm
        anchors.fill: parent
        opened: root.confirmOpen
        z: 20
        message: root.confirmationMessage()
        confirmText: root.confirmKind === "logout" ? "Sign out"
          : root.confirmKind === "disconnect" ? "Disconnect"
          : (root.confirmKind === "history" ? "Clear" : "Remove")
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.cancelConfirmation()
        onConfirmed: root.confirmPendingAction()
      }
    }
  }

  component DetailRow: RowLayout {
    required property string label
    required property string value
    property color valueColor: root.foreground
    width: parent ? parent.width : 0
    visible: value !== ""
    spacing: Style.space(12)

    Text {
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      Layout.fillWidth: true
      text: parent.value
      color: parent.valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideLeft
    }
  }

  // Omarchy's stock Dropdown uses CloseOnPressOutside. When its own trigger
  // is clicked while the popup is open, Qt closes the popup before the
  // trigger handles that same click, so the trigger immediately reopens it.
  // Keep the stock visuals and keyboard behavior, but treat the trigger as
  // the popup parent and center long lists synchronously on open.
  component StableDropdown: Dropdown {
    id: stableDropdown
    property var _popupObject: null
    property var _listObject: null

    function _discover(object, seen) {
      if (!object || seen.indexOf(object) !== -1) return
      seen.push(object)
      if (object.closePolicy !== undefined && object.opened !== undefined)
        _popupObject = object
      if (typeof object.positionViewAtIndex === "function" && object.currentIndex !== undefined)
        _listObject = object
      var values = object.data || object.children || []
      for (var i = 0; i < values.length; i++) _discover(values[i], seen)
    }

    function _stabilize() {
      _discover(stableDropdown, [])
      if (_popupObject)
        _popupObject.closePolicy = Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    }

    Component.onCompleted: Qt.callLater(_stabilize)

    Connections {
      target: stableDropdown._popupObject
      function onOpened() {
        Qt.callLater(function() {
          if (stableDropdown._listObject && stableDropdown._listObject.currentIndex >= 0)
            stableDropdown._listObject.positionViewAtIndex(stableDropdown._listObject.currentIndex, ListView.Center)
        })
      }
    }
  }

  component StableSearchableDropdown: SearchableDropdown {
    id: stableSearchableDropdown
    property var _popupObject: null

    function _discover(object, seen) {
      if (!object || seen.indexOf(object) !== -1) return
      seen.push(object)
      if (object.closePolicy !== undefined && object.opened !== undefined)
        _popupObject = object
      var values = object.data || object.children || []
      for (var i = 0; i < values.length; i++) _discover(values[i], seen)
    }

    function _stabilize() {
      _discover(stableSearchableDropdown, [])
      if (_popupObject)
        _popupObject.closePolicy = Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    }

    Component.onCompleted: Qt.callLater(_stabilize)
  }

  component HelpSectionHeader: Column {
    id: helpSectionHeader
    required property string title
    required property string helpText
    property bool helpOpen: false

    width: parent ? parent.width : 0
    spacing: Style.space(5)

    Item {
      width: parent.width
      implicitHeight: Math.max(helpTitle.implicitHeight, helpButton.implicitHeight)

      PanelSectionHeader {
        id: helpTitle
        anchors.left: parent.left
        anchors.right: helpButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: helpSectionHeader.title
        foreground: root.foreground
        fontFamily: root.fontFamily
        elide: Text.ElideRight
      }

      PanelActionButton {
        id: helpButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: "?"
        tooltipText: helpSectionHeader.helpOpen ? "Hide explanation" : "Explain this setting"
        foreground: root.foreground
        hoverColor: Color.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        size: Style.space(20)
        bordered: true
        onClicked: helpSectionHeader.helpOpen = !helpSectionHeader.helpOpen
      }
    }

    Text {
      visible: helpSectionHeader.helpOpen
      width: parent.width
      text: helpSectionHeader.helpText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  component SettingTitleHelp: Column {
    id: settingTitleHelp
    required property string title
    required property string helpText
    property bool helpOpen: false

    spacing: Style.space(5)

    Item {
      width: parent.width
      implicitHeight: Math.max(settingTitle.implicitHeight, settingTitleButton.implicitHeight)

      Text {
        id: settingTitle
        anchors.left: parent.left
        anchors.right: settingTitleButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: settingTitleHelp.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      PanelActionButton {
        id: settingTitleButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: "?"
        tooltipText: settingTitleHelp.helpOpen ? "Hide explanation" : "Explain " + settingTitleHelp.title
        foreground: root.foreground
        hoverColor: Color.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        size: Style.space(20)
        bordered: true
        focusable: true
        onClicked: settingTitleHelp.helpOpen = !settingTitleHelp.helpOpen
      }
    }

    Text {
      visible: settingTitleHelp.helpOpen
      width: parent.width
      text: settingTitleHelp.helpText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  component HelpToggle: Column {
    id: helpToggle
    property bool checked: false
    property string label: ""
    property string description: ""
    property string helpText: ""
    property bool controlEnabled: true
    property bool helpOpen: false
    signal clicked()

    spacing: Style.space(5)

    Item {
      width: parent.width
      implicitHeight: Math.max(helpToggleControl.implicitHeight, helpToggleButton.implicitHeight)

      Toggle {
        id: helpToggleControl
        anchors.left: parent.left
        anchors.right: helpToggleButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        checked: helpToggle.checked
        label: helpToggle.label
        description: helpToggle.description
        foreground: root.foreground
        accent: Color.accent
        fontFamily: root.fontFamily
        enabled: helpToggle.controlEnabled
        opacity: enabled ? 1.0 : 0.5
        onClicked: helpToggle.clicked()
      }

      PanelActionButton {
        id: helpToggleButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: "?"
        tooltipText: helpToggle.helpOpen ? "Hide explanation" : "Explain " + helpToggle.label
        foreground: root.foreground
        hoverColor: Color.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        size: Style.space(20)
        bordered: true
        focusable: true
        onClicked: helpToggle.helpOpen = !helpToggle.helpOpen
      }
    }

    Text {
      visible: helpToggle.helpOpen
      width: parent.width
      text: helpToggle.helpText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  component FavoriteRow: CursorSurface {
    id: favoriteRow
    required property var favorite
    required property int rowIndex

    foreground: root.foreground
    implicitHeight: favoriteContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: vpn.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
      enabled: !vpn.busy
      onClicked: root.connectFavorite(favoriteRow.favorite)
    }

    RowLayout {
      id: favoriteContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.controlPaddingX
      anchors.rightMargin: Style.spacing.controlPaddingX
      spacing: Style.space(8)

      Column {
        Layout.fillWidth: true
        spacing: Style.spacing.xxs

        Text {
          width: parent.width
          text: String(favoriteRow.favorite.label || favoriteRow.favorite.target || favoriteRow.favorite.mode || "Favorite")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: root.favoriteDescription(favoriteRow.favorite)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        iconText: "󰅖"
        tooltipText: "Remove favorite"
        foreground: root.foreground
        hoverColor: root.urgent
        fontFamily: root.fontFamily
        enabled: !vpn.busy
        onClicked: root.requestConfirmation("favorite", favoriteRow.rowIndex,
          String(favoriteRow.favorite.label || favoriteRow.favorite.target || favoriteRow.favorite.mode || "Favorite"))
      }
    }
  }

  component ServerMap: BorderSurface {
    id: serverMap
    required property var countries
    property string selectedCode: ""
    signal selected(string code)

    implicitHeight: Style.space(190)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
    radius: Style.cornerRadius
    borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16), 1)
    clip: true

    Repeater {
      model: [-120, -60, 0, 60, 120]
      Rectangle {
        required property real modelData
        x: (modelData + 180) / 360 * serverMap.width
        width: 1
        height: serverMap.height
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
      }
    }

    Repeater {
      model: [-45, 0, 45]
      Rectangle {
        required property real modelData
        y: (90 - modelData) / 180 * serverMap.height
        width: serverMap.width
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
      }
    }

    Text {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: Style.space(7)
      text: "LOCAL SERVER MAP"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Repeater {
      model: serverMap.countries
      Rectangle {
        id: mapMarker
        required property var modelData
        readonly property bool selected: String(modelData.code || "") === serverMap.selectedCode
        readonly property bool highlighted: selected || mapMouse.containsMouse
        width: highlighted ? Style.space(28) : Style.space(8)
        height: highlighted ? Style.space(18) : Style.space(8)
        radius: highlighted ? Style.cornerRadius : width / 2
        z: highlighted ? 2 : 1
        x: Math.max(0, Math.min(serverMap.width - width,
          (Number(modelData.longitude || 0) + 180) / 360 * serverMap.width - width / 2))
        y: Math.max(0, Math.min(serverMap.height - height,
          (90 - Number(modelData.latitude || 0)) / 180 * serverMap.height - height / 2))
        color: selected ? Color.accent : (Boolean(modelData.available)
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, highlighted ? 0.8 : 0.55)
          : Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, highlighted ? 0.8 : 0.55))
        border.color: selected ? root.foreground : (Boolean(modelData.available) ? Color.accent : root.urgent)
        border.width: 1

        Text {
          anchors.centerIn: parent
          visible: mapMarker.highlighted
          text: String(mapMarker.modelData.code || "")
          color: selected ? root.foreground : (Boolean(mapMarker.modelData.available) ? root.foreground : root.urgent)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: selected
        }

        MouseArea {
          id: mapMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: serverMap.selected(String(mapMarker.modelData.code || ""))
        }

        PanelToolTip {
          visible: mapMouse.containsMouse
          text: String(mapMarker.modelData.code || "") + " · "
            + Number(mapMarker.modelData.serverCount || 0) + " servers · best "
            + Number(mapMarker.modelData.minimumLoad || 0) + "%"
          fontFamily: root.fontFamily
        }
      }
    }
  }

  component ProfileRow: CursorSurface {
    id: profileRow
    required property var profile
    required property int rowIndex
    foreground: root.foreground
    implicitHeight: profileContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: vpn.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
      enabled: !vpn.busy
      onClicked: vpn.applyProfile(profileRow.profile)
    }
    RowLayout {
      id: profileContent
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.controlPaddingX; anchors.rightMargin: Style.spacing.controlPaddingX
      spacing: Style.space(8)
      Column {
        Layout.fillWidth: true
        Text { width: parent.width; text: String(profileRow.profile.name || "Profile"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
        Text { width: parent.width; text: String(profileRow.profile.mode || "Fastest") + (profileRow.profile.target ? " · " + profileRow.profile.target : "") + (profileRow.profile.feature && profileRow.profile.feature !== "None" ? " · " + profileRow.profile.feature : ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
      }
      PanelActionButton { iconText: "󰅖"; tooltipText: "Remove profile"; foreground: root.foreground; hoverColor: root.urgent; fontFamily: root.fontFamily; enabled: !vpn.busy; onClicked: root.requestConfirmation("profile", profileRow.rowIndex, String(profileRow.profile.name || "Profile")) }
    }
  }

  component SplitAppRow: CursorSurface {
    id: splitAppRow
    required property var application
    readonly property bool selected: root.splitApplicationSelected(String(application.executable || ""))
    foreground: root.foreground
    implicitHeight: splitAppContent.implicitHeight + Style.spacing.rowPaddingX
    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleSplitApplication(String(splitAppRow.application.executable || "")) }
    RowLayout {
      id: splitAppContent
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.controlPaddingX; anchors.rightMargin: Style.spacing.controlPaddingX
      spacing: Style.space(8)
      Text { text: splitAppRow.selected ? "󰄬" : "○"; color: splitAppRow.selected ? Color.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
      Column {
        Layout.fillWidth: true
        Text { width: parent.width; text: String(splitAppRow.application.name || "Application"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        Text { width: parent.width; text: String(splitAppRow.application.executable || ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle }
      }
    }
  }

  component HistoryRow: CursorSurface {
    id: historyRow
    required property var record
    foreground: root.foreground
    implicitHeight: historyContent.implicitHeight + Style.spacing.rowPaddingX
    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: vpn.busy ? Qt.ArrowCursor : Qt.PointingHandCursor; enabled: !vpn.busy; onClicked: vpn.connect("Server", String(historyRow.record.server || ""), "None") }
    RowLayout {
      id: historyContent
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.controlPaddingX; anchors.rightMargin: Style.spacing.controlPaddingX
      spacing: Style.space(8)
      Text { Layout.fillWidth: true; text: String(historyRow.record.server || "") + " · " + String(historyRow.record.location || ""); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
      Text { text: String(historyRow.record.load || ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    }
  }

  component ConfigToggle: Column {
    id: configToggle
    required property string settingKey
    property string enabledValue: "on"
    property bool extraLocked: false
    property string label: ""
    property string description: ""
    property string helpText: ""
    property bool helpOpen: false

    readonly property bool locked: extraLocked || root.configLocked(settingKey)

    spacing: Style.space(5)

    Item {
      width: parent.width
      implicitHeight: Math.max(configSwitch.implicitHeight, configHelpButton.implicitHeight)

      Toggle {
        id: configSwitch
        anchors.left: parent.left
        anchors.right: configHelpButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        checked: root.configValue(configToggle.settingKey) === configToggle.enabledValue
        label: configToggle.label
        description: configToggle.description
        foreground: root.foreground
        accent: Color.accent
        fontFamily: root.fontFamily
        enabled: vpn.configLoaded && !vpn.configBusy && !configToggle.locked
        opacity: enabled ? 1.0 : 0.5
        onClicked: vpn.setConfig(configToggle.settingKey, checked ? "off" : configToggle.enabledValue, "")
      }

      PanelActionButton {
        id: configHelpButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: configToggle.helpText !== ""
        iconText: "?"
        tooltipText: configToggle.helpOpen ? "Hide explanation" : "Explain " + configToggle.label
        foreground: root.foreground
        hoverColor: Color.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        size: Style.space(20)
        bordered: true
        focusable: true
        onClicked: configToggle.helpOpen = !configToggle.helpOpen
      }
    }

    Text {
      visible: configToggle.helpOpen
      width: parent.width
      text: configToggle.helpText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  component ActionButton: Button {
    foreground: root.foreground
    accent: Color.accent
    fontFamily: root.fontFamily
    fontSize: Style.font.body
    bordered: true
    focusable: true
    horizontalPadding: Style.spacing.controlPaddingX
    verticalPadding: Style.spacing.controlPaddingY
    opacity: enabled ? 1.0 : 0.5
    Accessible.name: text
    Accessible.role: Accessible.Button
  }
}
