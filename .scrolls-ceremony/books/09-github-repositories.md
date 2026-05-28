# Book 9: GitHub Repository Catalog — n4hy Open-Source Portfolio

> **Knowledge Domain**


---

## Abstract

This volume catalogs and synthesizes the 15 open-source repositories maintained at `github.com/n4hy`. Each repository is documented with its technical specifications, build instructions, research context, and integration pathways into the broader `.scrolls-ceremony/` framework. These repositories span signal processing, software-defined radio, embedded AI, space systems, and atmospheric science — collectively forming a comprehensive open-source toolkit for Indigenous technological sovereignty.

---

## 1. Modern-Computational-Nonlinear-Filtering

**Language**: C++
**Domain**: Signal Processing, State Estimation, Bayesian Filtering

### Overview
Comprehensive C++ implementation of modern nonlinear filtering algorithms for state estimation in noisy environments. Implements particle filters, unscented Kalman filters (UKF), extended Kalman filters (EKF), ensemble Kalman filters (EnKF), and Gaussian sum filters.

### Technical Specifications
- **Particle Filter**: Sequential importance resampling (SIR), adaptive particle count, systematic/stratified/multinomial resampling
- **UKF**: Sigma-point generation via Cholesky decomposition, augmented state handling
- **EKF**: Analytical Jacobian computation, numerical differentiation fallback
- **Ensemble KF**: Monte Carlo state sampling, covariance inflation, localization
- **Gaussian Sum**: Multiple hypothesis tracking, weight update via Bayes rule

### Build & Integration
```bash
git clone https://github.com/n4hy/Modern-Computational-Nonlinear-Filtering
cd Modern-Computational-Nonlinear-Filtering
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Integration: Feed RF tracking data from Creeper Sweeper
./particle_filter --input ../data/rf_tracks.csv --output filtered_tracks.json
```

### Scrolls Integration
- **Signal tracking**: Filter noisy RSSI measurements from Kismet for precise device localization
- **Drone trajectory prediction**: UKF for predicting hostile drone flight paths from SDR captures
- **Multi-target tracking**: Gaussian sum filters for simultaneous tracking of multiple surveillance devices

---

## 2. PassiveRadar_Kraken

**Language**: Python/C++
**Domain**: Passive Radar, Signal Processing

### Overview
Passive radar system using KrakenSDR (5-channel coherent RTL-SDR array). Detects and tracks aircraft, vehicles, and drones by analyzing reflected ambient RF signals (FM radio, DVB-T, cellular) — emitting zero energy, making the system completely undetectable.

### Technical Specifications
- **Antenna array**: 5-element circular array (KrakenSDR)
- **Frequency range**: 24 MHz - 1.7 GHz per channel
- **Processing**: Cross-ambiguity function, range-Doppler mapping
- **Detection range**: 50+ km for aircraft (FM illuminator), 5+ km for drones (DVB-T)
- **Output**: Range, bearing, Doppler, target classification

### Build & Integration
```bash
git clone https://github.com/n4hy/PassiveRadar_Kraken
cd PassiveRadar_Kraken
pip install -r requirements.txt
sudo python3 kraken_passive_radar.py \
    --illuminator FM --freq 98.5e6 \
    --output passive_tracks.json

# Integration: Feed tracks to Creeper Sweeper correlation engine
python3 correlate_passive_radar.py --input passive_tracks.json --kismet kismet_devices.json
```

### Scrolls Integration
- **Covert drone detection**: Track hostile drones without emitting — no RF signature to detect
- **Airspace monitoring**: Community perimeter awareness of all aerial activity
- **Integration with Ghost Mesh**: Passive radar alerts trigger CSI adversarial broadcast

---

## 3. GnuRadio-SHTUFF

**Language**: Python/C++ (GNU Radio OOT modules)
**Domain**: Software-Defined Radio, Digital Signal Processing

