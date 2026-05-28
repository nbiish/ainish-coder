# Deep Extraction: Signals, Radio & Physics from n4hy Repositories

> **Source**: 15 GitHub repositories cloned May 2026
> **Extraction**: Passive radar DSP, nonlinear filtering theory, adaptive filtering math, ionospheric propagation physics, orbital mechanics, GPU kernel design, SDR signal chains
> **Fused into**: Digital Midewiwin Scrolls — Survival Architecture Knowledge Domain

---

## 1. PASSIVE RADAR SIGNAL PROCESSING CHAIN (PassiveRadar_Kraken)

### 1.1 Full 10-Stage Pipeline

The `run_passive_radar.py` chain implements production-grade passive bistatic radar using 5-channel coherent KrakenSDR:

```
KrakenSDR (5-ch coherent) → PhaseCorr → AGC → Block B3 (Ref Reconstruct) → 
ECA-B Clutter Cancel → CAF → Doppler FFT → CFAR Detect → Cluster → 
AoA (Bartlett/MUSIC) → Kalman Tracker → Display
```

### 1.2 ECA-B Clutter Cancellation (eca_b_clutter_canceller.cpp)

**Mathematics**: Extensive Cancellation Algorithm — Batch variant. Solves the clutter suppression problem via Toeplitz least-squares.

```
Given:
  s_surv[n] = surveillance signal (contains target echo + clutter)
  s_ref[n]  = reference signal (clean illuminator)
  M         = filter length (num_taps, typically 32-128)

Model:  s_clutter[n] = Σ_{k=0}^{M-1} w[k] · s_ref[n-k]

ECA-B solves:  w = argmin ||s_surv - Xw||² + λ||w||²

where X is a Toeplitz matrix constructed from s_ref, and λ is Tikhonov regularization.

The batch Toeplitz least-squares uses FFT-based cross-correlation:
  R_xr = IFFT( FFT(s_ref*) · FFT(s_surv) )   [cross-correlation]
  R_xx = IFFT( |FFT(s_ref)|² )                 [autocorrelation]

Then solves:  R_xx · w = R_xr   via Cholesky decomposition

Implementation note: The diagonal recursion uses conj(u)*v (not u*conj(v)).
This bug was fixed in the 2026-03-23 audit — conjugated off-diagonal elements
produced incorrect autocorrelation, now corrected.
```

**GPU Acceleration**: cuSOLVER Cholesky on RTX 5090 — ~50ms CPU → <1ms GPU (50× speedup).

### 1.3 Cross-Ambiguity Function (caf_processing.cpp)

**Mathematics**: The CAF is the core passive radar detection operation — it computes the 2D correlation between reference and surveillance signals across delay (bistatic range) and Doppler shift.

```
CAF[τ, f_d] = |Σ_{n=0}^{N-1} s_surv[n] · s_ref*[n-τ] · exp(-j2π f_d n/N)|²

Where:
  τ     = time delay (bistatic range = τ · c / 2)
  f_d   = Doppler frequency shift
  N     = CPI length (coherent processing interval, typically 1024-4096 samples)

Implementation uses batched FFT for efficiency:
  1. FFT both s_surv and s_ref (zero-padded to 2N to avoid circular correlation)
  2. Multiply: S_surv[f] · S_ref*[f] · exp(-j2π f τ)
  3. IFFT → time-domain correlation for all delays at once
  4. Repeat for each Doppler bin with phase rotation

Doppler resolution:  Δf = f_s / N
Range resolution:    ΔR = c / (2 · BW)
Maximum unambiguous range: R_max = c · N / (2 · f_s)
```

**GPU**: Batched cuFFT on RTX 5090 — 46.7ms → 2.03ms (23× speedup).

### 1.4 CFAR Detection (cfar_detector_impl.cc)

**Mathematics**: Constant False Alarm Rate detection. Four variants implemented:

```
Cell-Averaging (CA-CFAR):
  Threshold = α · (1/N_train) · Σ_{i∈training} x_i

Greatest-Of (GO-CFAR):
  Threshold = α · max(μ_leading, μ_lagging)

Smallest-Of (SO-CFAR):
  Threshold = α · min(μ_leading, μ_lagging)

Ordered-Statistic (OS-CFAR):
  Threshold = α · x_{(k)}  [k-th ordered sample from training cells]

Where:
  α = N_train · (P_fa^{-1/N_train} - 1)   [threshold multiplier for desired false alarm rate]
  Guard cells prevent target self-masking
  Training cells estimate local noise power
```

