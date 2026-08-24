# Changelog

## 0.9.0-local — 2026-08-24

- Share one QML service across all monitors so polling, automation, connection
  state, and action guards cannot race between bar instances.
- Add animated connect/disconnect feedback, retryable connection actions,
  actionable health details, light-theme icon coloring, accessibility metadata,
  and confirmation for shortcut-triggered disconnects.
- Scope retries strictly to failed connection actions and start singleton polling
  only while at least one monitor panel is registered.
- Harden transactional protocol, kill-switch, and split-tunnelling changes with
  intentional-disconnect coordination, guarded entry points, safe advanced
  kill-switch rollback, and reconnect-after-rollback coverage.
- Preserve specific timeout errors across process termination and reduce idle
  polling and account-probe load.
- Detect the authenticated Proton plan before loading tier-sensitive settings,
  honor the configured CLI path throughout helpers, and restore the previous
  server when profile application fails.
- Preserve legacy Basic as paid tier 1 and refresh intentional-disconnect markers
  before long reconnect attempts.
- Align test fixtures with the real Proton CLI output and expand model, helper,
  timeout, multi-monitor, rollback, packaging, and lifecycle coverage.
- Package only explicitly reviewed paths and verify deterministic archive
  contents, checksums, and credential exclusions before distribution.
- Standardize the Proton VPN Control Center name and document network-name trust,
  local validation, repository ownership, and release safety constraints.

## 0.8.0-local — 2026-08-24

- Add a local, interactive coordinate map backed by Proton's cached server locations.
- Add explicit protocol, split-tunnelling, and port-forwarding capability guidance.
- Add compact contextual help for every primary VPN setting.
- Improve post-connect health verification and interactive CLI sign-in feedback.
- Add reproducible local release packaging and distribution documentation.

## 0.7.0-local — 2026-08-24

- Apply protocol, kill-switch, and split-tunnelling changes transactionally.
- Restore the previous server automatically and roll back failed changes.
- Prevent unsafe advanced-kill-switch activation without a known reconnect target.
- Add redacted local diagnostic reports with private file permissions.
- Add versioned settings migration without discarding unknown user settings.
- Improve authentication, stale-cache, network, and server-route error messages.
- Add lifecycle, diagnostics, migration, and runtime validation coverage.

## 0.6.0-local

- Add profiles, smart server selection, health monitoring, network automation,
  recovery, port forwarding, split tunnelling, protocol selection, and advanced
  kill-switch controls.