### Overview
Collection of GNU Radio out-of-tree (OOT) modules implementing custom signal processing blocks, demodulators, protocol analyzers, and RF attack/defense tools for the ISM and SIGINT bands.

### Module Catalog
- **LoRa Toolkit**: Complete LoRa PHY implementation (transmit + receive), Meshtastic decoder
- **DroneDetector**: DJI OcuSync/MavLink protocol analyzer, drone telemetry extraction
- **WiFiTools**: 802.11 frame injection, deauth detection, WPS pin recovery
- **BLE Sniffer**: Bluetooth Low Energy advertisement dissector, GATT service explorer
- **RFReplay**: Universal RF capture and replay with timing preservation
- **SigInt**: Signal intelligence collection — automatic modulation recognition, baud rate estimation

### Build & Integration
```bash
git clone https://github.com/n4hy/GnuRadio-SHTUFF
cd GnuRadio-SHTUFF
mkdir build && cd build
cmake .. && make -j$(nproc)
sudo make install
sudo ldconfig

# Use in GNU Radio Companion
gnuradio-companion
# Open examples/drone_detector.grc
```

### Scrolls Integration
- **SDR-based kill switch**: LoRa replay to disable Unitree robot dogs
- **Drone telemetry extraction**: Decode DJI OcuSync for VULN-003 feed hijack
- **RF environment mapping**: Automatic modulation recognition for threat identification

---

## 4. NPU_OrangePi6Plus

**Language**: Python/C++
**Domain**: Edge AI, Embedded Systems

### Overview
Neural Processing Unit (NPU) optimization on Orange Pi 6 Plus (Rockchip RK3588). Deploys quantized neural networks for real-time signal classification, anomaly detection, and computer vision at the edge.

### Technical Specifications
- **Platform**: Orange Pi 6 Plus (RK3588, 6 TOPS NPU)
- **Framework**: RKNN-Toolkit2 for model conversion and optimization
- **Models**: INT8 quantized for NPU acceleration, FP16 for GPU fallback
- **Performance**: ~5 TOPS sustained, <2W power consumption
- **Applications**: Real-time drone detection from video, acoustic classification, RF anomaly detection

### Build & Integration
```bash
git clone https://github.com/n4hy/NPU_OrangePi6Plus
cd NPU_OrangePi6Plus
# Requires RKNN-Toolkit2 (Rockchip proprietary)
python3 convert_model.py --input model.h5 --output model.rknn
python3 deploy_inference.py --model model.rknn --camera 0
```

### Scrolls Integration
- **Edge ML for camera nodes**: Replace cloud-dependent surveillance analytics with on-device inference
- **Drone classification**: Visual confirmation of passive radar detections
- **Privacy-preserving**: All ML runs locally — no data leaves community network

---

## 5. OptimizedKernelsForRaspberryPi5_NvidiaCUDA

**Language**: C++/CUDA
**Domain**: High-Performance Computing, Embedded Systems

### Overview
Performance-optimized compute kernels for Raspberry Pi 5 (ARM NEON SIMD) and NVIDIA CUDA GPUs. Implements DSP primitives, matrix operations, FFT acceleration, and cryptographic operations at maximum throughput.

### Kernel Catalog
- **FFT**: ARM NEON-optimized radix-4 FFT (2× faster than FFTW on Pi 5), CUDA cuFFT wrappers
- **Matrix Multiply**: NEON SGEMM (4×4 micro-kernel), CUDA Tensor Core utilization
- **FIR Filter**: NEON vectorized FIR (8-tap parallel), CUDA overlap-save convolution
- **Crypto**: NEON-accelerated AES-GCM (16B/cycle), ML-KEM optimized polynomial multiplication
- **DSP**: Vectorized complex math, window functions, resampling