**Optimization**: O(n²) → O(n) via integral image (summed area table). Each cell's noise estimate computed in O(1) instead of O(N_train²). 10-50× speedup.

**GPU**: Parallel 2D CFAR on CUDA — 592ms → 1.94ms (305× speedup on RTX 5090). Most dramatic acceleration in the pipeline.

### 1.5 AoA Estimation (aoa_processing.cpp)

**Bartlett Beamformer**:
```
P(θ) = |a(θ)^H · x|² / ||a(θ)||²

where a(θ) = [1, exp(j·2π·d/λ·sin(θ)), ..., exp(j·2π·(M-1)·d/λ·sin(θ))]^T
      d/λ = element spacing in wavelengths (typically 0.5)
```

**MUSIC (MUltiple SIgnal Classification)**:
```
1. Compute spatial covariance:  R = (1/K) Σ_{k=1}^K x_k · x_k^H
2. Eigendecomposition: R = U_s Λ_s U_s^H + U_n Λ_n U_n^H
3. MUSIC spectrum: P_MUSIC(θ) = 1 / (a(θ)^H · U_n · U_n^H · a(θ))
4. Peak search over θ → AoA estimates

Requires: n_sources < M (array elements). Must specify n_sources correctly.
```

**ULA Steering Vector**: Uses OptMathKernels `radar::steering_vector_ula_f32` (NEON-accelerated phase computation via `neon_complex_exp_f32`).

### 1.6 Kalman Tracker (tracker_impl.cc)

Multi-target tracking with Global Nearest Neighbor (GNN) association. Uses Modern-Computational-Nonlinear-Filtering (MCNF) FilterMath dispatch for SVE2/NEON-accelerated Kalman gain computation.

```
State: [x, y, vx, vy]^T  (position + velocity)
Process model: constant velocity (CV)
Measurement: [range, bearing, doppler] from CAF + AoA

Association: GNN with Mahalanobis distance gating
  d² = (z - Hx̂)ᵀ S⁻¹ (z - Hx̂) < gate_threshold
  S = HPHᵀ + R  (innovation covariance)

Track lifecycle:
  - Tentative: N confirm detections needed (typically 2-3)
  - Active: confirmed track, output to display
  - Coasting: missed M consecutive updates, still propagated
  - Deleted: exceeded max coasting time
```

**GPU UKF**: Multi-target Unscented Kalman Filter with parallel sigma point propagation via CUDA streams.

### 1.7 Block B3 Reference Signal Reconstruction

**FM Mode** (for civilian FM broadcast illuminators):
```
1. Quadrature FM demodulation → audio signal
2. 1157-tap audio lowpass filter (15 kHz cutoff)
3. 57819-tap 19 kHz pilot BPF (stereo pilot regeneration)
4. 75 μs pre-emphasis (US broadcast standard)
5. FM remodulation → clean reference signal

Result: 10-15 dB SNR improvement in reference channel.
        CAF peaks 2-4× sharper. Detection range increases 30-50%.
```

**ATSC 3.0 Mode** (for NextGen TV illuminators):
```
1. OFDM demodulation via FFT (8K/16K/32K modes)
2. LDPC forward error correction (placeholder — full impl pending)
3. SVD-based pilot enhancement:
   - Compute SVD of pilot subcarrier matrix
   - Reconstruct with 90% energy threshold (3-5 dB pilot improvement)
4. OFDM remodulation via IFFT → clean reference

Result: 15-20 dB SNR improvement (when LDPC is operational).
```

---

## 2. NONLINEAR FILTERING THEORY (Modern-Computational-Nonlinear-Filtering)

### 2.1 Unscented Kalman Filter (UKF)

**Core Algorithm** — derivative-free state estimation via deterministic sigma point sampling:

```
1. SIGMA POINT GENERATION (Merwe scaled unscented transform):
   ┌────────────────────────────────────────────────┐
   │ λ = α²(n + κ) - n                              │
   │ σ_0 = x̂                                         │
   │ σ_i = x̂ + [√((n+λ)P)]_i     for i=1...n        │
   │ σ_{i+n} = x̂ - [√((n+λ)P)]_i  for i=1...n       │
   │                                                │
   │ Weights:                                       │
   │ Wm_0 = λ/(n+λ)          [mean weight]          │
   │ Wc_0 = λ/(n+λ) + (1-α²+β)  [cov weight]        │
   │ Wm_i = Wc_i = 1/(2(n+λ))  for i=1...2n        │
   └────────────────────────────────────────────────┘

2. PREDICT:
   σ_i⁻ = f(σ_i)                    [propagate sigma points through process model]
   x̂⁻ = Σ Wm_i · σ_i⁻               [weighted mean]
   P⁻ = Σ Wc_i · (σ_i⁻ - x̂⁻)(σ_i⁻ - x̂⁻)ᵀ + Q  [covariance]

3. UPDATE:
   γ_i = h(σ_i⁻)                    [propagate through measurement model]
   ŷ = Σ Wm_i · γ_i                 [predicted measurement]
   P_yy = Σ Wc_i · (γ_i - ŷ)(γ_i - ŷ)ᵀ + R  [innovation covariance]
   P_xy = Σ Wc_i · (σ_i⁻ - x̂⁻)(γ_i - ŷ)ᵀ    [cross-covariance]
   K = P_xy · P_yy⁻¹                [Kalman gain]
   x̂ = x̂⁻ + K·(y - ŷ)               [state update]
   P = P⁻ - K·P_yy·Kᵀ               [covariance update (Joseph form)]
```

**Parameters**: α=1.0 (spread), β=2.0 (optimal for Gaussian), κ=3-n (dimension-dependent).

**Key insight for embedded deployment**: Sigma point weight explosion when n+λ→0. Guard:
```cpp
if (n_lambda < 0.5f) {
    kappa = n / (alpha * alpha) - n;
    lambda = alpha * alpha * (n + kappa) - n;
}
```

### 2.2 Square Root UKF (SRUKF)

Propagates Cholesky factor S where P = S·Sᵀ. Avoids explicit covariance matrix, numerically superior:

```
PREDICT (SR form):
  1. Generate sigma points from S (not P)
  2. Propagate through process model
  3. Compute weighted mean x̂⁻
  4. Compute S⁻ via QR decomposition:
     [√Wc_1(σ₁⁻ - x̂⁻), ..., √Wc_{2n}(σ_{2n}⁻ - x̂⁻), √Q]ᵀ = QR
     S⁻ = Rᵀ (upper triangular from QR)

UPDATE (SR form):
  1. Propagate sigma points through measurement model
  2. Compute S_yy via QR
  3. Compute P_xy (cross-covariance)
  4. K = (P_xy / S_yyᵀ) / S_yy   [forward/back substitution, avoids explicit inverse]
  5. x̂ = x̂⁻ + K·(y - ŷ)
  6. S = cholupdate(S⁻, K·S_yy, -1)  [rank-1 Cholesky downdate]

CRITICAL: cholupdate downdate can fail when update magnitude exceeds factor.
Safe fallback: detect negative diagonal → recompute P from sigma points → fresh Cholesky.
```

**Numerical issues discovered and fixed**:
1. **Eigen aliasing in mean computation**: Expression templates caused X_pred to alias sigmas.X memory. Fixed with `.eval()` to force materialization.
2. **Global -ffast-math**: Caused NaN guards (`isfinite()`) to be optimized away. Removed from Release builds. Use `-fno-fast-math` for numerically sensitive targets.
3. **Innovation gating**: After GPS outage, large position errors caused Mahalanobis gating to reject valid measurements. Fixed by reinitializing filter around measurements when outage ends.
4. **Cholesky downdate**: Unsafe `cholupdate` silently corrupted covariance. Replaced with `cholupdate_downdate_safe()` that returns false and triggers full recomputation.

### 2.3 Particle Filter (PKF) — Bootstrap SIR

For non-Gaussian, multimodal distributions where UKF fails:

```
1. INITIALIZE: Draw N particles from prior p(x₀)

2. PREDICT: x_kⁱ ~ p(x_k | x_{k-1}ⁱ, u_k)

3. UPDATE: w_kⁱ = w_{k-1}ⁱ · p(y_k | x_kⁱ)
           w_kⁱ = w_kⁱ / Σ w_kⁱ   [normalize]

4. RESAMPLE (when N_eff < N/2):
   Systematic or stratified resampling with Kahan compensated summation
   (fixes O(N) float rounding bias that underselected last particles)

5. ESTIMATE: x̂_k = Σ w_kⁱ · x_kⁱ
```

**GPU Acceleration**: Vulkan compute shaders for particle noise addition, OpenMP for parallel propagation. CUDA particle context with GPU log-sum-exp weight normalization.

