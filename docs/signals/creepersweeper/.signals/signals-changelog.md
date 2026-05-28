# Changelog — Creeper Sweeper

> **Complete commit history with feature descriptions.**
>
> 57 commits from initial scaffold to HEAD (`76a19b7`).
> All work spans February 7–11, 2026.

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total commits | 57 |
| Features | 32 |
| Fixes | 16 |
| Docs | 5 |
| Refactors | 2 |
| Performance | 1 |
| Total source lines | ~15,556 (12 webapp files) |
| Backend (`app.py`) | 5,307 lines |
| Frontend JS | 4,036 lines (app.js + reference.js) |
| Frontend CSS | 2,364 lines |
| MAC Breakdown | 340 lines (mac_breakdown.py) |
| Supporting modules | 2,681 lines (bt_scanner + pnl_engine + gps_reader + triangulation + phy_fingerprint) |
| OUI Database | 56,887 entries (5.5MB backend + 4.4MB frontend) |

---

## Commit Log (Chronological — Oldest First)

### Phase 1 — Foundation (Feb 7, 03:00–04:41)

| Hash | Type | Description |
|------|------|-------------|
| `77f1243` | feat | **Initial scaffold** — HTML structure, CSS dark theme, basic dashboard layout |
| `b949228` | feat(sensors) | **GPS, BT LE, triangulation modules** — `gps_reader.py` (gpsd integration), `bt_scanner.py` (btmgmt wrapper), `triangulation.py` (multi-node RSSI positioning) |

### Phase 2 — Core Features (Feb 7, 21:15–22:27)

| Hash | Type | Description |
|------|------|-------------|
| `cea28c9` | feat | **Surveillance database** — OUI-based surveillance vendor matching, unit tests |
| `0cd98c2` | feat(webapp) | **Single dashboard layout** — Alert sidebar (right column), instant tier alerts, device name removal, 2-column grid |
| `4fd7122` | feat(time) | **NTP + timezone** — `timedatectl` in deploy.sh, Eastern timezone, timezone-aware timestamps throughout |
| `d94d59b` | feat(reference) | **SIGINT reference module** — `reference.js` with ~16 surveillance vendors, 9 sub-tabs of educational content |
| `a790e77` | feat(webapp) | **Live analyzer sidebar** — MAC parser + BT decoder + RSSI distance calculator, dual-panel device modal, expanded vendor DB |
| `1234464` | fix(webapp) | **Layout restoration** — 2-column layout fix, floating analyzer positioning, Reference tab rendering |

### Phase 3 — Correlation & Hardware (Feb 7, 23:02–23:33)

| Hash | Type | Description |
|------|------|-------------|
| `e0d0f93` | feat(correlation) | **Signal correlation system** — Probe request tracking, initial weighted scoring algorithm |
| `eb326a0` | feat(hardware) | **gpsd integration** — `/etc/default/gpsd` config, udev rules for U-blox7 (`/dev/gps0`), hardware docs |
| `7abf4bc` | fix(systemd) | **Template unit fix** — `%i` instead of `%I` to prevent dash-to-slash unescaping in usernames |
| `f8c2559` | fix(systemd) | **Path fix** — Replace `%h` with `/home/%i` for system service WorkingDirectory |
| `660c227` | fix(systemd) | **Capabilities fix** — Remove `NoNewPrivileges`, use `AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW` for btmgmt |
| `1e6f9bc` | fix(systemd) | **Config dir fix** — Pre-create `~/.local/share/creeper-sweeper/` to prevent `NAMESPACE` startup failure |
| `b56bf11` | feat(hardware) | **Hardware auto-detection** — `hardware.py` module, USB VID:PID scanning for GPS/BT/WiFi adapters |

### Phase 4 — Detection Tuning & BT Pipeline (Feb 7 23:33–Feb 8 01:41)

| Hash | Type | Description |
|------|------|-------------|
| `b529187` | feat(correlation) | **Identification workflow** — Cluster identify + rename, bulk ignore (all MACs + SSIDs in cluster) |
| `e581756` | fix(detection) | **Drive-by tuning** — Adjust persist threshold and alert cooldowns for vehicle-speed targets |
| `abc3ff5` | fix(bluetooth) | **BT pipeline fix** — Parse both stdout+stderr from btmgmt, feed BT devices into detection/alert pipeline |
| `8896287` | fix(bluetooth) | **PTY wrapper** — `script -qc "btmgmt find -l" /dev/null` to solve systemd PTY buffering |
| `435ae1a` | docs(signals,llms) | **Documentation** — Comprehensive BT/WiFi scanning documentation in `.signals/` |

### Phase 5 — Dashboard Evolution (Feb 8, 01:57–04:26)