### Build & Integration
```bash
git clone https://github.com/n4hy/OptimizedKernelsForRaspberryPi5_NvidiaCUDA
cd OptimizedKernelsForRaspberryPi5_NvidiaCUDA

# Raspberry Pi 5 build
mkdir build_pi && cd build_pi
cmake .. -DPLATFORM=raspberrypi5 -DCMAKE_BUILD_TYPE=Release
make -j4

# CUDA build
mkdir build_cuda && cd build_cuda
cmake .. -DPLATFORM=cuda -DCMAKE_CUDA_ARCHITECTURES=86
make -j$(nproc)

# Benchmark
./benchmark_fft --size 4096 --iterations 1000
```

### Scrolls Integration
- **Real-time signal processing**: Accelerated FFT for SDR spectrum analysis on Pi 5
- **PQC performance**: Optimized ML-KEM/ML-DSA for embedded deployment
- **CSI processing**: Fast Fourier transforms for WiFi CSI extraction pipeline

---

## 6. UnifiedFlightTracker

**Language**: Python/C++
**Domain**: Aviation, Signal Processing

### Overview
Multi-source flight tracking system aggregating ADS-B (1090 MHz), Mode S, MLAT (multilateration), ACARS, and satellite-based tracking. Unified interface for monitoring all aerial activity — commercial, private, military, and drone.

### Technical Specifications
- **ADS-B**: 1090 MHz receiver (RTL-SDR), dump1090 integration
- **Mode S**: Selective interrogation, DF17/DF18 message decoding
- **MLAT**: Time-difference-of-arrival using multiple receivers
- **ACARS**: VHF data link monitoring (131.550 MHz)
- **Satellite**: ADS-B via Iridium (space-based tracking)
- **Output**: Real-time map, historical tracks, alerting on unusual activity

### Build & Integration
```bash
git clone https://github.com/n4hy/UnifiedFlightTracker
cd UnifiedFlightTracker
pip install -r requirements.txt
python3 unified_tracker.py \
    --adsb --mlat --acars \
    --web-server 8080
```

### Scrolls Integration
- **ICE flight monitoring**: Track deportation flights and surveillance aircraft
- **Drone fleet detection**: Identify military/law enforcement drone operations
- **Community alerting**: Push alerts when unusual aerial activity detected near sanctuaries

---

## 7. goes-hrit-live-webui

**Language**: Python, JavaScript
**Domain**: Satellite Communications, Meteorology

### Overview
Live reception and web-based visualization of GOES (Geostationary Operational Environmental Satellite) HRIT (High Rate Information Transmission) data. Receives full-disk Earth imagery, weather data, and emergency broadcasts.

### Technical Specifications
- **Satellite**: GOES-16/17/18 (East/West/Central)
- **Frequency**: 1694.1 MHz
- **Modulation**: BPSK, 400 ksps
- **Antenna**: 1.2m dish with 1694 MHz helical feed
- **Hardware**: RTL-SDR v3 or Airspy R2, LNA + bandpass filter
- **Data products**: Full-disk visible/IR imagery, EMWIN (emergency weather), DCS (data collection)

### Build & Integration
```bash
git clone https://github.com/n4hy/goes-hrit-live-webui
cd goes-hrit-live-webui
pip install -r requirements.txt
python3 goes_receiver.py --satellite GOES-18 --output ./images/
python3 webui.py --port 8080
```

### Scrolls Integration
- **Situational awareness**: Real-time weather imagery for community operations
- **Emergency communications**: EMWIN data for disaster alerts
- **Off-grid satellite capability**: No internet needed — direct satellite reception

---

## 8. HFPathSimulatorLiveData

**Language**: Python
**Domain**: RF Propagation, High Frequency Communications

### Overview
High Frequency (HF) radio propagation path simulator using live ionospheric data. Predicts optimal frequencies, takeoff angles, and expected signal quality for HF communications — critical for long-range emergency communications without satellite or internet dependency.

### Technical Specifications
- **Ionospheric data**: Real-time foF2, MUF from ionosondes and IRI model
- **Propagation models**: Ray tracing, VOACAP, ITU-R P.533
- **Frequency range**: 3-30 MHz
- **Output**: Frequency-availability maps, signal-to-noise predictions, circuit reliability

