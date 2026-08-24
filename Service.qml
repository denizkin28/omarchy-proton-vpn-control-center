pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool installed: false
  property bool installationResolved: false
  property bool connected: false
  property bool needsLogin: false
  property bool authResolved: false
  property bool refreshing: false
  property string statusText: "Checking…"
  property string server: ""
  property string location: ""
  property string load: ""
  property string protocol: ""
  property string actionStatus: ""
  property string lastError: ""
  property bool lastErrorRetryable: false
  property var countries: []
  property var cities: []
  property string citiesCountryCode: ""
  property string locationError: ""
  property var serverResults: []
  property int serverResultTotal: 0
  property int serverCacheTotal: 0
  property var serverRegions: []
  property var serverMapCountries: []
  property bool enhancedServersAvailable: false
  property string enhancedServersError: ""
  property string enhancedHelperVersion: ""
  property string enhancedProtonVersion: ""
  property var configValues: ({})
  property bool configLoaded: false
  property string configError: ""
  property string exitIp: ""
  property string reportStatus: ""
  property string reportError: ""
  property bool dnsCompatibilityNeeded: false
  property string dnsCompatibilityStatus: ""
  property string dnsCompatibilityError: ""
  property string onboardingStatus: ""
  property string onboardingError: ""
  property var health: ({ interfaceUp: false, routeThroughVpn: false, protonDns: false, healthy: false, rxBytes: 0, txBytes: 0 })
  property bool healthResolved: false
  property string healthError: ""
  property var activeNetwork: ({ device: "", connection: "", type: "", online: false })
  property string automationStatus: ""
  property var portForward: ({ active: false, port: 0, status: "stopped", message: "", serviceInstalled: false, natPmpInstalled: false, configured: false, connected: false, requirements: "" })
  property string portForwardError: ""
  property var splitTunneling: ({ available: false, enabled: false, mode: "exclude", exclude: ({ app_paths: [], ip_ranges: [] }), include: ({ app_paths: [], ip_ranges: [] }) })
  property bool splitTunnelingResolved: false
  property string splitTunnelingError: ""
  property string profileStatus: ""
  property string profileError: ""
  property var installedApplications: []
  property string applicationsError: ""
  property var coreSettings: ({ protocol: "", killSwitch: 0, protocols: [], unavailableProtocols: [], advancedKillSwitchAvailable: false, splitTunnelingEnabled: false })
  property string coreSettingsError: ""
  property string recoveryStatus: ""
  property string diagnosticsStatus: ""
  property string diagnosticsError: ""
  property string diagnosticsPath: ""

  readonly property string cliCommand: String(setting("cliCommand", "protonvpn") || "protonvpn").trim()
  readonly property string dataHelper: Quickshell.env("HOME") + "/.config/omarchy/plugins/denizkin.protonvpn/protonvpn-data-helper"
  readonly property string systemHelper: Quickshell.env("HOME") + "/.config/omarchy/plugins/denizkin.protonvpn/protonvpn-system-helper"
  readonly property string signinHelper: Quickshell.env("HOME") + "/.config/omarchy/plugins/denizkin.protonvpn/protonvpn-signin-terminal"
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 5, 3600)
  readonly property bool busy: whichProcess.running || statusProcess.running || actionProcess.running || profileProcess.running
    || recoveryProcess.running || configActionProcess.running || integrationProcess.running || dnsCompatibilityBusy || onboardingBusy
  readonly property bool indicatorBusy: actionProcess.running || profileProcess.running || onboardingBusy
  readonly property string connectionAction: actionProcess.running ? _actionMode
    : profileProcess.running ? "connect"
    : onboardingBusy ? "signin" : ""
  readonly property bool healthDegraded: connected && healthResolved
    && (!health.interfaceUp || !health.routeThroughVpn || !health.protonDns)
  readonly property string indicatorState: needsLogin ? "login-required"
    : connectionAction === "disconnect" ? "disconnecting"
    : indicatorBusy ? "connecting"
    : connected && healthDegraded ? "degraded"
    : connected ? "connected"
    : activeNetwork.online ? "unprotected" : "offline"
  readonly property bool locationsBusy: countriesProcess.running || citiesProcess.running
  readonly property bool serverDataBusy: serverDataProcess.running
  readonly property bool configBusy: configListProcess.running || configActionProcess.running
  readonly property bool reportBusy: reportStatusProcess.running || publicIpProcess.running || browserProcess.running
  readonly property bool exitIpBusy: publicIpProcess.running
  readonly property bool openingReport: _openReportAfterLookup && reportBusy
  readonly property bool dnsCompatibilityBusy: dnsProbeProcess.running || dnsApplyProcess.running
  readonly property bool onboardingBusy: onboardingProcess.running || _onboardingMode === "signin"

  property string _statusOutput: ""
  property string _statusError: ""
  property string _actionOutput: ""
  property string _actionError: ""
  property string _actionMode: ""
  property var _retryCommand: []
  property string _retryLabel: ""
  property string _retryMode: ""
  property string _accountOutput: ""
  property string _countriesOutput: ""
  property string _countriesError: ""
  property string _citiesOutput: ""
  property string _citiesError: ""
  property string _serverDataOutput: ""
  property string _serverDataError: ""
  property bool _serverDataPending: false
  property string _serverQuery: ""
  property string _serverFeature: "any"
  property int _serverMaxLoad: 100
  property bool _serverAvailableOnly: true
  property string _serverCountry: ""
  property string _serverRegion: ""
  property string _activeCitiesCountryCode: ""
  property string _pendingCitiesCountryCode: ""
  property string _configOutput: ""
  property string _configErrorOutput: ""
  property string _configActionOutput: ""
  property string _configActionError: ""
  property string _reportStatusOutput: ""
  property string _reportStatusErrorOutput: ""
  property string _publicIpOutput: ""
  property string _publicIpErrorOutput: ""
  property string _browserErrorOutput: ""
  property bool _reportTimedOut: false
  property bool _pollTimedOut: false
  property bool _actionTimedOut: false
  property bool _locationTimedOut: false
  property bool _configTimedOut: false
  property bool _reportCancelled: false
  property bool _openReportAfterLookup: false
  property string _dnsProbeOutput: ""
  property string _dnsProbeErrorOutput: ""
  property string _dnsApplyErrorOutput: ""
  property bool _dnsCompatibilityTimedOut: false
  property string _onboardingErrorOutput: ""
  property string _onboardingMode: ""
  property int _onboardingPollCount: 0
  property string _healthOutput: ""
  property bool _healthRefreshPending: false
  property string _networkOutput: ""
  property string _integrationOutput: ""
  property string _integrationError: ""
  property string _integrationMode: ""
  property var _integrationQueue: []
  property string _recoveryOutput: ""
  property string _recoveryError: ""
  property double _lastAutoConnectAt: 0
  property double _lastAccountProbeAt: 0
  property bool _previousConnected: false
  property bool _intentionalDisconnect: false
  property string _lastConnectedServer: ""
  property int _lastForwardedPort: 0

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(min, Math.min(max, value))
  }

  function clearConnection() {
    connected = false
    healthResolved = false
    health = ({ interfaceUp: false, routeThroughVpn: false, protonDns: false, healthy: false, rxBytes: 0, txBytes: 0 })
    healthError = ""
    server = ""
    location = ""
    load = ""
    protocol = ""
    clearReport()
    clearDnsCompatibility()
  }

  function clearReport() {
    delayedExitIp.stop()
    reportWatchdog.stop()
    _reportCancelled = true
    if (reportStatusProcess.running) reportStatusProcess.running = false
    if (publicIpProcess.running) publicIpProcess.running = false
    if (browserProcess.running) browserProcess.running = false
    exitIp = ""
    reportStatus = ""
    reportError = ""
    _reportTimedOut = false
    _openReportAfterLookup = false
  }

  function openIpReport() {
    if (!connected) {
      reportError = "Connect Proton VPN before checking its exit IP"
      return false
    }
    if (reportBusy) return false
    _reportStatusOutput = ""
    _reportStatusErrorOutput = ""
    _publicIpOutput = ""
    _publicIpErrorOutput = ""
    _browserErrorOutput = ""
    _reportTimedOut = false
    _reportCancelled = false
    _openReportAfterLookup = true
    reportStatus = ""
    reportError = ""
    reportStatusProcess.command = [cliCommand, "status"]
    reportStatusProcess.running = true
    reportWatchdog.restart()
    return true
  }

  function refreshExitIp() {
    if (!connected || reportBusy) return false
    exitIp = ""
    _publicIpOutput = ""
    _publicIpErrorOutput = ""
    _reportTimedOut = false
    _reportCancelled = false
    _openReportAfterLookup = false
    reportStatus = ""
    reportError = ""
    return startPublicIpCheck()
  }

  function startPublicIpCheck() {
    var plan = Model.publicIpPlan("curl", "proton0")
    if (!plan.ok) {
      reportWatchdog.stop()
      _openReportAfterLookup = false
      reportError = plan.error
      return false
    }
    publicIpProcess.command = plan.command
    publicIpProcess.running = true
    reportWatchdog.restart()
    return true
  }

  function openBrowserForExitIp() {
    var plan = Model.abuseIpReportPlan("omarchy", exitIp)
    if (!plan.ok) {
      reportWatchdog.stop()
      _openReportAfterLookup = false
      reportError = plan.error
      return false
    }
    _browserErrorOutput = ""
    browserProcess.command = plan.command
    browserProcess.running = true
    reportWatchdog.restart()
    return true
  }

  function clearDnsCompatibility() {
    delayedDnsCompatibility.stop()
    dnsCompatibilityWatchdog.stop()
    if (dnsProbeProcess.running) dnsProbeProcess.running = false
    if (dnsApplyProcess.running) dnsApplyProcess.running = false
    dnsCompatibilityNeeded = false
    dnsCompatibilityStatus = ""
    dnsCompatibilityError = ""
    _dnsCompatibilityTimedOut = false
  }

  function inspectProtonDnsCompatibility() {
    if (!connected || dnsCompatibilityBusy) return false
    _dnsProbeOutput = ""
    _dnsProbeErrorOutput = ""
    _dnsApplyErrorOutput = ""
    _dnsCompatibilityTimedOut = false
    dnsCompatibilityNeeded = false
    dnsCompatibilityStatus = ""
    dnsCompatibilityError = ""
    dnsProbeProcess.command = ["resolvectl", "status", "proton0"]
    dnsProbeProcess.running = true
    dnsCompatibilityWatchdog.restart()
    return true
  }

  function allowProtonDnsCompatibility() {
    if (!connected || !dnsCompatibilityNeeded || dnsCompatibilityBusy) return false
    var plan = Model.dnsCompatibilityApplyPlan("nmcli", "proton0")
    if (!plan.ok) {
      dnsCompatibilityError = plan.error
      return false
    }
    _dnsApplyErrorOutput = ""
    _dnsCompatibilityTimedOut = false
    dnsCompatibilityStatus = "Allowing Proton DNS for this connection…"
    dnsCompatibilityError = ""
    dnsApplyProcess.command = plan.command
    dnsApplyProcess.running = true
    dnsCompatibilityWatchdog.restart()
    return true
  }

  function refresh() {
    if (installed) {
      refreshStatus()
      return
    }
    if (whichProcess.running) return
    refreshing = true
    whichProcess.command = ["which", cliCommand]
    whichProcess.running = true
  }

  function beginOnboardingPolling(mode) {
    _onboardingMode = mode
    _onboardingPollCount = 0
    onboardingPollTimer.restart()
  }

  function finishOnboardingPolling() {
    onboardingPollTimer.stop()
    _onboardingMode = ""
    _onboardingPollCount = 0
  }

  function installCli() {
    if (installed || onboardingBusy) return false
    var plan = Model.installCliPlan("omarchy")
    if (!plan.ok) {
      onboardingError = plan.error
      return false
    }
    _onboardingErrorOutput = ""
    onboardingError = ""
    onboardingStatus = "Opening the Omarchy installer…"
    lastError = ""
    onboardingProcess.command = plan.command
    onboardingProcess.running = true
    onboardingWatchdog.restart()
    _onboardingMode = "install"
    return true
  }

  function signIn(username) {
    if (!installed || onboardingBusy) return false
    var plan = Model.signinPlan("omarchy", cliCommand, username, signinHelper)
    if (!plan.ok) {
      onboardingError = plan.error
      return false
    }
    _onboardingErrorOutput = ""
    onboardingError = ""
    onboardingStatus = "Opening Proton sign-in in a terminal…"
    lastError = ""
    // Authentication may legitimately take minutes for password and 2FA.
    // Launch detached so the installer watchdog cannot terminate its terminal.
    Quickshell.execDetached(plan.command)
    onboardingStatus = "Complete sign-in in the Proton terminal; this panel will update automatically."
    beginOnboardingPolling("signin")
    return true
  }

  function refreshStatus() {
    if (!installed || statusProcess.running || actionProcess.running) return
    _statusOutput = ""
    _statusError = ""
    _pollTimedOut = false
    refreshing = true
    statusProcess.command = [cliCommand, "status"]
    statusProcess.running = true
    pollWatchdog.restart()
  }

  function refreshLocations() {
    if (!installed || countriesProcess.running) return
    _countriesOutput = ""
    _countriesError = ""
    _locationTimedOut = false
    locationError = ""
    countriesProcess.command = [cliCommand, "countries", "list"]
    countriesProcess.running = true
    locationWatchdog.restart()
  }

  function loadCities(countryCode) {
    var code = String(countryCode || "").trim().toUpperCase()
    if (!installed || code === "") return
    if (citiesProcess.running) {
      _pendingCitiesCountryCode = code
      return
    }
    if (citiesCountryCode === code && cities.length > 0) return
    _activeCitiesCountryCode = code
    _pendingCitiesCountryCode = ""
    _citiesOutput = ""
    _citiesError = ""
    _locationTimedOut = false
    locationError = ""
    cities = []
    citiesCountryCode = ""
    citiesProcess.command = [cliCommand, "cities", "list", code]
    citiesProcess.running = true
    locationWatchdog.restart()
  }

  function refreshServers(query, feature, maxLoad, availableOnly, country, region) {
    if (!installed) return false
    _serverQuery = String(query || "")
    _serverFeature = String(feature || "any").trim().toLowerCase().replace(/ /g, "-")
    _serverMaxLoad = Math.max(0, Math.min(100, parseInt(String(maxLoad || 100), 10) || 100))
    _serverAvailableOnly = Boolean(availableOnly)
    _serverCountry = String(country || "")
    _serverRegion = String(region || "")
    if (serverDataProcess.running) {
      _serverDataPending = true
      return true
    }
    _serverDataOutput = ""
    _serverDataError = ""
    enhancedServersError = ""
    _serverDataPending = false
    var command = [dataHelper, "--query=" + _serverQuery, "--feature", _serverFeature,
      "--max-load", String(_serverMaxLoad), "--limit", "100"]
    if (_serverCountry !== "") command.push("--country", _serverCountry)
    if (_serverRegion !== "") command.push("--region", _serverRegion)
    if (_serverAvailableOnly) command.push("--available-only")
    serverDataProcess.command = command
    serverDataProcess.running = true
    return true
  }

  function refreshHealth(forceFresh) {
    if (!installed || !connected) return
    if (healthProcess.running) {
      if (forceFresh === true) _healthRefreshPending = true
      return
    }
    _healthOutput = ""
    healthProcess.command = [systemHelper, "health"]
    healthProcess.running = true
  }

  function refreshNetwork() {
    if (!installed || networkProcess.running) return
    _networkOutput = ""
    networkProcess.command = [systemHelper, "network"]
    networkProcess.running = true
  }

  function networkIsTrusted(name) {
    var trusted = setting("trustedNetworks", [])
    if (!(trusted instanceof Array)) return false
    for (var i = 0; i < trusted.length; i++)
      if (String(trusted[i] || "") === String(name || "")) return true
    return false
  }

  function maybeAutoConnect() {
    if (!Boolean(setting("autoConnectUntrusted", false)) || connected || needsLogin || !installed
        || actionProcess.running || profileProcess.running || integrationProcess.running || configActionProcess.running) return
    if (!activeNetwork.online || networkIsTrusted(activeNetwork.connection)) return
    var now = Date.now()
    if (now - _lastAutoConnectAt < 120000) return
    _lastAutoConnectAt = now
    automationStatus = "Untrusted network detected; connecting Proton VPN…"
    var profileName = String(setting("autoConnectProfile", ""))
    var profiles = setting("profiles", [])
    if (profiles instanceof Array && profileName !== "") {
      for (var i = 0; i < profiles.length; i++) {
        if (String(profiles[i].name || "") === profileName) {
          applyProfile(profiles[i])
          return
        }
      }
    }
    connect("fastest", "", "none")
  }

  function applyProfile(profile) {
    if (!installed || profileProcess.running || actionProcess.running || integrationProcess.running || configActionProcess.running) return false
    profileStatus = "Applying " + String(profile.name || "VPN profile") + "…"
    profileError = ""
    _integrationOutput = ""
    _integrationError = ""
    profileProcess.command = [systemHelper, "profile-apply", "--cli", cliCommand,
      "--profile", JSON.stringify(profile)]
    profileProcess.running = true
    return true
  }

  function refreshApplications() { runIntegration("apps", [systemHelper, "apps"]) }
  function exportDiagnostics() {
    diagnosticsStatus = "Creating redacted diagnostic report…"
    diagnosticsError = ""
    runIntegration("diagnostics", [systemHelper, "diagnostics", "--cli", cliCommand])
  }
  function copyDiagnosticsPath() {
    if (diagnosticsPath === "") return
    Quickshell.execDetached(["wl-copy", "--type", "text/plain", diagnosticsPath])
    diagnosticsStatus = "Diagnostic path copied"
  }
  function openDiagnosticsFolder() {
    if (diagnosticsPath === "") return
    var slash = diagnosticsPath.lastIndexOf("/")
    Quickshell.execDetached(["xdg-open", slash > 0 ? diagnosticsPath.substring(0, slash) : diagnosticsPath])
  }
  function refreshCoreSettings() { runIntegration("settings-get", [systemHelper, "settings-get", "--cli", cliCommand]) }
  function setCoreSetting(name, value) {
    runIntegration("transaction-set", [systemHelper, "transaction-set", "--cli", cliCommand,
      "--operation", "settings", "--setting", String(name), "--value", String(value)])
  }

  function notify(title, message) {
    if (!Boolean(setting("vpnNotifications", false))) return
    Quickshell.execDetached(["notify-send", "--app-name", "Proton VPN Control Center", String(title), String(message)])
  }

  function refreshPortForward() { runIntegration("port-status", [systemHelper, "port-status", "--cli", cliCommand]) }
  function setPortForwardRunning(enabled) {
    runIntegration(enabled ? "port-start" : "port-stop",
      ["systemctl", "--user", enabled ? "start" : "stop", "proton-port-forward.service"])
  }
  function refreshSplitTunneling() { runIntegration("split-get", [systemHelper, "split-get", "--cli", cliCommand]) }
  function setSplitTunneling(enabled, mode, appPaths, ipRanges) {
    runIntegration("transaction-split", [systemHelper, "transaction-set", "--cli", cliCommand,
      "--operation", "split", "--enabled", enabled ? "on" : "off",
      "--mode", String(mode || "exclude"), "--apps", JSON.stringify(appPaths || []),
      "--ips", JSON.stringify(ipRanges || [])])
  }
  function runIntegration(mode, command) {
    if (integrationProcess.running) {
      for (var i = 0; i < _integrationQueue.length; i++)
        if (_integrationQueue[i].mode === mode) return true
      _integrationQueue = _integrationQueue.concat([{ mode: mode, command: command }])
      return true
    }
    _integrationMode = mode
    _integrationOutput = ""
    _integrationError = ""
    integrationProcess.command = command
    integrationProcess.running = true
    return true
  }

  function finishIntegration() {
    _integrationMode = ""
    if (_integrationQueue.length === 0) return
    var pending = _integrationQueue[0]
    _integrationQueue = _integrationQueue.slice(1)
    Qt.callLater(function() { root.runIntegration(pending.mode, pending.command) })
  }

  function refreshConfig() {
    if (!installed || configListProcess.running || configActionProcess.running) return
    _configOutput = ""
    _configErrorOutput = ""
    _configTimedOut = false
    configError = ""
    configListProcess.command = [cliCommand, "config", "list"]
    configListProcess.running = true
    configWatchdog.restart()
  }

  function setConfig(settingName, value, dnsServers) {
    if (!installed || configActionProcess.running || actionProcess.running) return false
    var plan = Model.configPlan(cliCommand, settingName, value, dnsServers)
    if (!plan.ok) {
      configError = plan.error
      lastError = plan.error
      return false
    }
    _configActionOutput = ""
    _configActionError = ""
    _configTimedOut = false
    configError = ""
    lastError = ""
    actionStatus = "Updating " + String(settingName || "setting") + "…"
    configActionProcess.command = plan.command
    configActionProcess.running = true
    configWatchdog.restart()
    return true
  }

  function connect(mode, target, feature) {
    if (!installed || actionProcess.running || configActionProcess.running || integrationProcess.running || profileProcess.running) return false
    var plan = Model.connectPlan(cliCommand, mode, target, feature)
    if (!plan.ok) {
      lastError = plan.error
      return false
    }
    runAction(plan.command, "Connecting…", "connect")
    return true
  }

  function disconnect() {
    if (!installed || !connected || actionProcess.running || configActionProcess.running || integrationProcess.running || profileProcess.running) return false
    _intentionalDisconnect = true
    runAction([systemHelper, "disconnect", "--cli", cliCommand], "Disconnecting…", "disconnect")
    return true
  }

  function signOut() {
    if (!installed || connected || actionProcess.running) return false
    runAction([cliCommand, "signout"], "Signing out…", "signout")
    return true
  }

  function toggle() {
    if (integrationProcess.running || profileProcess.running || configActionProcess.running) return false
    return connected ? disconnect() : connect("fastest", "", "none")
  }

  function runAction(command, label, mode) {
    _actionOutput = ""
    _actionError = ""
    lastError = ""
    lastErrorRetryable = false
    _actionTimedOut = false
    actionStatus = label
    _actionMode = String(mode || "")
    if (_actionMode === "connect") {
      _retryCommand = command.slice(0)
      _retryLabel = label
      _retryMode = _actionMode
    }
    actionProcess.command = command
    actionProcess.running = true
    actionWatchdog.restart()
  }

  function retryLastAction() {
    if (!lastErrorRetryable || _retryCommand.length === 0 || busy) return false
    runAction(_retryCommand.slice(0), _retryLabel || "Connecting…", _retryMode || "connect")
    return true
  }

  function scheduleRecovery() {
    if (!Boolean(setting("recoverUnexpectedDrops", false)) || _intentionalDisconnect || recoveryProcess.running) return
    recoveryStatus = "Unexpected VPN loss detected; recovery scheduled…"
    recoveryTimer.restart()
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: recoveryTimer
    interval: 2500
    repeat: false
    onTriggered: {
      root._recoveryOutput = ""
      root._recoveryError = ""
      recoveryProcess.command = [systemHelper, "recover", "--cli", cliCommand,
        "--server", root._lastConnectedServer, "--cooldown", "120"]
      recoveryProcess.running = true
      root.recoveryStatus = "Restoring VPN connection…"
    }
  }

  Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: { root.refreshHealth(); root.refreshNetwork() }
  }

  Timer {
    id: delayedHealthValidation
    interval: 1200
    repeat: false
    onTriggered: root.refreshHealth(true)
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.portForward.active
    onTriggered: root.refreshPortForward()
  }

  Timer {
    id: delayedRefresh
    interval: 700
    repeat: false
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: onboardingPollTimer
    interval: 3000
    repeat: true
    onTriggered: {
      root._onboardingPollCount += 1
      if (root._onboardingPollCount >= 100) {
        root.finishOnboardingPolling()
        root.onboardingStatus = "Use Refresh after completing the terminal step."
      } else {
        root.refresh()
      }
    }
  }

  Timer {
    id: onboardingWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (onboardingProcess.running) onboardingProcess.running = false
      root.onboardingError = "Could not open the Omarchy terminal"
      root.finishOnboardingPolling()
    }
  }

  Timer {
    id: delayedDnsCompatibility
    interval: 1000
    repeat: false
    onTriggered: root.inspectProtonDnsCompatibility()
  }

  Timer {
    id: delayedExitIp
    interval: 2200
    repeat: false
    onTriggered: root.refreshExitIp()
  }

  Timer {
    id: dnsCompatibilityWatchdog
    interval: 10000
    repeat: false
    onTriggered: {
      root._dnsCompatibilityTimedOut = true
      if (dnsProbeProcess.running) dnsProbeProcess.running = false
      if (dnsApplyProcess.running) dnsApplyProcess.running = false
      root.dnsCompatibilityStatus = ""
      root.dnsCompatibilityError = "Proton DNS compatibility check timed out"
    }
  }

  Timer {
    id: pollWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (statusProcess.running) {
        root._pollTimedOut = true
        statusProcess.running = false
        root.refreshing = false
        root.lastError = "Status check timed out"
        root.lastErrorRetryable = false
      }
    }
  }

  Timer {
    id: actionWatchdog
    interval: 60000
    repeat: false
    onTriggered: {
      if (actionProcess.running) {
        root._actionTimedOut = true
        actionProcess.running = false
        root.actionStatus = ""
        root.lastError = "Proton VPN command timed out"
        root.lastErrorRetryable = root._retryCommand.length > 0
        root._actionMode = ""
      }
    }
  }

  Timer {
    id: locationWatchdog
    interval: 30000
    repeat: false
    onTriggered: {
      root._locationTimedOut = true
      if (countriesProcess.running) countriesProcess.running = false
      if (citiesProcess.running) citiesProcess.running = false
      root.locationError = "Location list timed out"
    }
  }

  Timer {
    id: delayedConfigRefresh
    interval: 500
    repeat: false
    onTriggered: root.refreshConfig()
  }

  Timer {
    id: actionMessageTimer
    interval: 4500
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Timer {
    id: configWatchdog
    interval: 30000
    repeat: false
    onTriggered: {
      root._configTimedOut = true
      if (configListProcess.running) configListProcess.running = false
      if (configActionProcess.running) configActionProcess.running = false
      root.actionStatus = ""
      root.configError = "Proton VPN configuration command timed out"
      root.lastError = root.configError
      root.lastErrorRetryable = false
    }
  }

  Timer {
    id: reportWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      root._reportTimedOut = true
      if (reportStatusProcess.running) reportStatusProcess.running = false
      if (publicIpProcess.running) publicIpProcess.running = false
      if (browserProcess.running) browserProcess.running = false
      root.reportError = root._openReportAfterLookup ? "Opening the IP report timed out" : "Exit IP lookup timed out"
      root._openReportAfterLookup = false
    }
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      root.installationResolved = true
      if (root.installed) root.refreshStatus()
      else {
        root.refreshing = false
        root.clearConnection()
        root.needsLogin = false
        root.authResolved = true
        root.statusText = "CLI not installed"
      }
    }
  }

  Process {
    id: onboardingProcess
    running: false
    command: []
    stderr: StdioCollector {
      id: onboardingStderr
      waitForEnd: true
      onStreamFinished: root._onboardingErrorOutput = text
    }
    onExited: function(exitCode) {
      onboardingWatchdog.stop()
      var stderr = String(onboardingStderr.text || root._onboardingErrorOutput || "")
      if (exitCode !== 0) {
        if (root._onboardingMode === "signin") {
          root.onboardingError = ""
          root.onboardingStatus = "Complete sign-in in the Proton terminal; this panel will update automatically."
          root.beginOnboardingPolling("signin")
          return
        }
        root.onboardingStatus = ""
        root.onboardingError = Model.classifyFailure(stderr).message
        root.finishOnboardingPolling()
        return
      }

      var mode = root._onboardingMode
      root.onboardingStatus = mode === "install"
        ? "Finish installation in the terminal; detection is automatic."
        : "Finish sign-in in the terminal; detection is automatic."
      root.beginOnboardingPolling(mode)
      root.refresh()
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
      onStreamFinished: root._statusOutput = text
    }
    stderr: StdioCollector {
      id: statusStderr
      waitForEnd: true
      onStreamFinished: root._statusError = text
    }
    onExited: function(exitCode) {
      pollWatchdog.stop()
      root.refreshing = false
      if (root._pollTimedOut) return
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      if (exitCode === 0) {
        var parsed = Model.parseStatus(stdout)
        if (parsed.ok) {
          var wasConnected = root._previousConnected
          var connectionChanged = parsed.connected && (!root.connected || root.server !== parsed.server)
          var clearExitIp = !parsed.connected || connectionChanged
          root.connected = parsed.connected
          if (clearExitIp) {
            root.clearReport()
            root.clearDnsCompatibility()
          }
          // `protonvpn status` reports Disconnected for both signed-in and
          // signed-out accounts. Preserve the last resolved auth state until
          // `protonvpn info` resolves that ambiguity; otherwise the main panel
          // flashes between two account probes.
          if (parsed.connected) root.needsLogin = false
          root.statusText = (!parsed.connected && root.needsLogin) ? "Needs sign-in" : parsed.statusText
          root.server = parsed.server
          root.location = parsed.location
          root.load = parsed.load
          root.protocol = parsed.protocol
          root._previousConnected = parsed.connected
          if (parsed.connected) {
            root.authResolved = true
            root._lastConnectedServer = parsed.server
            root._intentionalDisconnect = false
            root.recoveryStatus = ""
          } else if (wasConnected) {
            root.scheduleRecovery()
            root._intentionalDisconnect = false
          }
          root.lastError = ""
          root.lastErrorRetryable = false
          var now = Date.now()
          var accountProbeDue = !root.authResolved || root._onboardingMode !== ""
            || now - root._lastAccountProbeAt >= 300000
          if (!parsed.connected && !accountProcess.running && accountProbeDue) {
            root._accountOutput = ""
            root._lastAccountProbeAt = now
            accountProcess.command = [root.systemHelper, "account", "--cli", root.cliCommand]
            accountProcess.running = true
          }
          if (root._onboardingMode !== "" && parsed.connected) {
            root.finishOnboardingPolling()
            root.onboardingStatus = "Proton VPN is ready."
            root.onboardingError = ""
          }
          if (connectionChanged) {
            root.healthResolved = false
            delayedHealthValidation.restart()
            delayedDnsCompatibility.restart()
            delayedExitIp.restart()
          }
        } else {
          root.clearConnection()
          root.statusText = "Status unavailable"
          root.lastError = parsed.message
          root.lastErrorRetryable = false
        }
      } else {
        var failure = Model.classifyFailure(stderr || stdout)
        root.clearConnection()
        root.needsLogin = failure.needsLogin
        root.statusText = failure.needsLogin ? "Needs sign-in" : "Status unavailable"
        root.lastError = failure.message
        root.lastErrorRetryable = false
        if (failure.needsLogin && root._onboardingMode === "install") {
          root.finishOnboardingPolling()
          root.onboardingStatus = "CLI installed. Sign in to continue."
          root.onboardingError = ""
        }
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: actionStdout
      waitForEnd: true
      onStreamFinished: root._actionOutput = text
    }
    stderr: StdioCollector {
      id: actionStderr
      waitForEnd: true
      onStreamFinished: root._actionError = text
    }
    onExited: function(exitCode) {
      actionWatchdog.stop()
      if (root._actionTimedOut) return
      var stdout = String(actionStdout.text || root._actionOutput || "")
      var stderr = String(actionStderr.text || root._actionError || "")
      root.actionStatus = ""
      if (exitCode === 0) {
        root.lastError = ""
        root.lastErrorRetryable = false
        root._retryCommand = []
        root._retryLabel = ""
        root._retryMode = ""
        if (root._actionMode === "signout") {
          root.clearConnection()
          root.needsLogin = true
          root.authResolved = true
          root.statusText = "Needs sign-in"
          root.onboardingStatus = "Signed out successfully."
          root.actionStatus = "Signed out successfully"
          actionMessageTimer.restart()
        } else {
          delayedRefresh.restart()
        }
      } else {
        var failure = Model.classifyFailure(stderr || stdout)
        root.needsLogin = failure.needsLogin
        root.lastError = failure.message
        root.lastErrorRetryable = failure.retryable && root._retryCommand.length > 0
      }
      root._actionMode = ""
    }
  }

  Process {
    id: accountProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._accountOutput = text }
    onExited: function(exitCode) {
      if (exitCode === 3 || exitCode === 4) {
        root.clearConnection()
        root.needsLogin = true
        root.statusText = "Needs sign-in"
        if (exitCode === 4 && root._onboardingMode === "")
          root.onboardingStatus = "The stored Proton CLI session expired. Sign in again to continue."
      } else if (exitCode === 0) {
        root.needsLogin = false
        if (root._onboardingMode === "signin") {
          root.finishOnboardingPolling()
          root.onboardingStatus = "Signed in successfully."
          root.onboardingError = ""
        }
      }
      root.authResolved = true
    }
  }

  Process {
    id: countriesProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: countriesStdout
      waitForEnd: true
      onStreamFinished: root._countriesOutput = text
    }
    stderr: StdioCollector {
      id: countriesStderr
      waitForEnd: true
      onStreamFinished: root._countriesError = text
    }
    onExited: function(exitCode) {
      if (!citiesProcess.running) locationWatchdog.stop()
      if (root._locationTimedOut) return
      var stdout = String(countriesStdout.text || root._countriesOutput || "")
      var stderr = String(countriesStderr.text || root._countriesError || "")
      if (exitCode === 0) {
        var parsed = Model.parseCountries(stdout)
        if (parsed.length > 0) {
          root.countries = parsed
          root.locationError = ""
        } else {
          root.locationError = "No countries returned by Proton VPN"
        }
      } else {
        root.locationError = Model.classifyFailure(stderr || stdout).message
      }
    }
  }

  Process {
    id: citiesProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: citiesStdout
      waitForEnd: true
      onStreamFinished: root._citiesOutput = text
    }
    stderr: StdioCollector {
      id: citiesStderr
      waitForEnd: true
      onStreamFinished: root._citiesError = text
    }
    onExited: function(exitCode) {
      locationWatchdog.stop()
      if (root._locationTimedOut) return
      var completedCode = root._activeCitiesCountryCode
      var stdout = String(citiesStdout.text || root._citiesOutput || "")
      var stderr = String(citiesStderr.text || root._citiesError || "")
      if (root._pendingCitiesCountryCode !== "" && root._pendingCitiesCountryCode !== completedCode) {
        var pendingCode = root._pendingCitiesCountryCode
        root._pendingCitiesCountryCode = ""
        Qt.callLater(function() { root.loadCities(pendingCode) })
      } else if (exitCode === 0) {
        root.cities = Model.parseCities(stdout)
        root.citiesCountryCode = completedCode
        root.locationError = root.cities.length > 0 ? "" : "No cities available for this country"
      } else {
        root.locationError = Model.classifyFailure(stderr || stdout).message
      }
    }
  }

  Process {
    id: serverDataProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: serverDataStdout
      waitForEnd: true
      onStreamFinished: root._serverDataOutput = text
    }
    stderr: StdioCollector {
      id: serverDataStderr
      waitForEnd: true
      onStreamFinished: root._serverDataError = text
    }
    onExited: function(exitCode) {
      var stdout = String(serverDataStdout.text || root._serverDataOutput || "")
      var stderr = String(serverDataStderr.text || root._serverDataError || "")
      try {
        var result = JSON.parse(stdout)
        if (result.schemaVersion !== 1) throw new Error("Unsupported helper schema")
        root.enhancedHelperVersion = String(result.helperVersion || "")
        root.enhancedProtonVersion = String(result.protonPackageVersion || "")
        if (!result.ok) {
          root.enhancedServersAvailable = false
          root.enhancedServersError = String(result.error || result.detail || "Enhanced server data is unavailable")
          root.serverResults = []
          root.serverResultTotal = 0
          return
        }
        root.enhancedServersAvailable = true
        root.enhancedServersError = ""
        root.serverResults = result.servers instanceof Array ? result.servers : []
        root.serverRegions = result.regions instanceof Array ? result.regions : []
        root.serverMapCountries = result.mapCountries instanceof Array ? result.mapCountries : []
        root.serverResultTotal = Number(result.total || 0)
        root.serverCacheTotal = Number(result.cacheTotal || 0)
      } catch (error) {
        root.enhancedServersAvailable = false
        root.enhancedServersError = stderr !== "" ? Model.classifyFailure(stderr).message : "Enhanced server data is incompatible; manual server entry remains available"
        root.serverResults = []
        root.serverMapCountries = []
        root.serverResultTotal = 0
      }
      if (root._serverDataPending) Qt.callLater(function() {
        root.refreshServers(root._serverQuery, root._serverFeature, root._serverMaxLoad, root._serverAvailableOnly,
          root._serverCountry, root._serverRegion)
      })
    }
  }

  Process {
    id: healthProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._healthOutput = text }
    onExited: function(exitCode) {
      try {
        var result = JSON.parse(root._healthOutput)
        if (!result.ok || result.schemaVersion !== 1) throw new Error(result.error || "Health helper failed")
        root.health = result.health
        root.healthError = ""
      } catch (error) {
        root.healthError = "Connection health is unavailable"
      }
      if (root._healthRefreshPending) {
        root._healthRefreshPending = false
        root.healthResolved = false
        Qt.callLater(function() { root.refreshHealth() })
      } else {
        root.healthResolved = true
      }
    }
  }

  Process {
    id: networkProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._networkOutput = text }
    onExited: function(exitCode) {
      try {
        var result = JSON.parse(root._networkOutput)
        if (!result.ok || result.schemaVersion !== 1) throw new Error(result.error || "Network helper failed")
        root.activeNetwork = result.network
        root.maybeAutoConnect()
      } catch (error) {
        root.activeNetwork = ({ device: "", connection: "", type: "", online: false })
      }
    }
  }

  Process {
    id: profileProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._integrationOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root._integrationError = text }
    onExited: function(exitCode) {
      try {
        var result = JSON.parse(root._integrationOutput)
        if (!result.ok) throw new Error(result.error || "Profile failed")
        root.profileStatus = "Profile applied"
        root.profileError = ""
        root.automationStatus = ""
        delayedRefresh.restart()
      } catch (error) {
        root.profileStatus = ""
        root.profileError = String(error.message || root._integrationError || "Profile failed")
      }
    }
  }

  Process {
    id: integrationProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._integrationOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root._integrationError = text }
    onExited: function(exitCode) {
      var mode = root._integrationMode
      if (mode === "port-start" || mode === "port-stop") {
        if (exitCode === 0) {
          root.portForwardError = ""
          Qt.callLater(root.refreshPortForward)
        } else {
          root.portForwardError = Model.classifyFailure(root._integrationError).message
        }
        root.finishIntegration()
        return
      }
      try {
        var result = JSON.parse(root._integrationOutput)
        if (!result.ok) throw new Error(result.error || "Integration command failed")
        if (mode === "port-status") {
          var oldPort = root._lastForwardedPort
          root.portForward = result.portForward
          root._lastForwardedPort = Number(result.portForward.port || 0)
          if (root._lastForwardedPort > 0 && root._lastForwardedPort !== oldPort)
            root.notify("Forwarded port ready", "Port " + root._lastForwardedPort + " is active")
          root.portForwardError = ""
        } else if (mode === "apps") {
          root.installedApplications = result.applications instanceof Array ? result.applications : []
          root.applicationsError = ""
        } else if (mode === "diagnostics") {
          root.diagnosticsPath = String(result.diagnostics.path || "")
          root.diagnosticsStatus = "Redacted diagnostic report saved"
          root.diagnosticsError = ""
        } else if (mode === "settings-get") {
          root.coreSettings = result.coreSettings
          root.coreSettingsError = ""
        } else if (mode === "settings-set" || mode === "transaction-set") {
          root.coreSettingsError = ""
          root.actionStatus = result.transaction && result.transaction.reconnected
            ? "VPN setting applied and the previous server restored"
            : "VPN setting applied"
          actionMessageTimer.restart()
          Qt.callLater(root.refreshCoreSettings)
          delayedRefresh.restart()
        } else if (mode === "split-get" || mode === "split-set" || mode === "transaction-split") {
          if (result.splitTunneling && result.splitTunneling.available !== undefined) root.splitTunneling = result.splitTunneling
          root.splitTunnelingResolved = true
          root.splitTunnelingError = ""
          if (mode !== "split-get") {
            root.actionStatus = result.transaction && result.transaction.reconnected
              ? "Split tunnelling updated and the previous server restored"
              : "Split tunnelling updated"
            actionMessageTimer.restart()
          }
          if (mode !== "split-get") Qt.callLater(root.refreshSplitTunneling)
          delayedRefresh.restart()
        }
      } catch (error) {
        var message = String(error.message || root._integrationError || "Integration command failed")
        if (mode.indexOf("port-") === 0) root.portForwardError = message
        else if (mode === "apps") root.applicationsError = message
        else if (mode === "diagnostics") { root.diagnosticsStatus = ""; root.diagnosticsError = message }
        else if (mode.indexOf("settings-") === 0 || mode === "transaction-set") root.coreSettingsError = message
        else {
          root.splitTunnelingError = message
          if (mode === "split-get") root.splitTunnelingResolved = true
        }
      }
      root.finishIntegration()
    }
  }

  Process {
    id: recoveryProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._recoveryOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root._recoveryError = text }
    onExited: function(exitCode) {
      try {
        var result = JSON.parse(root._recoveryOutput)
        if (!result.ok) throw new Error(result.error || "Recovery failed")
        root.recoveryStatus = "VPN connection restored"
        root.notify("VPN restored", "Connected using " + String(result.server || "Proton VPN"))
        delayedRefresh.restart()
      } catch (error) {
        root.recoveryStatus = String(error.message || "VPN recovery failed")
        root.notify("VPN recovery failed", root.recoveryStatus)
      }
    }
  }

  Process {
    id: configListProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: configStdout
      waitForEnd: true
      onStreamFinished: root._configOutput = text
    }
    stderr: StdioCollector {
      id: configStderr
      waitForEnd: true
      onStreamFinished: root._configErrorOutput = text
    }
    onExited: function(exitCode) {
      configWatchdog.stop()
      if (root._configTimedOut) return
      var stdout = String(configStdout.text || root._configOutput || "")
      var stderr = String(configStderr.text || root._configErrorOutput || "")
      if (exitCode === 0) {
        var parsed = Model.parseConfig(stdout)
        root.configValues = parsed
        root.configLoaded = Object.keys(parsed).length > 0
        root.configError = root.configLoaded ? "" : "No Proton VPN settings returned"
      } else {
        root.configError = Model.classifyFailure(stderr || stdout).message
        root.lastError = root.configError
        root.lastErrorRetryable = false
      }
    }
  }

  Process {
    id: configActionProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: configActionStdout
      waitForEnd: true
      onStreamFinished: root._configActionOutput = text
    }
    stderr: StdioCollector {
      id: configActionStderr
      waitForEnd: true
      onStreamFinished: root._configActionError = text
    }
    onExited: function(exitCode) {
      configWatchdog.stop()
      if (root._configTimedOut) return
      var stdout = String(configActionStdout.text || root._configActionOutput || "")
      var stderr = String(configActionStderr.text || root._configActionError || "")
      if (exitCode === 0) {
        root.configError = ""
        root.lastError = ""
        root.actionStatus = String(stdout || "Setting updated").replace(/\s+/g, " ").trim()
        actionMessageTimer.restart()
        delayedConfigRefresh.restart()
      } else {
        root.actionStatus = ""
        root.configError = Model.classifyFailure(stderr || stdout).message
        root.lastError = root.configError
        root.lastErrorRetryable = false
      }
    }
  }

  Process {
    id: dnsProbeProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: dnsProbeStdout
      waitForEnd: true
      onStreamFinished: root._dnsProbeOutput = text
    }
    stderr: StdioCollector {
      id: dnsProbeStderr
      waitForEnd: true
      onStreamFinished: root._dnsProbeErrorOutput = text
    }
    onExited: function(exitCode) {
      if (root._dnsCompatibilityTimedOut) return
      var stdout = String(dnsProbeStdout.text || root._dnsProbeOutput || "")
      var stderr = String(dnsProbeStderr.text || root._dnsProbeErrorOutput || "")
      if (exitCode !== 0) {
        dnsCompatibilityWatchdog.stop()
        root.dnsCompatibilityError = "Could not inspect Proton DNS: " + Model.classifyFailure(stderr || stdout).message
        return
      }

      var result = Model.dnsCompatibilityProbe(stdout, "proton0")
      if (!result.ok) {
        dnsCompatibilityWatchdog.stop()
        root.dnsCompatibilityError = result.error
      } else {
        dnsCompatibilityWatchdog.stop()
        root.dnsCompatibilityNeeded = result.needed
        root.dnsCompatibilityError = ""
      }
    }
  }

  Process {
    id: dnsApplyProcess
    running: false
    command: []
    stderr: StdioCollector {
      id: dnsApplyStderr
      waitForEnd: true
      onStreamFinished: root._dnsApplyErrorOutput = text
    }
    onExited: function(exitCode) {
      dnsCompatibilityWatchdog.stop()
      if (root._dnsCompatibilityTimedOut) return
      var stderr = String(dnsApplyStderr.text || root._dnsApplyErrorOutput || "")
      if (exitCode === 0) {
        root.dnsCompatibilityNeeded = false
        root.dnsCompatibilityStatus = "Proton DNS is allowed for this connection."
        root.dnsCompatibilityError = ""
      } else {
        root.dnsCompatibilityStatus = ""
        root.dnsCompatibilityError = "Could not enable Proton DNS: " + Model.classifyFailure(stderr).message
      }
    }
  }

  Process {
    id: reportStatusProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: reportStatusStdout
      waitForEnd: true
      onStreamFinished: root._reportStatusOutput = text
    }
    stderr: StdioCollector {
      id: reportStatusStderr
      waitForEnd: true
      onStreamFinished: root._reportStatusErrorOutput = text
    }
    onExited: function(exitCode) {
      if (root._reportTimedOut || root._reportCancelled) return
      var stdout = String(reportStatusStdout.text || root._reportStatusOutput || "")
      var stderr = String(reportStatusStderr.text || root._reportStatusErrorOutput || "")
      if (exitCode !== 0) {
        reportWatchdog.stop()
        root._openReportAfterLookup = false
        root.reportError = Model.classifyFailure(stderr || stdout).message
        return
      }

      var parsed = Model.parseStatus(stdout)
      if (!parsed.ok) {
        reportWatchdog.stop()
        root._openReportAfterLookup = false
        root.reportError = parsed.message
        return
      }
      if (!parsed.connected) {
        root.clearConnection()
        root.statusText = "Disconnected"
        root.reportError = "Proton VPN disconnected before opening the IP report"
        root.lastError = root.reportError
        return
      }

      var connectionChanged = !root.connected || root.server !== parsed.server
      if (connectionChanged) root.exitIp = ""
      root.connected = true
      root.needsLogin = false
      root.statusText = parsed.statusText
      root.server = parsed.server
      root.location = parsed.location
      root.load = parsed.load
      root.protocol = parsed.protocol
      root.lastError = ""
      if (root.exitIp !== "") root.openBrowserForExitIp()
      else root.startPublicIpCheck()
    }
  }

  Process {
    id: publicIpProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: publicIpStdout
      waitForEnd: true
      onStreamFinished: root._publicIpOutput = text
    }
    stderr: StdioCollector {
      id: publicIpStderr
      waitForEnd: true
      onStreamFinished: root._publicIpErrorOutput = text
    }
    onExited: function(exitCode) {
      if (root._reportTimedOut || root._reportCancelled) return
      var stdout = String(publicIpStdout.text || root._publicIpOutput || "")
      var stderr = String(publicIpStderr.text || root._publicIpErrorOutput || "")
      var parsed = Model.parsePublicIpResult(exitCode, stdout, stderr)
      if (parsed.ok && root.connected) {
        root.exitIp = parsed.ip
        if (root._openReportAfterLookup) {
          root.openBrowserForExitIp()
        } else {
          reportWatchdog.stop()
          root.reportStatus = ""
          root.reportError = ""
        }
      } else if (root.connected) {
        reportWatchdog.stop()
        root._openReportAfterLookup = false
        root.reportError = "Could not determine exit IP: " + parsed.error
      }
    }
  }

  Process {
    id: browserProcess
    running: false
    command: []
    stderr: StdioCollector {
      id: browserStderr
      waitForEnd: true
      onStreamFinished: root._browserErrorOutput = text
    }
    onExited: function(exitCode) {
      reportWatchdog.stop()
      if (root._reportTimedOut || root._reportCancelled) return
      var stderr = String(browserStderr.text || root._browserErrorOutput || "")
      if (exitCode === 0 && root.connected) {
        root.reportStatus = "Opened AbuseIPDB report"
        root.reportError = ""
      } else if (root.connected) {
        root.reportStatus = ""
        root.reportError = Model.classifyFailure(stderr).message
      }
      root._openReportAfterLookup = false
    }
  }
}