| Hash | Type | Description |
|------|------|-------------|
| `cc70816` | fix(webapp) | **Alert UX** — Auto-dismiss tier 1/2/4 alerts after 5s, recompute confirmation dialog |
| `c5e1601` | feat(webapp) | **GPS-tagged detections** — Attach lat/lon to every detection from live GPS fix |
| `6183e48` | feat(webapp) | **Location fallback** — Use SSID's last-known location when GPS unavailable, boost RSSI correlation |
| `53236d1` | feat(webapp) | **Settings upgrades** — Sound toggle, unconstrained RSSI default (-127 = no limit) |
| `6bdd77d` | feat(correlator) | **RSSI convergence** — Damped oscillatory tolerance convergence (later replaced by pure exponential) |
| `5164384` | feat(webapp) | **Scrollable correlation** — Scrollable cluster cards with `max-height` constraints |
| `155f8f1` | fix(webapp) | **Viewport constraint** — Enforce scrollable layout for all tabs, prevent page overflow |
| `ac0c099` | fix(webapp) | **Dashboard restore** — Scrollable correlation only (not all tabs), popup toggle setting |
| `2576ed6` | fix(webapp) | **Layout fix** — Remove flex from correlation tab, fix clipped cluster cards |
| `9622411` | feat(webapp) | **RSSI setting UX** — Positive dBm scale display in settings, default 127 |

### Phase 6 — Advanced Features (Feb 8, 04:55–06:10)

| Hash | Type | Description |
|------|------|-------------|
| `8b2b753` | feat(detection) | **PNL fingerprinting** — `pnl_engine.py`, BLE address type classification (LE Public/Random/BR-EDR), directed probe extraction, PNL hash computation |
| `09d1f06` | feat(webapp) | **CSV export/import** — 34-column CSV export merging WiFi+BT+fingerprints, CSV import with `action` field (ignore/name/both) |
| `d247af4` | feat(webapp) | **Watch alerts** — WatchList system (7 match types, cooldown, enable/disable), settings persistence (7 fields to JSON), fix min RSSI handling |
| `ce7b49d` | docs(signals) | **Knowledge base update** — Comprehensive `.signals/` documentation refresh |
| `9082ecd` | refactor(correlation) | **Multi-dimensional clustering** — Replace union-find + 7-signal weighted scoring with 6-phase pipeline, 9 cluster types, pure exponential RSSI convergence |
| `7228c8e` | perf(correlator) | **RSSI gap tightening** — `RSSI_GAP_TARGET` 8→1 dBm, deployed to Pi, recomputed 315 clusters |

### Phase 7 — CD Analytics & CI/CD Pipelines (Feb 8–9)

| Hash | Type | Description |
|------|------|-------------|
| `44078f4` | test | **Analytics test suite** — 30 comprehensive tests for CD analytics module |
| `9e27644` | feat(phy) | **PHY-layer fingerprinting** — 4 engines: IE, Clock Skew, Supported Rates, RadioTap/PHY composite |
| `b2ffceb` | fix(infra) | **Infrastructure fixes** — webapp bind 0.0.0.0, iw full path, wlan1 auto-up, BT/GPS fixes |
| `8b59f55` | feat(pipeline) | **CI/CD enrichment pipeline** — IEEE OUI DB, name/SSID classification, 51 tests |
| `8f38685` | feat(research) | **OUI research pipeline** — Wireshark DB, IEEE cross-ref, BT SIG analysis, 27 tests |
| `d67e29d` | feat(ci-cd) | **Correlation export** — UI export buttons, research CLI, deploy to Pi |
| `65d6c5c` | docs | **OSA documentation** — Orchestrated agent commands and patterns |

### Phase 8 — Home Network, Presence & Correlation UX (Feb 9–10)

| Hash | Type | Description |
|------|------|-------------|
| `16ae677` | feat(presence) | **Device identification** — Presence tracking, CI/CD correlation analysis |
| `3885313` | feat(webapp) | **Correlation card info modal** — Home network detection tab (3-tier) |
| `6e36af2` | feat(webapp) | **Clickable correlation cards** — Full cluster info on click |
| `f57d37e` | fix(webapp) | **Double-modal stacking fix** — Event propagation issue resolved |
| `1f632f9` | fix(webapp) | **Inline onclick** — Reliable correlation card click handling |
| `3462ca8` | fix(webapp) | **HTML modal restructure** — Sibling modals fix invisible modal bug |
| `23559c3` | docs(all) | **Phase 10 documentation** — README, PRD, RULES, TODO update |

### Phase 9 — Setup Automation & Config (Feb 10)