### Build & Integration
```bash
git clone https://github.com/n4hy/HFPathSimulatorLiveData
cd HFPathSimulatorLiveData
pip install -r requirements.txt
python3 hf_simulator.py \
    --tx 45.0,-85.0 --rx 65.0,-51.0 \
    --date 2026-05-24 --output hf_path.png
```

### Scrolls Integration
- **Emergency HF planning**: Predict usable frequencies for community-to-community HF links
- **NVIS optimization**: Plan near-vertical incidence skywave for regional coverage
- **Integration with AutoNVIS**: Combined NVIS propagation prediction

---

## 9. AutoNVIS

**Language**: Python/C++
**Domain**: RF Propagation, Emergency Communications

### Overview
Near Vertical Incidence Skywave (NVIS) propagation prediction and antenna optimization. NVIS enables regional HF communications (0-500 km) using low antennas and frequencies below the critical frequency — no infrastructure, no satellites, no repeaters.

### Technical Specifications
- **Propagation model**: Ionospheric ray tracing with real-time foF2 data
- **Antenna optimization**: Optimal frequency, height, and orientation for NVIS
- **Coverage prediction**: Signal strength maps for regional operations
- **Frequency management**: Automatic frequency selection based on time of day and solar activity

### Build & Integration
```bash
git clone https://github.com/n4hy/AutoNVIS
cd AutoNVIS
mkdir build && cd build
cmake .. && make -j$(nproc)
./autonvis --lat 45.0 --lon -85.0 --date 2026-05-24 --output nvis_plan.json
```

### Scrolls Integration
- **Community HF network**: Plan NVIS links between sanctuaries
- **Disaster communications**: Always-available regional comms when cellular/internet down
- **Integration with HFPathSimulator**: Combined short and long-range HF planning

---

## 10. AdaptiveFiltering

**Language**: C++/Python
**Domain**: Digital Signal Processing, Adaptive Systems

### Overview
Comprehensive adaptive filtering library implementing LMS, NLMS, RLS, QR-RLS, Kalman, and particle filter variants. Designed for real-time signal denoising, interference cancellation, echo suppression, and adaptive beamforming.

### Algorithm Catalog
- **LMS family**: Standard LMS, normalized LMS (NLMS), sign-error/sign-data/sign-sign variants
- **RLS family**: Standard RLS, QR-decomposition RLS, fast transversal RLS
- **Kalman variants**: Standard, extended (EKF), unscented (UKF), ensemble (EnKF)
- **Applications**: Noise cancellation, channel equalization, system identification, beamforming

### Build & Integration
```bash
git clone https://github.com/n4hy/AdaptiveFiltering
cd AdaptiveFiltering
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
./adaptive_noise_canceller --input noisy_signal.wav --reference noise_ref.wav --output clean.wav
```

### Scrolls Integration
- **Acoustic denoising**: Clean audio for voice assistant and sound classification
- **RF interference cancellation**: Remove jamming from legitimate signals
- **Beamforming**: Directional reception for locating surveillance transmitters

---

## 11. SolarImagingDisplay

**Language**: Python
**Domain**: Space Weather, Solar Physics

### Overview
Solar observation and imaging pipeline with live display. Captures solar imagery across multiple wavelengths, monitors solar activity (flares, CMEs, coronal holes), and provides space weather alerts affecting RF propagation and satellite communications.

### Technical Specifications
- **Data sources**: SDO (Solar Dynamics Observatory), SOHO, STEREO, GOES X-ray flux
- **Wavelengths**: H-alpha (656.3 nm), Ca-K (393.4 nm), white light, EUV (various)
- **Monitoring**: Sunspot number, flare classification (C/M/X), CME alerts, proton events
- **Display**: Live web dashboard with multi-wavelength composite views

### Build & Integration
```bash
git clone https://github.com/n4hy/SolarImagingDisplay
cd SolarImagingDisplay
pip install -r requirements.txt
python3 solar_display.py --web 8080
```