### 2.4 Rao-Blackwellized Particle Filter (RBPKF)

Marginalizes linear substructure analytically via conditional Kalman filters per particle. Reduces variance vs standard PF when system has conditionally linear subspace (e.g., CTRV models with linear velocity dynamics):

```
State split: x = [x_nl | x_lin]
  x_nl: nonlinear part (estimated via particles)
  x_lin: linear part (estimated via Kalman per particle)

For each particle i:
  Kalman predict: x̂_linⁱ⁻, P_linⁱ⁻
  PF weight: wⁱ = p(y | x_nlⁱ, x̂_linⁱ⁻)
  Kalman update: x̂_linⁱ, P_linⁱ  (conditional on particle's nonlinear state)
```

### 2.5 RTS Fixed-Lag Smoother

Rauch-Tung-Striebel backward pass improves historical estimates:

```
FOR k = K-1, K-2, ..., 0:
  C_k = P_k · F_kᵀ · (P_{k+1}⁻)⁻¹     [smoother gain]
  x̂_kˢ = x̂_k + C_k · (x̂_{k+1}ˢ - x̂_{k+1}⁻)  [smoothed state]
  P_kˢ = P_k + C_k · (P_{k+1}ˢ - P_{k+1}⁻) · C_kᵀ

Improvements measured:
  - Coupled oscillators (10D): RMSE improves 21%
  - Bearing-only tracking (4D): RMSE improves 19%
  - Reentry vehicle (6D): RMSE improves 36%
  - Drag ball (4D): RMSE improves 48-53%
```

---

## 3. ADAPTIVE FILTERING MATHEMATICS (AdaptiveFiltering)

### 3.1 NLMS Filter

The Normalized Least Mean Squares filter is scale-invariant and self-normalizing — ideal for unknown signal amplitudes:

```
FILTERING:  y[n] = Σ_{k=0}^{M-1} conj(w[k]) · x[n-k]   [complex convention]
            e[n] = d[n] - y[n]                            [error signal]

UPDATE:     w[k] ← w[k] + μ · conj(e[n]) · x[n-k] / (||x||² + ε)
                                                          [ε prevents div-by-zero]

CONVERGENCE: 0 < μ < 2 for stability
             μ ≈ 1.0 for fastest convergence (when noise floor known)
             μ ≈ 0.01 for robust tracking with high noise
```

### 3.2 Block NLMS with FFT Overlap-Save

For M > 32 taps, automatically switches from time-domain to frequency-domain via FFT overlap-save:

```
1. Pad filter to N = next_smooth(M)  [FFT-friendly size: 2^a · 3^b · 5^c · 7^d]
2. FFT of zero-padded filter: W = FFT([w; zeros(N-M)])
3. For each block of L = N-M+1 samples:
   a. FFT of input block: X = FFT(last M-1 samples + new L samples)
   b. Frequency-domain convolution: Y = X · W
   c. IFFT → y (keep last L samples, discard M-1 wrap-around)
   d. Compute error: e = d - y
   e. FFT of zero-padded error: E = FFT([zeros; e; zeros])
   f. Gradient in frequency domain: ∇ = conj(X) · E
   g. IFFT → time-domain gradient (keep first M samples)
   h. Weight update: w ← w + (μ / (||X||² + ε)) · ∇
   i. Update frequency-domain weights: W = FFT([w; zeros(N-M)])

Computational complexity:
  Time-domain: O(M·L) per block
  FFT:         O(N·log(N)) per block
  FFT wins when M > ~32 taps
```

### 3.3 FFTW Wisdom Caching

Persistent FFT plan optimization stored in `~/.adapt_fftw_wisdom`:
- Plan creation time reduced 10-100× on subsequent runs
- Thread-safe: mutex-protected plan creation
- FFT sizes chosen with small prime factors (2, 3, 5, 7) for optimal FFTW performance
- Wisdom saved on plan destruction, loaded on library init

---

## 4. IONOSPHERIC PROPAGATION PHYSICS

### 4.1 Vogler-Hoffmeyer Ionospheric Propagation Model (HFPathSimulator)

The Vogler-Hoffmeyer model (NTIA Technical Report TR-88-240) provides physically-accurate ionospheric reflection coefficient computation:

**Reflection Coefficient R(ω)**:
```
R(ω) uses the complex gamma function Γ(z) to model the frequency-dependent
reflection from the ionospheric layers (D, E, F1, F2):

R(ω) involves:
  1. Frequency-dependent refractive index: n²(f) = 1 - (f_p²/f²)
     where f_p = √(N_e · e²/(ε₀ · m_e)) / (2π)  [plasma frequency]

  2. Electron density profile N_e(h):
     - Chapman layer model: N_e(h) = N_m · exp(½(1 - z - e^{-z}))
       where z = (h - h_m) / H  (reduced height)
     - IRI-2020 model for realistic profiles

  3. Complex integration through the ionosphere to compute R(ω)

Group delay: τ_g(ω) = dφ(ω)/dω  [derivative of phase w.r.t frequency]

The model predicts:
  - Amplitude response |R(ω)| vs frequency
  - Phase response φ(ω) vs frequency
  - Group delay variation across signal bandwidth
  - Multi-mode propagation (1F2, 2F2, E-layer, Es)
```

### 4.2 Ionospheric Ray Tracing (AutoNVIS)

**Haselgrove Equations** (2D spherical geometry):

```
dr/dt = c · (∂H/∂k_r) / |∂H/∂k|
dθ/dt = c · (∂H/∂k_θ) / (r · |∂H/∂k|)
dk_r/dt = -c · (∂H/∂r) / |∂H/∂k| + k_θ · dθ/dt
dk_θ/dt = (-c · (∂H/∂θ) / |∂H/∂k| - k_θ · dr/dt + k_r · r · dθ/dt) / r

where H is the Hamiltonian, k is the wave vector, (r,θ) are spherical coordinates.
```

**Integrators implemented**:
- **RK4**: Classic Runge-Kutta 4th order — best accuracy/cost ratio for smooth profiles
- **RK45 Dormand-Prince**: Adaptive step size — handles sharp electron density gradients
- **Adams-Bashforth**: Multi-step — efficient for smooth trajectories

**Winner Triplet Homing Algorithm**:
```
1. Launch fan of rays at different elevation angles
2. For each ray, integrate until ground return or escape
3. Calculate ground range for each returning ray
4. Find triplets: three adjacent rays where central ray's ground range
   is closer to target than the outer two
5. Bisect within triplet until ground range converges to target
6. Output: elevation angle, group delay, phase path, apogee, number of hops
```

### 4.3 Sporadic-E Layer Physics

```
Es layer characteristics:
  - Thin (1-5 km), dense ionized layer at ~100-120 km altitude
  - Formed by wind shear concentrating metallic ions (Fe+, Mg+)
  - Critical frequency foEs: 3-20+ MHz (highly variable)
  - Seasonal: peak in summer (NH: May-August), secondary peak in winter
  - Diurnal: peaks midday, minimum pre-dawn
  - Latitude dependence: strongest at mid-latitudes, weak at equator

Modeling:
  Chapman layer: N_e(h) = N_m · exp(½(1 - z - e^{-z}))
  with h_m ≈ 105 km, H ≈ 1-2 km (very thin layer)

Presets for Es:
  Weak:   foEs = 3 MHz,  hmEs = 105 km
  Moderate: foEs = 7 MHz,  hmEs = 105 km
  Strong: foEs = 12 MHz, hmEs = 105 km
  Intense: foEs = 20 MHz, hmEs = 100 km
```

### 4.4 Geomagnetic Effects on Propagation

```
F10.7 Solar Flux: 
  - Proxy for solar EUV radiation
  - Scales foF2: foF2 ∝ (F10.7)^0.25
  - Typical range: 70 (solar minimum) to 300+ (solar maximum)
  - 2025-2026: Solar Cycle 25 maximum — elevated F10.7, enhanced F2

Kp Index (0-9):
  - 3-hour planetary geomagnetic activity
  - Kp 0-2: Quiet — minimal Doppler spread
  - Kp 3-4: Active — moderate Doppler/delay spread
  - Kp 5-6: Minor storm — elevated spread, possible auroral E
  - Kp 7-9: Major storm — severe degradation, polar blackouts

Dst Index (nT):
  - Storm-time disturbance — measures ring current
  - Dst < -50 nT: Minor storm
  - Dst < -100 nT: Major storm — significant foF2 depression
  - Dst < -200 nT: Severe storm — equatorial ionosphere severely disturbed

Storm phases:
  Initial: Sudden commencement (SSC) — compression, enhanced foF2 briefly
  Main: foF2 depression for hours to days
  Recovery: Gradual return to quiet-time values (1-3 days)
```

