const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const root = path.resolve(__dirname, "..")
const panel = fs.readFileSync(path.join(root, "Panel.qml"), "utf8")
const service = fs.readFileSync(path.join(root, "Service.qml"), "utf8")

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