### Scrolls Integration
- **HF propagation prediction**: Solar activity directly affects ionospheric conditions
- **Communications planning**: Flare alerts warn of upcoming radio blackouts
- **Satellite operations**: Space weather affects all satellite-based systems

---

## 12. CoralDualEdgeTPU

**Language**: Python
**Domain**: Edge AI, Embedded ML

### Overview
Dual Google Coral Edge TPU integration for high-throughput ML inference at the edge. Supports model pipelining across two TPUs for doubled inference throughput, ideal for multi-camera or multi-sensor AI applications.

### Technical Specifications
- **Hardware**: 2× Google Coral USB Accelerator or 1× Dual TPU M.2 module
- **Performance**: 8 TOPS total (4 TOPS per TPU, INT8)
- **Power**: 2.5W per TPU
- **Framework**: TensorFlow Lite, PyCoral API
- **Pipelining**: Alternating inference across two TPUs, batch processing

### Build & Integration
```bash
git clone https://github.com/n4hy/CoralDualEdgeTPU
cd CoralDualEdgeTPU
pip install -r requirements.txt
python3 dual_tpu_inference.py \
    --model1 person_detector_edgetpu.tflite \
    --model2 drone_classifier_edgetpu.tflite \
    --camera 0
```

### Scrolls Integration
- **Multi-camera AI**: Run person detection + drone classification simultaneously
- **CSI processing acceleration**: Offload DensePose inference to TPUs
- **Alert pipeline**: Parallel model execution for faster threat detection

---

## 13. VisibleEphemerisCPP

**Language**: C++
**Domain**: Orbital Mechanics, Space Situational Awareness

### Overview
C++ library for computing visible satellite passes from any ground location. Calculates rise/set times, azimuth/elevation tracks, and illumination conditions for all publicly cataloged satellites — critical for understanding satellite surveillance overflight patterns.

### Technical Specifications
- **Orbit models**: SGP4/SDP4 for TLE propagation
- **Catalog**: CelesTrak TLE database (all public satellites)
- **Computation**: Azimuth, elevation, range, range-rate, illumination
- **Visibility**: Above-horizon filtering, sun-illumination, minimum elevation
- **Output**: Pass predictions, sky tracks, ground tracks

### Build & Integration
```bash
git clone https://github.com/n4hy/VisibleEphemerisCPP
cd VisibleEphemerisCPP
mkdir build && cd build
cmake .. && make -j$(nproc)
./visible_passes --lat 45.0 --lon -85.0 --min-elevation 10 --hours 24
```

### Scrolls Integration
- **Surveillance satellite tracking**: Predict when imaging satellites will overfly sanctuaries
- **Operational planning**: Schedule sensitive activities during satellite-gap windows
- **SAR satellite awareness**: Track synthetic aperture radar satellites that can image through clouds and darkness

---

## 14. vt-fox

**Language**: Python
**Domain**: Threat Intelligence, Malware Analysis

### Overview
VirusTotal automation and analysis toolkit. Automates file/URL submission, retrieves scan reports, and aggregates threat intelligence. Used for community network defense — checking suspicious files and URLs before opening.

### Technical Specifications
- **API**: VirusTotal v3 API integration
- **Automation**: Bulk file scanning, scheduled re-scans, hash lookups
- **Analysis**: Aggregated threat scoring, vendor consensus, behavioral analysis
- **Integration**: Webhook alerts, SIEM integration, incident response automation

### Build & Integration
```bash
git clone https://github.com/n4hy/vt-fox
cd vt-fox
pip install -r requirements.txt
export VT_API_KEY="your_key"
python3 vt_scan.py --file suspicious_binary.exe
python3 vt_monitor.py --watch-dir /home/user/Downloads --auto-scan
```

### Scrolls Integration
- **Community phishing defense**: Scan email attachments and links automatically
- **Malware detection**: Detect ICE/military malware targeting community devices
- **Threat intelligence**: Build community threat database from VT intelligence