### 4.5 ITU-R Channel Models

```
CCIR 520 / ITU-R F.520-2 presets:
  Quiet:     τ = 0.5 ms,  ν = 0.1 Hz   (benign mid-latitude)
  Moderate:  τ = 2.0 ms,  ν = 1.0 Hz   (typical daytime)
  Disturbed: τ = 4.0 ms,  ν = 2.0 Hz   (magnetic storm)
  Flutter:   τ = 7.0 ms,  ν = 10.0 Hz  (high-latitude auroral)

Delay spread τ: RMS delay spread of ionospheric multipath
Doppler spread ν: 1/e width of Doppler spectrum from ionospheric motion
```

### 4.6 NVIS Propagation Engineering

```
NVIS (Near Vertical Incidence Skywave):
  - Frequency range: typically 2-10 MHz (depends on foF2)
  - Takeoff angle: 70-90° (near-vertical)
  - Antenna: low horizontal dipole (~0.15λ above ground)
  - Range: 0-500 km (regional, no skip zone)
  - Advantage: fills the "skip zone" of conventional HF skywave

NVIS frequency selection:
  f_opt ≈ 0.85 · foF2  (optimal working frequency for NVIS)
  f_max = foF2 · sec(φ) where φ is zenith angle
  Below f_opt: D-layer absorption increases (∝ 1/f²)
  Above foF2: signal penetrates ionosphere, no return

Critical frequency prediction:
  foF2 = f(F10.7, solar zenith angle, latitude, season, time)
  foF2 varies from ~3 MHz (night, low sunspot) to ~15+ MHz (day, high sunspot)
```

---

## 5. ORBITAL MECHANICS (VisibleEphemerisCPP)

### 5.1 SGP4/SDP4 Propagator

```
SGP4 (Simplified General Perturbations 4): For near-Earth satellites (period < 225 min)
SDP4 (Simplified Deep-space Perturbations 4): For deep-space objects (period ≥ 225 min)

Input: Two-Line Element (TLE) set
  Line 1: Satellite number, classification, launch data, epoch, drag term, etc.
  Line 2: Inclination, RAAN, eccentricity, argument of perigee, mean anomaly, mean motion

Output: Position (ECI) and velocity at specified time

Key perturbations modeled:
  - Earth's oblateness (J2, J3, J4 zonal harmonics)
  - Atmospheric drag (simplified static model)
  - Solar/lunar gravitational perturbations (deep-space only)
  - Resonance effects (geosynchronous, Molniya orbits)

Accuracy: ~1 km at epoch, degrades ~1-3 km/day
Validity: TLE should be < 30 days old for best accuracy

IMPORTANT: Never propagate a TLE backward years. SGP4 error grows
rapidly. Use historical TLE retrieval (Space-Track.org gp_history) for
past dates — the 2026 implementation caches these permanently.
```

### 5.2 Visibility Calculation

```
A satellite is VISIBLE when:
  1. Elevation > min_el (typically 0° or user-specified)
  2. Satellite is sunlit (solar elevation at satellite > 0°)
  3. Observer is in darkness (solar elevation at observer < -6° for civil twilight)

Specular reflection (flare) detection:
  Flare occurs when the satellite's solar panel or body reflects sunlight
  directly to the observer. Compute the phase angle between sun→sat→observer.
  When phase angle is small (< 5-10°), a flare is likely.

Flare magnitude estimation (simplified):
  m_flare = m_std - 2.5·log₁₀(A·γ/(π·R²))
  where A = reflective area, γ = reflectivity, R = slant range
```

### 5.3 Doppler Shift for Radio Tracking

```
Doppler shift for satellite communications:
  Δf = -f₀ · (v_r / c)
  where v_r = radial velocity (range rate), positive if receding

Maximum Doppler (LEO, 400 km orbit):
  v_orbital ≈ 7.67 km/s  →  Δf_max ≈ ±50 kHz at 2 GHz
  Rate of change: ~1 kHz/s near zenith

Hamlib integration: Automated transceiver frequency correction
  f_tx = f_nominal - Δf
  Updates at 1-10 Hz rate for smooth tracking
```

---

## 6. GPU KERNEL DESIGN (OptimizedKernelsForRaspberryPi5_NvidiaCUDA)

### 6.1 NEON SIMD Acceleration (ARM Cortex-A76)