| Hash | Type | Description |
|------|------|-------------|
| `2cd97af` | feat(setup) | **One-shot setup** — Streamlined installation, CREEPER_TIMEZONE, systemd env |
| `c56f0a9` | fix(config) | **Kismet username** — Environment variable handling update |

### Phase 10 — Comprehensive Data Export (Feb 10)

| Hash | Type | Description |
|------|------|-------------|
| `7636ed7` | feat(export) | **16 export endpoints** — CSV + JSON for all dashboard sections, full dump |
| `80771b1` | docs(export) | **Phase 11 documentation** — llms.txt and README updated for export system |

### Phase 11 — MAC Address Breakdown & OUI Database (Feb 11)

| Hash | Type | Description |
|------|------|-------------|
| `5f130e1` | feat(oui) | **MAC address breakdown** — 56,887-entry OUI vendor DB, structural analysis engine, visual octet diagram, vendor cards, tracking risk, ignore list badges |
| `76a19b7` | fix(oui) | **OUI DB loader** — Add missing `loadOuiDatabase()` on page init (fetches 56k+ entry DB to `window._ouiDB`) |

---

## Key Architectural Milestones

| Commit | Milestone |
|--------|-----------|
| `77f1243` | First HTML/CSS scaffold |
| `b949228` | Sensor modules (GPS, BT, triangulation) |
| `0cd98c2` | Single-page dashboard with alert sidebar |
| `e0d0f93` | First correlation engine |
| `8896287` | BT scanning working under systemd (PTY fix) |
| `6bdd77d` | RSSI convergence algorithm |
| `8b2b753` | PNL fingerprinting engine |
| `9082ecd` | Multi-dimensional clustering (final algorithm) |
| `7228c8e` | Production-tuned RSSI gap (1 dBm) — 315 clusters |
| `9e27644` | PHY-layer fingerprinting (4 engines, 9 techniques) |
| `8b59f55` | CI/CD enrichment pipeline (IEEE OUI DB, classifiers) |
| `8f38685` | OUI research pipeline (Wireshark + IEEE + BT SIG) |
| `3885313` | Home network detection (3-tier) + correlation info modals |
| `7636ed7` | 16 comprehensive data export endpoints |
| `5f130e1` | MAC address breakdown + 56,887-entry vendor database |

---

## File Evolution

| File | Current Lines | First Commit | Major Changes |
|------|--------------|--------------|---------------|
| `app.py` | 5,307 | `0cd98c2` | Every phase added features; 200 functions, 93 routes |
| `app.js` | 3,063 | `77f1243` | Started ~200 lines → MAC breakdown, OUI loader, export |
| `style.css` | 2,364 | `77f1243` | Dark theme, modals, MAC breakdown panel, vendor badges |
| `reference.js` | 973 | `d94d59b` | 16 vendors → 30 vendors, MAC analyzer with OUI lookup |
| `index.html` | 732 | `77f1243` | 10 tabs, 4 modals, CDN imports, cache-busting |
| `mac_breakdown.py` | 340 | `5f130e1` | NEW: MAC structural analysis, 56k+ vendor lookup |
| `phy_fingerprint.py` | 728 | `9e27644` | 4 PHY-layer engines (IE, clock, rates, composite) |
| `pnl_engine.py` | 613 | `8b2b753` | PNL profiling, Jaccard similarity, hash computation |
| `triangulation.py` | 590 | `b949228` | Multi-node RSSI positioning, weighted centroid |
| `bt_scanner.py` | 401 | `b949228` | btmgmt wrapper → PTY fix → regex parser |
| `gps_reader.py` | 349 | `b949228` | gpsd socket client, quality parsing |
| `build_oui_db.py` | 96 | `5f130e1` | NEW: CI/CD OUI DB merge (maclookup + IEEE) |

---

## Deployment History

| Date | Target | Action | Result |
|------|--------|--------|--------|
| 2026-02-07 | Pi `192.168.1.243` | Initial deploy | Dashboard running, WiFi scanning |
| 2026-02-08 | Pi `192.168.1.243` | BT pipeline fix | BT devices appearing in dashboard |
| 2026-02-08 | Pi `192.168.1.243` | Multi-dim clustering + RSSI gap 1 dBm | 315 clusters computed |
| 2026-02-09 | Pi (mDNS) | PHY engines + CI/CD pipeline | 9 detection techniques live |
| 2026-02-10 | Pi (mDNS) | Home network + presence + export | 16 export endpoints, 10-tab dashboard |
| 2026-02-11 | Pi (mDNS) | MAC breakdown + 56k OUI DB | Vendor lookup live, breakdown panel in all modals |

---

*signals-changelog v2.0 | 2026-02-11 | Creeper Sweeper*