---

## 15. documents

**Language**: Markdown, LaTeX
**Domain**: Technical Documentation, Research Archive

### Overview
Supplementary technical documentation and research archive supporting all other repositories. Contains whitepapers, implementation notes, mathematical derivations, experimental results, and integration guides.

### Contents
- **Signal processing theory**: Derivation of nonlinear filtering algorithms
- **RF propagation**: NVIS theory, ionospheric modeling, link budget calculations
- **SDR implementation**: GNU Radio block documentation, FPGA bitstream specifications
- **Embedded systems**: Pi 5 and ESP32 optimization guides
- **Security research**: CVE analysis, exploit chain documentation

### Access
```bash
git clone https://github.com/n4hy/documents
cd documents
# Browse organized by topic
ls signal_processing/ rf_propagation/ sdr/ embedded/ security/
```

### Scrolls Integration
- **Knowledge preservation**: Technical documentation ensures community can maintain systems
- **Training material**: Source content for community education programs
- **Research continuity**: Future generations can understand and extend the work

---

## Cross-Repository Integration Architecture

```
              ┌───────────────────────────────────────┐
              │         Creeper Sweeper (Pi 5)         │
              │  ┌─────────────────────────────────┐   │
              │  │ Detection Pipeline               │   │
              │  │  Modern-Computational-           │   │
              │  │  Nonlinear-Filtering (tracking)  │   │
              │  │  AdaptiveFiltering (denoising)   │   │
              │  │  GnuRadio-SHTUFF (SDR blocks)   │   │
              │  └─────────────────────────────────┘   │
              │  ┌─────────────────────────────────┐   │
              │  │ ML Inference                     │   │
              │  │  NPU_OrangePi6Plus               │   │
              │  │  CoralDualEdgeTPU                │   │
              │  │  OptimizedKernels (NEON)         │   │
              │  └─────────────────────────────────┘   │
              └──────────────────┬────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
   ┌────┴─────┐           ┌──────┴──────┐           ┌────┴─────┐
   │ Passive   │           │  Unified    │           │  HF/NVIS  │
   │ Radar     │           │  Flight     │           │  Network  │
   │ (Kraken)  │           │  Tracker    │           │           │
   └──────────┘           └─────────────┘           │ AutoNVIS  │
                                                     │ HFPath    │
        ┌────────────────────────────────────────────┤ Simulator │
        │                                            └──────────┘
   ┌────┴─────┐           ┌─────────────┐
   │ Satellite│           │  Space      │
   │ Imagery  │           │  Weather    │
   │          │           │             │
   │ GOES HRIT│           │ SolarImaging│
   │ Visible  │           │ Display     │
   │ Ephemeris│           └─────────────┘
   └──────────┘
```

---

## Exercises & Assessment

1. **Lab 9.1**: Build and deploy the PassiveRadar_Kraken system. Detect at least 5 aircraft without emitting any RF energy.

2. **Lab 9.2**: Integrate GnuRadio-SHTUFF LoRa blocks with the Creeper Sweeper for Meshtastic node detection.

3. **Lab 9.3**: Deploy the UnifiedFlightTracker and correlate ADS-B tracks with visual/radar observations over 24 hours.

4. **Lab 9.4**: Use VisibleEphemerisCPP to predict surveillance satellite passes over a community location. Verify with visual observation.

5. **Lab 9.5**: Build an HF emergency communications plan using AutoNVIS and HFPathSimulatorLiveData. Test the link between two locations >200km apart.

6. **Capstone Integration**: Deploy the full stack — passive radar, flight tracker, satellite ephemeris, and HF planning — as a unified situational awareness system for community defense.

---

*Volume 9 of 9 — GitHub Repository Catalog. This concludes the capstone book series.*
*All repositories are MIT-licensed. Build, deploy, defend. The knowledge belongs to the people.*
