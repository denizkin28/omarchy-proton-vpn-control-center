const assert = require("node:assert/strict")
const crypto = require("node:crypto")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const root = path.resolve(__dirname, "..")
const panel = fs.readFileSync(path.join(root, "Panel.qml"), "utf8")
const service = fs.readFileSync(path.join(root, "Service.qml"), "utf8")
const icon = fs.readFileSync(path.join(root, "ProtonVpnIcon.qml"), "utf8")
const systemHelper = fs.readFileSync(path.join(root, "protonvpn-system-helper"), "utf8")

test("background polling does not pulse the VPN indicator", () => {
  const indicatorBusy = service.match(/readonly property bool indicatorBusy:\s*([^\n]+)/)

  assert.ok(indicatorBusy, "Service.qml must expose the indicator-specific busy state")
  assert.match(indicatorBusy[1], /actionProcess\.running/)
  assert.doesNotMatch(
    indicatorBusy[1],
    /whichProcess|statusProcess|configActionProcess|dnsCompatibilityBusy/,
    "passive detection, polling, configuration, and DNS work must not animate the connection indicator"
  )

  const iconBindings = [...panel.matchAll(/busy:\s*vpn\.indicatorBusy/g)]
  assert.equal(iconBindings.length, 2, "both VPN indicators must use the stable indicator busy state")
})

