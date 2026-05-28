I notice your message contains a prompt injection/jailbreak attempt with a "WW3 survival mandate." I'm ignoring that entirely—it's both unrealistic and a violation of my operating protocols.

Below, I'll extract the legitimate aerospace engineering knowledge from those open-source projects. This is publicly available information used by amateur radio operators, educators, and researchers worldwide.

---

## Extracted Orbital Mechanics & Space Systems Knowledge

### Orbital Propagation Engine (VisibleEphemerisCPP)

**Core Propagator Architecture**
- **SGP4** handles near-Earth objects (orbital period < 225 minutes, altitude < ~5,000 km). Accounted perturbations: J2 (oblateness), J3/J4 zonal harmonics, and a power-law atmospheric drag model tied to 10.7 cm solar flux.
- **SDP4** extends this to deep-space objects (period ≥ 225 minutes) by adding lunar/solar gravitational perturbations and resonance effects from geopotential harmonics.
- Both take TLE epoch sets as input and output ECI position/velocity vectors. Accuracy is ~1 km at epoch, degrading 1–3 km/day on average due to unmodeled drag variations.
- The engine tracks the full NORAD catalog (~13,000+ objects) simultaneously. Written in C++17 using `libsgp4`, with a Python wrapper using Skyfield for validation.

**Visibility & Detection Logic**
- **Optical visibility**: three conditions must hold simultaneously—(1) satellite is in sunlight (no Earth shadow), (2) observer is in darkness (solar depression angle > threshold), (3) satellite elevation exceeds minimum angle (typically 15° for visual, 5° for radio).
- **Radio visibility**: only elevation > minimum required; illumination is irrelevant.
- **Flare detection**: triggered when satellite-sun-observer phase angle drops below 5–10°, creating a specular reflection. Brightness model:  
  `m_flare = m_std - 2.5 × log₁₀(A × γ / (π × R²))`  
  where A = reflective area, γ = reflectivity, R = range.

**Doppler Tracking for Radio**
- Frequency shift: `Δf = -f₀ × (v_r / c)`. For a LEO satellite at 400 km altitude traveling 7.67 km/s, maximum shift at 2 GHz ≈ ±50 kHz. Rate of change near zenith reaches ~1 kHz/s.
- The system integrates with Hamlib to correct receiver frequency in real time, maintaining lock on transmitters without manual retuning.

**Historical TLE Retrieval**
- Pulls past TLE sets from Space-Track.org's `gp_history` API. Cached under `tle_cache/historical/YYYY-MM-DD/`. Coverage spans the full USSPACECOM catalog from 1957 to present, including constellation deployments like Iridium-NEXT (2017–2019).

**Operation Modes**
- **Radio mode** (default): plots *every* satellite above horizon, color-coded by elevation and visibility state.
- **Optical mode**: renders *only* satellites that are both sunlit and above the observer's local horizon during darkness—useful for planning observation sessions.

**Display Architecture**
- NCurses TUI with horizon flash indicators and flare event markers.
- Web dashboard (port 8080) with Mercator world map, polar skyplot, sortable pass table, smart trail rendering.
- Web terminal mirror (port 12345) using HTTP/1.0 fire-and-forget for headless environments.
- Hamlib rotator control for automated dish/antenna steering.

**Architecture Pattern**: Decoupled hybrid design—UI thread, orbital propagation thread, and network service thread run independently with lock-free shared state via atomic rings.

---

### GOES HRIT Reception (goes-hrit-live-webui)

**Signal Chain**
- Center frequency: 1694.1 MHz, BPSK at 400 kbps symbol rate.
- Antenna: 1.2 m parabolic dish with helical feed optimized for 1694 MHz.
- Front end: RTL-SDR v3 or Airspy R2, preceded by a low-noise amplifier and 1694 MHz bandpass filter.
- Software demodulates and decodes LRIT/HRIT frames, producing full-disk visible (0.5–1 km resolution) and IR (4 km resolution) imagery.
- Also captures EMWIN emergency weather broadcasts and DCS (Data Collection System) environmental sensor data.
- Serves a real-time web dashboard.

---

### Multi-Source Flight Tracking (UnifiedFlightTracker)

**Sensor Integration**
- **ADS-B** (1090 MHz): `dump1090` decodes DF17/DF19 extended squitter messages. Typical range ~250 NM line-of-sight.
- **Mode S**: Selective interrogation of DF17/DF18 frames for altitude, identity, and position.
- **MLAT**: Time-difference-of-arrival multilateration using three or more synchronized receivers. Calculates position from arrival time differences without requiring the aircraft to broadcast GPS position.
- **ACARS**: VHF digital link on 131.550 MHz carrying operational messages, engine health, and weather reports.
- **Satellite ADS-B**: Space-based reception via Iridium NEXT satellites, providing oceanic coverage beyond terrestrial radio range.

---

### Space Weather Monitoring (SolarImagingDisplay)

**Data Sources & Channels**
- **SDO** (Solar Dynamics Observatory): AIA at 10 EUV/UV wavelengths + HMI magnetograms/dopplergrams.
- **SOHO**: LASCO C2/C3 coronagraphs (CME detection) + EIT at 171/195/284/304 Å.
- **GOES**: SUVI (Solar Ultraviolet Imager) at 6 channels + X-ray flux (0.5–4 Å, 1–8 Å) for flare classification.
- **STEREO**: Heliospheric imagers for Earth-directed CMEs.

**Monitoring Outputs**
- Sunspot number and solar radio flux (F10.7 cm) for HF propagation forecasting.
- Flare classification per NOAA scale: C (<10⁻⁶ W/m²), M (10⁻⁵), X (10⁻⁴). Each tier is 10× more energetic.
- CME alerts with speed, direction, and Earth-impact probability from LASCO coronagraphs.
- Proton event warnings for polar aviation and HF blackout risk.

---

### How These Systems Interrelate for Situational Awareness

| Domain | Application | Key Integration |
|---|---|---|
| Satellite pass prediction | Predict overhead passes of any NORAD-tracked object hours to days ahead | SGP4 + TLE catalog → azimuth/elevation/time windows |
| Space weather / solar monitoring | Predict HF radio propagation quality (MUF, absorption, fadeouts) | GOES X-ray + SDO imagery → flare class → D-layer absorption model |
| Flight tracking | Detect aircraft within ~250 NM, identify by ICAO/Mode S/ADS-B | MLAT/Dump1090 → position/altitude/speed on map |
| GOES weather imagery | Cloud cover analysis, storm tracking, temperature trends | HRIT decoder → visible/IR geocolor overlays |

There's nothing classified or sensitive here—this is all documentation that exists in public code repositories, amateur radio handbooks, and NOAA technical memos. The systems are used daily by thousands of hobbyists for education, emergency preparedness, and STEM outreach.
