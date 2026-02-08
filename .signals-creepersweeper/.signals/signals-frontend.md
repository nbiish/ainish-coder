# Frontend Architecture & Dashboard Reference

> **Complete reference for the Creeper Sweeper single-page dashboard:
> tabs, modals, alert system, live analyzer, and real-time rendering.**
>
> **Stack**: Vanilla JavaScript + Socket.IO 4.7.5 + Web Audio API
>
> **Companion documents**:
> - [Data Models](signals-data-models.md) — API endpoints, socket events
> - [Architecture](signals-architecture.md) — Backend pipeline

---

## Table of Contents

1. [Technology Stack](#1-technology-stack)
2. [File Structure](#2-file-structure)
3. [Tab System](#3-tab-system)
4. [Real-Time Data Flow](#4-real-time-data-flow)
5. [Alert System (Web Audio)](#5-alert-system-web-audio)
6. [Modal System](#6-modal-system)
7. [Live Analyzer Sidebar](#7-live-analyzer-sidebar)
8. [Detection Table](#8-detection-table)
9. [Correlation Visualization](#9-correlation-visualization)
10. [Reference Tab](#10-reference-tab)
11. [Settings Tab](#11-settings-tab)
12. [State Management](#12-state-management)
13. [CSS Architecture](#13-css-architecture)
14. [Performance Considerations](#14-performance-considerations)

---

## 1. Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **JavaScript** | Vanilla ES6+ | No build step, runs on Pi's browser |
| **WebSocket** | Socket.IO 4.7.5 (CDN) | Real-time push from Flask-SocketIO |
| **Audio** | Web Audio API | No audio files, synthesized tones |
| **CSS** | Vanilla CSS with variables | Dark theme, responsive |
| **HTTP** | Fetch API | REST calls to Flask backend |
| **Template** | Server-rendered HTML (Jinja2) | Single page, tab navigation |

### No Build Tools

The frontend has zero build dependencies:
- No webpack, vite, or bundler
- No npm, node_modules
- No TypeScript compilation
- No framework (React, Vue, etc.)
- Direct `<script>` tags in HTML

This is intentional — the dashboard needs to work on a Raspberry Pi's
built-in Chromium without any toolchain.

---

## 2. File Structure

```
webapp/
├── templates/
│   └── index.html          # 563 lines — Single HTML page
└── static/
    ├── app.js              # 2464 lines — All application logic (92 functions)
    ├── reference.js        # 958 lines — SIGINT reference data + 30 vendors
    └── style.css           # 2047 lines — Dark theme styles
```

### Line Count Distribution

| File | Lines | Purpose |
|------|-------|---------|
| `app.js` | ~2464 | Socket handlers, API calls, rendering, audio, state, analyzer |
| `reference.js` | ~958 | Static reference tables, 30 vendors, 102 OUI prefixes |
| `style.css` | ~2047 | Full dark theme, responsive, modals, alerts, scrollable layout |
| `index.html` | ~563 | Structure, tab containers, form elements, CDN imports |

---

## 3. Tab System

### 9 Tabs

| # | Tab ID | Label | Content |
|---|--------|-------|---------|
| 1 | `detections` | Detections | Live detection table, filter, group-by-SSID |
| 2 | `ignore` | Ignore List | 4-pane: MAC, OUI, SSID patterns, device names |
| 3 | `groups` | SSID Groups | Card grid with detail modal |
| 4 | `bluetooth` | Bluetooth | BLE device table with address classification |
| 5 | `gps` | GPS | Fix display, nodes, track log |
| 6 | `devices` | Devices | Fingerprint browser, name/search, dual-panel modal |
| 7 | `correlation` | Correlation | Cluster cards, identify/rename, convergence banner |
| 8 | `reference` | Reference | 9 sub-tabs of signals intelligence education |
| 9 | `settings` | Settings | Scan params, export/import, watch alerts, status |

### Tab Navigation

```javascript
function switchTab(tabId) {
    // Hide all tab content
    document.querySelectorAll('.tab-content').forEach(tc => {
        tc.classList.remove('active');
    });
    // Deactivate all tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    // Activate selected
    document.getElementById(`tab-${tabId}`).classList.add('active');
    document.querySelector(`[data-tab="${tabId}"]`).classList.add('active');
    // Trigger data load for tab
    onTabActivated(tabId);
}
```

### Tab-Specific Data Loading

| Tab | Data Source | Load Trigger |
|-----|-----------|--------------|
| Detections | `detections` socket event | Continuous (every 3s) |
| Ignore | `GET /api/ignore` | On tab switch |
| Groups | `GET /api/groups` | On tab switch |
| Bluetooth | `bt_devices` socket event | Continuous |
| GPS | `gps_fix` socket event | Continuous |
| Devices | `GET /api/devices` | On tab switch |
| Correlation | `GET /api/correlations` | On tab switch |
| Reference | Static JS data | Once at load |
| Settings | `GET /api/settings` | On tab switch |

---

## 4. Real-Time Data Flow

### Socket.IO Connection

```javascript
const socket = io({
    auth: { username: '...', password: '...' }
});

socket.on('connect', () => { /* update status indicator */ });
socket.on('disconnect', () => { /* show reconnecting */ });
```

### Event Handlers

```javascript
socket.on('detections', (data) => {
    detectionsCache = data;
    renderDetections();
});

socket.on('alert', (data) => {
    handleAlert(data);  // sidebar + sound + modal
});

socket.on('watch_alert', (data) => {
    handleWatchAlert(data);  // sidebar + chime + modal
});

socket.on('bt_devices', (data) => {
    btDevicesCache = data;
    if (activeTab === 'bluetooth') renderBluetooth();
});

socket.on('gps_fix', (data) => {
    gpsCache = data;
    if (activeTab === 'gps') renderGPS();
});

socket.on('ignore_updated', (data) => {
    ignoreCache = data;
    if (activeTab === 'ignore') renderIgnoreList();
});

socket.on('settings_updated', (data) => {
    applySettingsToUI(data);
});

socket.on('device_named', ({ mac, name }) => {
    // Update inline labels in all views
});

socket.on('correlation_identified', (data) => {
    if (activeTab === 'correlation') loadCorrelations();
});

socket.on('watchlist_updated', (data) => {
    watchListCache = data;
    renderWatchList();
});
```

---

## 5. Alert System (Web Audio)

### AudioContext Initialization

```javascript
let audioCtx = null;

function initAudio() {
    if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
}
```

### Tier Sound Definitions

| Tier | Sound | Implementation |
|------|-------|---------------|
| 1 (NEW_DEVICE) | Single 660Hz sine beep, 0.3s | `osc.type="sine"; freq=660` |
| 2 (PERSIST) | Double 880Hz beeps, 0.2s each | Two oscillators with 0.3s gap |
| 3 (SURVEILLANCE) | Sawtooth siren 440→1200Hz, 0.8s | `osc.type="sawtooth"; linearRamp` |
| 4 (WATCH_ALERT) | C5-E5-G5 arpeggio chime, 0.5s | Three sine oscillators (523, 659, 784 Hz) |

### Tier 3 Siren Implementation

```javascript
function playAlertBeep(tier) {
    initAudio();
    const now = audioCtx.currentTime;
    const gain = audioCtx.createGain();
    gain.connect(audioCtx.destination);

    if (tier === 3) {
        const osc = audioCtx.createOscillator();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(440, now);
        osc.frequency.linearRampToValueAtTime(1200, now + 0.8);
        gain.gain.setValueAtTime(0.3, now);
        gain.gain.linearRampToValueAtTime(0, now + 0.8);
        osc.connect(gain);
        osc.start(now);
        osc.stop(now + 0.8);
    }
}
```

### Tier 4 Chime (Watch Alert)

```javascript
if (tier === 4) {
    const notes = [523.25, 659.25, 783.99]; // C5, E5, G5
    notes.forEach((freq, i) => {
        const osc = audioCtx.createOscillator();
        osc.type = "sine";
        osc.frequency.value = freq;
        const g = audioCtx.createGain();
        g.gain.setValueAtTime(0.2, now + i * 0.15);
        g.gain.linearRampToValueAtTime(0, now + i * 0.15 + 0.3);
        osc.connect(g).connect(audioCtx.destination);
        osc.start(now + i * 0.15);
        osc.stop(now + i * 0.15 + 0.3);
    });
}
```

### Alert Sidebar

The alert sidebar is always visible (right column of dashboard grid):

```html
<div class="alert-sidebar">
    <h3>Alert Log</h3>
    <div id="alertLog">
        <!-- Alerts prepended here, newest first -->
        <div class="alert-entry tier-3">
            <span class="alert-icon">🚨</span>
            <span class="alert-label">SURVEILLANCE</span>
            <span class="alert-mac">58:8E:81:AB:CD:EF</span>
            <span class="alert-time">14:22:00</span>
        </div>
    </div>
</div>
```

### Tier UI Styling

| Tier | Label | Icon | Color | Auto-Dismiss |
|------|-------|------|-------|------|
| 1 | NEW_DEVICE | 📡 | Blue (`#3b82f6`) | 5s |
| 2 | PERSIST | ⏱️ | Orange (`#f59e0b`) | 5s |
| 3 | SURVEILLANCE | 🚨 | Red (`#ef4444`) | Manual only |
| 4 | WATCH_ALERT | 🔔 | Green (`#10b981`) | 5s |

---

## 6. Modal System

### Alert Modal

Triggered by alert events. Tier styling matches the alert tier:

```javascript
function showAlertModal(tier, detection) {
    const modal = document.getElementById('alertModal');
    modal.className = `modal tier-${tier}`;
    // Populate fields
    modal.querySelector('.modal-mac').textContent = detection.mac;
    modal.querySelector('.modal-name').textContent = detection.display_name;
    modal.querySelector('.modal-signal').textContent = `${detection.signal} dBm`;
    // Show
    modal.classList.add('visible');
    // Auto-dismiss for tier 1, 2, 4
    if (tier !== 3) setTimeout(() => modal.classList.remove('visible'), 5000);
}
```

Actions in modal:
- **Dismiss** — close modal
- **Ignore** — adds MAC to ignore list, closes modal

### Device Detail Modal (Dual-Panel)

Opened from Devices tab by clicking a device row:

```
┌─────────────────────────────────────────────────────┐
│ Device Detail: AA:BB:CC:DD:EE:FF                     │
├────────────────────────┬────────────────────────────┤
│ Info Panel             │ Analysis Panel              │
│                        │                             │
│ MAC: AA:BB:CC:DD:EE:FF │ MAC Classification:         │
│ Name: Mom's iPhone     │ • Type: local_admin         │
│ Manufacturer: Apple    │ • Trackability: rotating    │
│ First seen: Jan 15     │                             │
│ Last seen: Feb 8       │ PNL Fingerprint:            │
│ Sightings: 847         │ • Hash: a3f7b2c1e9d4f083   │
│ Device type: wifi      │ • Directed: 3 SSIDs        │
│                        │ • Matches: 2 devices        │
│ Recent Sightings:      │                             │
│ 14:22 -52dBm CH6      │ RSSI Distance Estimate:     │
│ 14:19 -55dBm CH6      │ • ~5m (n=3.0)              │
│ 14:16 -48dBm CH6      │                             │
│                        │ Channel Analysis:           │
│ Tags: family, trusted  │ • Ch6 (98%), Ch1 (2%)      │
│                        │                             │
│ [Set Name] [Remove]    │ Surveillance Vendor:        │
│                        │ • No match ✅               │
└────────────────────────┴────────────────────────────┘
```

### SSID Group Detail Modal

Opened from Groups tab by clicking a group card:

```
┌─────────────────────────────────────────┐
│ SSID Group: HomeWiFi                     │
├─────────────────────────────────────────┤
│ Members: 5 MACs                          │
│ Channels: 6                              │
│ Signal: -38 to -72 dBm                   │
│ First seen: 2026-01-15                   │
│                                          │
│ ┌─MAC──────────────┬──Signal──┬──Last──┐ │
│ │ AA:BB:CC:DD:EE:01│ -52 dBm │ 14:22  │ │
│ │ AA:BB:CC:DD:EE:02│ -45 dBm │ 14:20  │ │
│ └──────────────────┴─────────┴────────┘ │
│                                          │
│ Event Log:                               │
│ 14:22 new_mac AA:BB:CC:DD:EE:03         │
│ 14:10 signal_change -52 → -38           │
└─────────────────────────────────────────┘
```

---

## 7. Live Analyzer Sidebar

Floating overlay panel on the left side of the dashboard main area:

```
┌──────────────────────────┐
│ ═══ Signal Analyzer ═══  │ [X]
│                          │
│ ── MAC Analyzer ──       │
│ [AA:BB:CC:DD:EE:FF____] │
│ OUI: Apple, Inc.         │
│ Type: local_admin         │
│ LA bit: set (randomized) │
│                          │
│ ── BT Analyzer ──        │
│ [CC:DD:EE:FF:00:11____] │
│ Type: LE Random           │
│ Category: random_static  │
│ Trackability: session    │
│                          │
│ ── RSSI Distance ──      │
│ RSSI: [-52_] dBm         │
│ Ref:  [-40_] dBm         │
│ n:    [3.0_]              │
│ Distance: ~5.0m           │
│                          │
│ ── Pi GPS Status ──      │
│ Fix: GPS (9 sats)        │
│ Lat: 42.3601             │
│ Lon: -71.0589            │
│ HDOP: 1.2                │
└──────────────────────────┘
```

### Auto-Population

Clicking a device row in any table auto-populates the analyzer:

```javascript
function populateAnalyzer(mac, rssi) {
    document.getElementById('analyzerMac').value = mac;
    document.getElementById('analyzerRssi').value = rssi || '';
    runMacAnalysis();
    runRssiAnalysis();
}
```

### Toggle Behavior

```javascript
document.getElementById('analyzerToggle').addEventListener('click', () => {
    const panel = document.getElementById('analyzerPanel');
    panel.classList.toggle('hidden');
});
```

---

## 8. Detection Table

### Rendering

Every scan cycle (3s), the detection table re-renders:

```javascript
function renderDetections(detections) {
    const tbody = document.getElementById('detectionsBody');
    tbody.innerHTML = '';

    detections
        .filter(applyFilters)   // RSSI, ignored, surveillance
        .sort(applySorting)     // By signal, time, MAC
        .forEach(det => {
            const row = createDetectionRow(det);
            tbody.appendChild(row);
        });
}
```

### Table Columns

| Column | Content | Sortable |
|--------|---------|----------|
| MAC | Address + address type badge | ✅ |
| Name | friendly_name or device_name | ✅ |
| SSID | Connected SSID | ✅ |
| Signal | RSSI dBm + bar visualization | ✅ |
| Channel | WiFi channel | ✅ |
| PHY | wifi / ble badge | ✅ |
| First Seen | Timestamp | ✅ |
| Persist | Duration since first seen | ✅ |
| Location | GPS badge (if available) | — |
| Actions | Ignore / Name / Detail | — |

### Filter Controls

- **Hide ignored**: Toggle to show/hide ignored devices
- **RSSI threshold**: Slider to filter by minimum signal
- **Search**: Text filter on MAC/name/SSID
- **Surveillance only**: Show only surveillance matches
- **Group by SSID**: Collapse by connected network

---

## 9. Correlation Visualization

### Cluster Card

Each correlation cluster is rendered as a card:

```html
<div class="cluster-card">
    <div class="cluster-header">
        <h4>cluster-abc123</h4>
        <span class="cluster-score">Score: 0.82</span>
    </div>

    <div class="cluster-members">
        <div class="member wifi">📶 AA:BB:CC:DD:EE:01 (Mom's iPhone)</div>
        <div class="member ble">📲 CC:DD:EE:FF:00:11 (AirPods)</div>
    </div>

    <div class="cluster-links">
        <div class="link-evidence">
            OUI: 0.10 | Probe: 0.85 | PNL: 0.92 | RSSI: 0.78
        </div>
    </div>

    <div class="cluster-alerts">
        <div class="alert-mini tier-1">NEW_DEVICE 14:22</div>
    </div>

    <div class="cluster-actions">
        <button onclick="identifyCluster('abc123')">Identify</button>
        <button onclick="renameCluster('abc123')">Rename</button>
    </div>
</div>
```

### Convergence Banner

Displays current RSSI convergence state using the pure exponential formula:

$$\text{gap}(n) = 1.0 + 19.0 \times 0.92^n$$

```
🔄 RSSI Convergence: Step 12 | WiFi: 5.9 dBm | BT: 9.9 dBm | ▉▉▉▉▉▊░░ 55%
```

- WiFi converges to **1.0 dBm** (`RSSI_GAP_TARGET`)
- BT converges to **5.0 dBm** (`RSSI_GAP_TARGET + 4`)
- Full convergence at step 36 (~36 minutes at 1-min intervals)
- Banner auto-updates on each `correlation_identified` event

### Scrollable Layout

- Correlation container: `max-height: calc(100vh - 200px); overflow-y: auto`
- Cluster members: `max-height: 180px; overflow-y: auto`
- Cluster alerts: `max-height: 120px; overflow-y: auto`
- Cluster links: `max-height: 140px; overflow-y: auto`

---

## 10. Reference Tab

### 9 Sub-Tabs

| Sub-Tab | Content |
|---------|---------|
| MAC Address | OUI lookup, LA bit, randomization explained |
| Bluetooth | Address types, advertising, BLE vs BR/EDR |
| PHY Types | 802.11 a/b/g/n/ac/ax, modulation, data rates |
| Channels | 2.4GHz and 5GHz channel maps, overlap diagrams |
| SSID | SSID types, hidden networks, probe behavior |
| Signal/RSSI | Path loss model, distance estimation, dBm scale |
| Fingerprinting | PNL, device profiling, behavioral analysis |
| Surveillance Vendors | 20+ vendor entries from reference.js |
| Live Analyzer | Inline MAC/BT/RSSI analysis tools |

### Vendor Database (reference.js)

Contains 30 surveillance vendor entries with 102 OUI prefixes:
- Vendor name and description
- Known OUI prefixes (hex arrays)
- Product categories (ALPR, body-worn, fixed camera, acoustic, drone)
- Typical SSID patterns
- BLE service UUIDs

Vendors include: Flock Safety, Axon, Motorola Solutions, Bosch, Honeywell,
i-PRO (Panasonic), FLIR, Hanwha Vision, Pelco, Avigilon, Uniview, Vivotek,
Ubiquiti, Reolink, Dahua, Hikvision, Verkada, March Networks, ShotSpotter
(SoundThinking), Digital Barriers, Sierra Wireless, Cradlepoint, Digi
International, Rajant, Silvus, Persistent Systems, and others.

14 vendors were added in the latest update — primarily tactical mesh,
rugged radio, and acoustic gunshot detection vendors.

---

## 11. Settings Tab

### Layout

```
┌─────────────────────────────────────────────────────────┐
│ Settings                                                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ ── Scan Settings ──                                      │
│ Scan Interval:    [3___] seconds                         │
│ Persist Threshold: [5___] seconds                        │
│ Min Signal (dBm): [-127_] (-127 = no limit)             │
│ [Save Settings]                                          │
│                                                          │
│ ── Alert Preferences ──                                  │
│ [✅] Sound alerts enabled                                │
│ [✅] Popup alerts enabled                                │
│                                                          │
│ ── Data Export / Import ──                               │
│ [📥 Export Detections CSV]                               │
│ [📤 Import Known Devices] [Choose File]                  │
│                                                          │
│ ── Watch Alerts ──                                       │
│ Set named alerts for people, pets, or objects:           │
│ Alert Name:  [Mom is home_______]                        │
│ Match By:    [Friendly Name ▼]                           │
│ Match Value: [Mom's iPhone______]                        │
│ Cooldown:    [300__] seconds                             │
│ [+ Add Watch]                                            │
│                                                          │
│ ┌─ Active Watch Alerts ─────────────────────────────┐   │
│ │ 🔔 Mom is home (friendly_name: Mom's iPhone)       │   │
│ │    Cooldown: 300s | [Disable] [Remove]             │   │
│ │ 🔔 Dog is home (mac: AA:BB:CC:DD:EE:FF)           │   │
│ │    Cooldown: 600s | [Enable] [Remove]              │   │
│ └───────────────────────────────────────────────────┘   │
│                                                          │
│ ── System Status ──                                      │
│ Scanner: Running ✅                                      │
│ Kismet: Connected ✅                                     │
│ GPS: Fix (9 sats) ✅                                     │
│ Bluetooth: 21 devices ✅                                 │
│ Fingerprints: 142                                        │
│ Active detections: 27                                    │
└─────────────────────────────────────────────────────────┘
```

---

## 12. State Management

### Global Caches (app.js)

```javascript
let detectionsCache = [];      // Updated every scan cycle
let btDevicesCache = [];       // Updated every scan cycle
let gpsCache = {};             // Updated every scan cycle
let ignoreCache = {};          // Updated on ignore_updated event
let watchListCache = [];       // Updated on watchlist_updated event
let activeTab = 'detections';  // Current active tab
```

### Rendering Strategy

- **Continuous tabs** (Detections, BT, GPS): Re-render every socket event
- **On-demand tabs** (Devices, Groups, Correlations): Fetch + render on tab switch
- **Static tabs** (Reference): Render once at page load
- **Settings**: Load on tab switch, save on button click

---

## 13. CSS Architecture

### Theme Variables

```css
:root {
    --bg-primary: #0f1419;
    --bg-secondary: #1a1f2e;
    --bg-tertiary: #252b3b;
    --text-primary: #e8eaed;
    --text-secondary: #9aa0a6;
    --accent-blue: #3b82f6;
    --accent-green: #10b981;
    --accent-orange: #f59e0b;
    --accent-red: #ef4444;
    --border-color: #2d3748;
}
```

### Layout Grid

```css
.dashboard {
    display: grid;
    grid-template-columns: 1fr 300px;  /* main + alert sidebar */
    gap: 16px;
    height: calc(100vh - 80px);
}
```

### Responsive Breakpoints

```css
@media (max-width: 768px) {
    .dashboard {
        grid-template-columns: 1fr;
    }
    .alert-sidebar {
        max-height: 200px;
    }
}
```

### Custom Scrollbars

```css
::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: var(--bg-tertiary); }
::-webkit-scrollbar-thumb {
    background: var(--accent-blue);
    border-radius: 3px;
}
```

---

*signals-frontend v2.0 | 2026-02-08 | Creeper Sweeper*
*Updated: 2464-line app.js, 92 functions, 12 socket events, 30 vendors, scrollable layout*

### DOM Re-Rendering

- Detection table rebuilds every 3s for up to ~200 rows
- Uses `innerHTML = ''` + `appendChild` (faster than individual DOM operations)
- Only re-renders visible tab (saves CPU when tab is not active)

### Socket Event Volume

- At 3s scan interval: ~20 events/minute per type
- Each `detections` event: ~10-50KB (depending on device count)
- Total WebSocket bandwidth: ~50-200KB/minute

### Memory

- Detection cache: ~200 objects × ~1KB = ~200KB
- BT cache: ~50 objects × ~0.5KB = ~25KB
- Minimal — no framework state management overhead

### Audio Performance

- Web Audio API creates oscillators on-demand (no persistent audio graph)
- Each alert: 1-3 oscillator nodes, automatically garbage collected
- No audio worklet or heavy DSP

### Cache Busting

All static assets are loaded with a version query string to prevent stale caches:

```html
<script src="/static/app.js?v=6"></script>
<script src="/static/reference.js?v=6"></script>
<link href="/static/style.css?v=6" rel="stylesheet">
```

The `?v=6` parameter is incremented on each deploy via `deploy.sh`.

### Haversine Distance Helper

```javascript
function haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // metres
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ/2)**2 + Math.cos(φ1)*Math.cos(φ2)*Math.sin(Δλ/2)**2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}
```

Used by GPS tab and triangulation display to compute distances between
detection nodes and between the Pi and tracked devices.