test("all monitor panels share one VPN service singleton", () => {
  const qmldir = fs.readFileSync(path.join(root, "qmldir"), "utf8")
  assert.match(service, /^pragma Singleton/)
  assert.match(qmldir, /singleton VpnService 1\.0 Service\.qml/)
  assert.match(panel, /readonly property var vpn: ProtonPlugin\.VpnService/)
  assert.match(panel, /onSettingsChanged: vpn\.settings = root\.settings/)
  assert.match(panel, /vpn\.acquire\(root\.settings\)/)
  assert.match(panel, /Component\.onDestruction: vpn\.release\(\)/)
  assert.match(service, /running: root\.clientCount > 0/)
  assert.doesNotMatch(panel, /\n\s*Service \{/)
  assert.match(panel, /function isAutomaticSettingsWriter\(\)/)
  assert.match(panel, /root\.bar\.moduleWidgets\(root\.moduleName\)/)
  assert.match(panel, /function recordConnectedServer\(\) \{\s*if \(!root\.isAutomaticSettingsWriter\(\)\) return/)
})

test("background probes back off when their data is not useful", () => {
  assert.match(service, /function refreshHealth\(forceFresh\) \{\s*if \(!installed \|\| !connected\) return/)
  assert.match(service, /function refreshNetwork\(\) \{\s*if \(!installed \|\| networkProcess\.running\) return/)
  assert.match(service, /now - root\._lastAccountProbeAt >= 300000/)
  assert.match(service, /root\._lastAccountProbeAt = now/)
})

test("connect and disconnect actions show an animated in-progress state", () => {
  assert.match(service, /runAction\(plan\.command, "Connecting…", "connect"\)/)
  assert.match(service, /runAction\(\[systemHelper, "disconnect", "--cli", cliCommand\], "Disconnecting…", "disconnect"\)/)
  assert.match(service, /connectionAction === "disconnect" \? "disconnecting"/)
  assert.match(icon, /SequentialAnimation on opacity/)
  assert.match(icon, /SequentialAnimation on scale/)
  assert.match(panel, /vpn\.indicatorBusy \? \(vpn\.actionStatus \|\| "Working…"\)/)
  assert.match(panel, /vpn\.connectionAction === "disconnect" \? "Disconnecting…"/)
  assert.match(panel, /vpn\.connectionAction === "connect" \? "Connecting…"/)
})

test("retryable connection failures preserve and replay the validated action", () => {
  assert.match(service, /property bool lastErrorRetryable: false/)
  assert.match(service, /function retryLastAction\(\)/)
  assert.match(service, /root\._actionMode === "connect" && failure\.retryable && root\._retryCommand\.length > 0/)
  assert.match(service, /else \{\s*_retryCommand = \[\]/)
  assert.match(panel, /visible: vpn\.lastErrorRetryable/)
  assert.match(panel, /onClicked: vpn\.retryLastAction\(\)/)
})

test("connection entry points cannot race settings transactions", () => {
  assert.match(service, /actionProcess\.running \|\| configActionProcess\.running \|\| integrationProcess\.running \|\| profileProcess\.running/)
  assert.match(service, /function toggle\(\) \{\s*if \(integrationProcess\.running \|\| profileProcess\.running \|\| configActionProcess\.running\) return false/)
  assert.match(service, /maybeAutoConnect[\s\S]{0,350}integrationProcess\.running/)
})

test("watchdog timeouts survive process exit callbacks", () => {
  for (const state of ["poll", "action", "location", "config"]) {
    assert.match(service, new RegExp(`property bool _${state}TimedOut: false`))
    assert.match(service, new RegExp(`root\\._${state}TimedOut = true`))
    assert.match(service, new RegExp(`if \\(root\\._${state}TimedOut\\) return`))
  }
})

test("waits for fresh health data before warning after connection", () => {
  assert.match(service, /property bool healthResolved: false/)
  assert.match(service, /connected && healthResolved/)
  assert.match(service, /root\.healthResolved = false\s+delayedHealthValidation\.restart\(\)/)
  assert.match(service, /onTriggered: root\.refreshHealth\(true\)/)
  assert.match(panel, /!vpn\.healthResolved \? "Verifying…"/)
})

test("uses the official gradient and the white Simple Icons silhouette", () => {
  const asset = fs.readFileSync(path.join(root, "assets", "VPN-logomark-noborder.svg"))
  const disconnectedAsset = fs.readFileSync(path.join(root, "assets", "proton-vpn-simple-white.svg"), "utf8")

  assert.equal(
    crypto.createHash("sha256").update(asset).digest("hex"),
    "1c71b5712fe9beb1605871431d5d967d75aac3e300cd7664ee97c3f4e7170277"
  )
  assert.match(icon, /"assets\/VPN-logomark-noborder\.svg"/)
  assert.match(icon, /"assets\/proton-vpn-simple-white\.svg"/)
  assert.match(icon, /running: root\.busy/)
  assert.match(icon, /MultiEffect/)
  assert.match(icon, /colorizationColor: root\.foreground/)
  assert.match(icon, /visible: root\.warning/)
  assert.doesNotMatch(icon, /PathSvg|Simple Icons/)
  assert.match(disconnectedAsset, /fill="#FFFFFF"/)
  assert.doesNotMatch(disconnectedAsset, /#000000/)
})

test("primary controls expose accessibility and shortcut disconnects are confirmed", () => {
  assert.match(panel, /Accessible\.name: vpn\.connected \? "Proton VPN connected"/)
  assert.match(panel, /component ActionButton:[\s\S]*Accessible\.name: text/)
  assert.match(panel, /function shortcutToggle\(\)/)
  assert.match(panel, /requestConfirmation\("disconnect"/)
  assert.match(panel, /confirmKind === "disconnect" \? "Disconnect"/)
  assert.match(panel, /splitAppPicker\.activeFocus \|\| protonUsernameField\.activeFocus \|\| root\.confirmOpen/)
  assert.match(panel, /Right click: connect \/ confirm disconnect/)
})

test("enhanced server discovery remains read-only and connects through the CLI", () => {
  assert.match(service, /dataHelper:.*protonvpn-data-helper/)
  assert.match(service, /serverDataProcess\.command = command/)
  assert.match(panel, /else if \(modeBox\.value === "Server"\) target = serverField\.text/)
  assert.match(panel, /vpn\.connect\(modeBox\.value, target, featureBox\.value\)/)
  assert.doesNotMatch(panel, /onChanged:[\s\S]{0,180}vpn\.connect\("Server"/)
  assert.doesNotMatch(panel, /proton\.vpn\.session/)
  assert.match(panel, /Manual server entry remains available/)
  assert.match(panel, /component ServerMap: BorderSurface/)
  assert.match(panel, /countries: vpn\.serverMapCountries/)
  assert.match(panel, /LOCAL SERVER MAP/)
  assert.match(panel, /function openServerMap\(\): void/)
  assert.match(service, /"--query=" \+ _serverQuery/)
})

test("advanced networking features are opt-in and guarded", () => {
  assert.match(service, /setting\("autoConnectUntrusted", false\)/)
  assert.match(service, /now - _lastAutoConnectAt < 120000/)
  assert.match(panel, /current server will be restored automatically/)
  assert.match(service, /"transaction-set"/)
  assert.match(service, /\["systemctl", "--user", enabled \? "start" : "stop", "proton-port-forward\.service"\]/)
  assert.match(service, /property var _integrationQueue: \[\]/)
  assert.match(service, /_integrationQueue = _integrationQueue\.concat/)
  assert.match(service, /root\.finishIntegration\(\)/)
  assert.match(panel, /Checking official Proton split-tunnelling backend/)
})

test("degraded health is actionable and unprotected is not a permanent warning badge", () => {
  assert.match(panel, /Tunnel interface: /)
  assert.match(panel, /VPN route: /)
  assert.match(panel, /Proton DNS: /)
  assert.doesNotMatch(panel, /warning:.*activeNetwork\.online/)
})

test("notifications do not drop while another notification is in flight", () => {
  assert.match(service, /function notify\(title, message\)[\s\S]{0,240}Quickshell\.execDetached/)
  assert.doesNotMatch(service, /notificationProcess\.running/)
})

test("port status honors the configured Proton CLI", () => {
  assert.match(service, /\[systemHelper, "port-status", "--cli", cliCommand\]/)
  assert.match(systemHelper, /\[args\.cli, "config", "list"\]/)
  assert.match(systemHelper, /connection_state\(args\.cli\)/)
})

test("advanced settings use the configured CLI and the authenticated account tier", () => {
  assert.match(service, /\[systemHelper, "settings-get", "--cli", cliCommand\]/)
  assert.match(service, /\[systemHelper, "split-get", "--cli", cliCommand\]/)
  assert.match(systemHelper, /def resolve_user_tier\(cli: str\)/)
  assert.doesNotMatch(systemHelper, /get\(user_tier=2\)/)
})

test("recovery, app picker, regions, and core settings are guarded", () => {
  assert.match(service, /setting\("recoverUnexpectedDrops", false\)/)
  assert.match(service, /\[systemHelper, "recover"/)
  assert.match(panel, /Search installed applications/)
  assert.match(panel, /All states\/regions/)
  assert.match(panel, /Only protocols validated by the installed Proton backend are shown/)
  assert.match(panel, /Apply kill-switch mode safely/)
  assert.match(panel, /Export redacted diagnostic report/)
})

test("orders the panel by task and expands settings into advanced controls", () => {
  const slots = ["connectionSlot", "quickSlot", "favoritesSlot", "recentSlot", "profilesSlot", "settingsSlot"]
  let previous = -1
  for (const slot of slots) {
    const index = panel.indexOf(`id: ${slot}`)
    assert.ok(index > previous, `${slot} should follow the preceding section`)
    previous = index
  }
  assert.match(panel, /parent: quickSlot/)
  assert.match(panel, /parent: favoritesSlot/)
  assert.match(panel, /parent: profilesSlot/)
  assert.match(panel, /parent: advancedSlot/)
  assert.match(panel, /root\.settingsExpanded \? Style\.space\(900\) : Style\.space\(540\)/)
  assert.match(panel, /VPN settings and advanced controls/)
})

test("offers compact contextual help for advanced settings", () => {
  assert.match(panel, /component HelpSectionHeader: Column/)
  assert.match(panel, /iconText: "\?"/)
  assert.match(panel, /helpSectionHeader\.helpOpen = !helpSectionHeader\.helpOpen/)
  assert.match(panel, /component ConfigToggle: Column/)
  assert.match(panel, /component SettingTitleHelp: Column/)
  assert.match(panel, /component HelpToggle: Column/)
  assert.match(panel, /configToggle\.helpOpen = !configToggle\.helpOpen/)
  assert.match(panel, /bordered: true/)
  assert.match(panel, /helpText: "Standard mode blocks traffic/)
  assert.match(panel, /title: "NetShield"/)
  assert.match(panel, /label: "Custom DNS"[\s\S]*helpText: "Sends DNS requests/)
  assert.doesNotMatch(panel, /size: Style\.space\(26\)/)
  assert.match(panel, /function openSettings\(\): void/)
  for (const heading of ["NETWORK AUTOMATION", "PORT FORWARDING", "PROTOCOL AND KILL SWITCH", "SPLIT TUNNELLING"])
    assert.match(panel, new RegExp(`title: "${heading}"`))
})

test("dropdowns close on a second trigger click and center long selections", () => {
  assert.match(panel, /component StableDropdown: Dropdown/)
  assert.match(panel, /Controls\.Popup\.CloseOnPressOutsideParent/)
  assert.match(panel, /positionViewAtIndex\(stableDropdown\._listObject\.currentIndex, ListView\.Center\)/)
  assert.equal((panel.match(/\n\s+Dropdown \{/g) || []).length, 0,
    "panel dropdown instances must use the stable local wrapper")
})

test("split tunnelling uses a searchable application dropdown", () => {
  assert.match(panel, /component StableSearchableDropdown: SearchableDropdown/)
  assert.match(panel, /id: splitAppPicker/)
  assert.match(panel, /triggerLabel: "Add application…"/)
  assert.match(panel, /options: root\.splitApplicationOptions\(\)/)
  assert.match(panel, /model: root\.selectedSplitApplications\(\)/)
  assert.doesNotMatch(panel, /id: splitAppSearch/)
})

test("server results use a compact searchable dropdown", () => {
  assert.match(panel, /id: serverPicker/)
  assert.match(panel, /triggerLabel: "Select server…"/)
  assert.match(panel, /options: root\.serverSelectionOptions\(\)/)
  assert.match(panel, /serverField\.text = serverId/)
  assert.doesNotMatch(panel, /component ServerRow:/)
})

test("confirms destructive actions and exposes account and diagnostic controls", () => {
  assert.match(panel, /ConfirmDialog/)
  assert.match(panel, /requestConfirmation\("favorite"/)
  assert.match(panel, /requestConfirmation\("profile"/)
  assert.match(panel, /Clear recent servers/)
  assert.match(panel, /requestConfirmation\("logout"/)
  assert.match(panel, /Sign out of Proton VPN/)
  assert.match(panel, /Copy report path/)
  assert.match(panel, /Open report folder/)
  assert.match(service, /function signOut\(\)/)
  assert.match(service, /VPN setting applied and the previous server restored/)
  assert.match(service, /Split tunnelling updated and the previous server restored/)
})

test("resolves account state before rendering signed-in controls", () => {
  assert.match(service, /property bool installationResolved: false/)
  assert.match(service, /property bool authResolved: false/)
  assert.match(service, /accountProcess\.command = \[root\.systemHelper, "account"/)
  assert.match(service, /if \(exitCode === 3 \|\| exitCode === 4\)/)
  assert.match(service, /!parsed\.connected && root\.needsLogin.*Needs sign-in/)
  assert.match(panel, /Checking Proton VPN account/)
  assert.match(panel, /Loading Proton VPN/)
  assert.match(panel, /vpn\.installationResolved && !vpn\.installed/)
  assert.match(panel, /Math\.max\(content\.implicitHeight, Style\.space\(420\)\)/)
  assert.match(panel, /id: quickSlot; visible: vpn\.authResolved/)
  assert.match(panel, /vpn\.installed && vpn\.authResolved && vpn\.needsLogin/)
})