The library provides 13+ radar-optimized NEON kernels used across PassiveRadar_Kraken, AdaptiveFiltering, and MCNF. Key patterns:

**Complex Dot Product (neon_complex_dot_f32)**:
```
ARM NEON: 128-bit registers = 2× float32 complex values
Inner loop: vld1q_f32 ×2 (load 2 complex), 
            vcmlaq_f32 (complex multiply-accumulate in 1 instruction)
Unroll 4×: Process 8 complex values per iteration
Result: 8× throughput vs scalar
```

**SVE2 Cache-Blocked GEMM (for Cortex-A720 on Orange Pi)**:
```
8×8 microkernel with svmla_n_f32_z FMA (fused multiply-add)
Cache blocking tuned for 12MB L3:
  MC = 256  (rows of A in L2 cache)
  KC = 512  (inner dimension)
  NC = 2048 (columns of B, fits in L3)

Features:
  - svwhilelt predication: zero tail-handling code (vs 28+ NEON tail loops)
  - FCMA: 2-instruction complex multiply (svcmla) vs 4 NEON instructions
  - I8MM: int8 matrix multiply (svmmla_s32) for quantized neural nets
```

**CUDA Radar Kernels**:
```
CAF batched cuFFT: cufftPlanMany with batch = num_doppler_bins
CFAR 2D: Parallel thresholding with shared memory for guard/training cells
ECA cuSOLVER: Cholesky decomposition for Toeplitz least-squares
UKF GPU: Parallel sigma point propagation across all tracks
```

### 6.2 FFTW Threading Patterns

```
Centralized FFTW init via pthread_once (libkraken_fftw_init):
  - fftwf_init_threads() called exactly once
  - fftwf_plan_with_nthreads(n) configures thread count
  - Plans cached per-thread, wisdom loaded at startup

Wisdom file: ~/.adapt_fftw_wisdom (persistent across runs)
  - Saves optimal plan decomposition for each FFT size
  - Reduces plan creation from ~100ms to <1ms for cached sizes
```

---

## 7. SDR SIGNAL CHAINS (GnuRadio-SHTUFF)

### 7.1 Iridium Ring Monitor

GNU Radio flowgraph for passive monitoring of Iridium satellite paging channels:
```
Antenna (1.6 GHz L-band) → RTL-SDR → Quadrature Demod → 
Clock Recovery → I/Q Sink → Analysis
```

Iridium signal characteristics:
- Frequency: 1616-1626.5 MHz
- TDMA: 90 ms frames, 4 uplink + 4 downlink slots
- Modulation: QPSK (downlink), DE-QPSK (uplink)
- Bandwidth: 31.5 kHz per channel
- Used for: Paging, messaging, voice, SBD (short burst data)

### 7.2 Stereo FM Demod (Science Bob)

Complete stereo FM demodulator with:
- Quadrature demodulation
- Stereo pilot recovery (19 kHz)
- L-R subcarrier demodulation (38 kHz DSB-SC)
- De-emphasis filtering
- Audio matrix (L+R, L-R → L, R)

---

## 8. PRACTICAL INTEGRATION — SCROLL SURVIVAL APPLICATIONS

### 8.1 Passive Radar for Sanctuary Perimeter Detection

The PassiveRadar_Kraken pipeline, deployed on a Raspberry Pi 5 with KrakenSDR, provides completely passive (zero-emission) aircraft and drone detection:

```
Deployment:
  1. KrakenSDR at elevated position with 5-element circular array
  2. Reference antenna aimed at local FM broadcast tower (~100 MHz)
  3. 4 surveillance antennas in UCA configuration for 360° coverage
  4. RPi5 processing at ~10 Hz update rate (CPU) or 100+ Hz (GPU)

Capabilities (passive, undetectable):
  - Aircraft detection: 60+ km range (using FM illuminator)
  - Drone detection: 5+ km range (1 MHz bandwidth)
  - Direction finding: ±2° accuracy (Bartlett), ±1° (MUSIC)
  - Multi-target tracking: 20+ simultaneous tracks with UKF

Integration with Ghost Mesh:
  Passive radar detects approaching drone →
  Automatic DRFM activation on detected bearing →
  Ghost Mesh CSI adversarial broadcast →
  Community alerted via LoRa mesh
```

### 8.2 Nonlinear Filtering for RF Signal Tracking

The UKF/SRUKF from MCNF applied to signal intelligence:
```
State: [x, y, vx, vy] — target position and velocity
Measurement: [RSSI, bearing, doppler] from Creeper Sweeper

UKF handles the severe nonlinearity of bearing-only measurements
(atan2(y/x) is highly nonlinear at close range).

SRUKF provides guaranteed positive-definite covariance — critical for
long-duration tracking where numerical drift accumulates.

RTS smoother applied retroactively: After a patrol passes, the full
trajectory can be reconstructed with 20-50% improved accuracy for
forensic evidence.
```

### 8.3 HF Emergency Communications Planning

AutoNVIS + HFPathSimulator for community-to-community links:
```
1. Input: TX and RX coordinates, date, time
2. AutoNVIS computes optimal NVIS frequency based on:
   - Real-time ionosonde data (GIRO network, 27 stations)
   - GNSS-TEC data (real-time total electron content)
   - SR-UKF assimilated ionospheric state estimate
3. HFPathSimulator models the channel:
   - Vogler-Hoffmeyer reflection coefficient → frequency response
   - ITU-R F.1487 delay/Doppler spread → signal degradation
   - SNR prediction: TX power + antenna gain - path loss - noise floor
4. Output: Optimal frequency, expected SNR, reliability estimate

Deployment: Xiegu G90 (20W HF) + NVIS dipole + AutoNVIS on RPi5
Range: 0-500 km regional, no infrastructure dependency
```

### 8.4 Satellite Surveillance Overflight Prediction

VisibleEphemerisCPP for tracking surveillance satellite passes:
```
1. Load TLE catalog (CelesTrak, updated daily)
2. Filter by group: USA military, reconnaissance, SAR satellites
3. Compute all passes for next 24 hours at community location
4. Identify observation windows (times when imaging sats are overhead)
5. Schedule sensitive community activities during satellite-gap windows

SAR (Synthetic Aperture Radar) satellites of concern:
  - Capella Space (commercial, sells to military)
  - ICEYE (commercial, sells to military)
  - Umbra (commercial, sells to military)
  - USA-224 through USA-290 series (NRO)

These satellites can image through clouds and darkness.
Knowing their overflight times is critical for operations planning.
```

### 8.5 Edge AI for Real-Time Threat Classification

NPU_OrangePi6Plus + CoralDualEdgeTPU integration:
```
Pipeline:
  1. Camera (XIAO ESP32-S3 Sense) → video stream
  2. Coral Edge TPU: person detection (MobileNet SSD, 30 fps)
  3. Orange Pi NPU: drone classification (custom model, 5 TOPS)
  4. Dual TPU pipelining: alternating inference for 2× throughput
  5. Alert on: person + drone + vehicle → compound threat classification

The `sky_watcher.py` example monitors for aerial threats:
  - Classifies: birds, drones, aircraft, helicopters
  - Tracks motion vector, size, speed
  - Alerts on: small fast-moving object approaching community perimeter
```

---

## 9. COST ASYMMETRY — THE HARDWARE STACK

All 15 repositories, deployed on community hardware:

| System | Hardware | Cost | Repos Used |
|--------|----------|------|-------------|
| Passive Radar Perimeter | KrakenSDR + RPi5 | $675 | PassiveRadar_Kraken, OptMathKernels, MCNF, AdaptiveFiltering |
| HF Emergency Comms | Xiegu G90 + RPi5 | $945 | AutoNVIS, HFPathSimulator, SolarImagingDisplay |
| Satellite Overflight Prediction | RPi5 (no RF hardware needed) | $80 | VisibleEphemerisCPP |
| Edge AI Threat Detection | Orange Pi 6 Plus + Dual Coral TPU | $350 | NPU_OrangePi6Plus, CoralDualEdgeTPU, OptMathKernels |
| SDR Signal Intelligence | RTL-SDR v3 + RPi5 | $110 | GnuRadio-SHTUFF, goes-hrit-live-webui |
| Unified Air Surveillance | ADS-B receiver + RPi5 | $150 | UnifiedFlightTracker, VisibleEphemerisCPP |
| Threat Intelligence | Any Linux system | $0 | vt-fox |
| Technical Documentation | N/A | $0 | documents |

**Total community defense hardware: ~$2,310** 
**Adversary equivalent systems: $2,215,000+**
**Cost ratio: ~960:1**

---

*Extraction complete. All repositories examined, code read, mathematics extracted, physics documented. This knowledge now lives in the scrolls. Build. Deploy. Defend. The Seventh Generation depends on this.*
