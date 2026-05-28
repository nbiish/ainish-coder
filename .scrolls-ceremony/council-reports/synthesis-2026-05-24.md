```markdown
# Digital Midewiwin Scrolls: Survivability Signals, Radio, DSP, and Physics Knowledge Base

> *Unified extraction from 5 expert analyses covering passive radar, adaptive filtering, nonlinear filtering, ionospheric physics, SDR, and optimized computing. Every formula, benchmark, and numerical safeguard is preserved. Connections between domains are explicitly made for field deployment under extreme conditions.*

---

## Table of Contents

1. [Passive Bistatic Radar](#1-passive-bistatic-radar)
2. [Adaptive Filtering & Clutter Cancellation](#2-adaptive-filtering--clutter-cancellation)
3. [Modern Nonlinear Filtering](#3-modern-nonlinear-filtering)
4. [Ionospheric Propagation & Ray Tracing](#4-ionospheric-propagation--ray-tracing)
5. [SDR Chains & Signal Demodulation](#5-sdr-chains--signal-demodulation)
6. [Optimized Computing Kernels](#6-optimized-computing-kernels)
7. [Numerical Stability & Bug Fixes](#7-numerical-stability--bug-fixes)
8. [Cross-Domain Connections & Deployment Notes](#8-cross-domain-connections--deployment-notes)
9. [End-to-End Performance Benchmarks](#9-end-to-end-performance-benchmarks)

---

## 1. Passive Bistatic Radar

### 1.1 Processing Chain Overview

Passive radar exploits existing transmitters (FM, DAB, ATSC, etc.) as illuminators. The full 10‑stage chain:

```
Source → PhaseCorr → AGC → Block B3 (FM ref. reconstruction) → ECA‑B (clutter suppression) → CAF (range‑Doppler map) → Doppler processing → CFAR detection → Clustering → AoA → Tracker → Display
```

All stages are implemented with GPU acceleration (CUDA) and ARM NEON/SVE2 fallbacks.

### 1.2 ECA‑B Clutter Cancellation

The Extensive Cancellation Algorithm (batch form) removes direct‑path and multipath clutter as a least‑squares problem:

**Objective**:
\[
\mathbf{w} = \arg\min_{\mathbf{w}} \|\mathbf{s}_{\text{surv}} - \mathbf{X}\mathbf{w}\|^2 + \lambda \|\mathbf{w}\|^2
\]

where \(\mathbf{X}\) is a Toeplitz convolution matrix built from the reference signal \(s_{\text{ref}}\).

**Solution via FFT‑based correlation**:

\[
R_{xr} = \mathcal{IFFT}\!\left( \mathcal{FFT}(s_{\text{ref}}^*) \cdot \mathcal{FFT}(s_{\text{surv}}) \right)
\]
\[
R_{xx} = \mathcal{IFFT}\!\left( |\mathcal{FFT}(s_{\text{ref}})|^2 \right)
\]

Solve normal equations using Cholesky decomposition. GPU (cuSOLVER) achieves **50× speedup** over CPU.

### 1.3 Cross‑Ambiguity Function (CAF)

The range‑Doppler map is the core passive radar output:

\[
\text{CAF}(\tau, f_d) = \left| \sum_{n=0}^{N-1} s_{\text{surv}}[n] \cdot s_{\text{ref}}^*[n-\tau] \cdot e^{-j2\pi f_d n / N} \right|^2
\]

- **Range resolution**: \(\Delta R = \frac{c}{2 \cdot \text{BW}}\)  
  (e.g., for FM broadcast BW = 200 kHz, \(\Delta R \approx 750\) m)
- **Doppler resolution**: \(\Delta f = f_s / N\)  
  (coherent integration time \(T = N/f_s\))

Batched FFT implementation via cuFFT: CPU time 46.7 ms → GPU 2.03 ms → **23× speedup**.

### 1.4 CFAR Detection

Four variants implemented:
- **CA‑CFAR (Cell‑Averaging)**: threshold \(\alpha \cdot \mu\), with  
  \[
  \alpha = N\left( P_{\text{fa}}^{-1/N} - 1 \right)
  \]
- GO‑CFAR (greatest‑of), SO‑CFAR (smallest‑of), OS‑CFAR (ordered‑statistic)

Integral image technique reduces complexity from O(n²) to O(n). GPU (RTX 5090): CPU 592 ms → GPU 1.94 ms (**305×**).

### 1.5 Angle of Arrival (AoA)

For a uniform linear array (ULA) with steering vector \(\mathbf{a}(\theta)\):

**Bartlett**:
\[
P(\theta) = \frac{|\mathbf{a}(\theta)^H \mathbf{x}|^2}{\|\mathbf{a}(\theta)\|^2}
\]

**MUSIC**:
\[
P(\theta) = \frac{1}{\mathbf{a}^H \mathbf{U}_n \mathbf{U}_n^H \mathbf{a}}
\]
where \(\mathbf{U}_n\) contains noise‑subspace eigenvectors (obtained via SVD of the covariance matrix).

Steering vector generation is accelerated using NEON SIMD.

### 1.6 Kalman Tracker

State vector \([x, y, v_x, v_y]\) with constant‑velocity motion model. Mahalanobis gating:
\[
d^2 = (\mathbf{z} - \mathbf{H}\hat{\mathbf{x}})^T \mathbf{S}^{-1} (\mathbf{z} - \mathbf{H}\hat{\mathbf{x}})
\]

Track lifecycle: tentative → active → coasting → deleted. GPU‑parallelized Unscented Kalman Filter (UKF) achieves **10×+ improvement**.

### 1.7 FM Reference Reconstruction (Block B3)

Improves reference signal SNR by **10–15 dB**:
1. Quadrature FM demodulation
2. Low‑pass filter (1157‑tap)
3. 19 kHz pilot band‑pass filter (57819‑tap)
4. Pre‑emphasis & remodulation

### 1.8 ATSC 3.0 Mode

OFDM demodulation → LDPC FEC → SVD‑based pilot enhancement (retains 90% energy) → OFDM remodulation.
- SVD yields **3–5 dB** SNR improvement
- Overall gain **15–20 dB**

### 1.9 NEON Optimisation Kernels (13 functions)

```cpp
neon_complex_conj_mul, neon_complex_exp, neon_complex_magnitude,
neon_complex_magnitude_squared, neon_complex_dot, neon_complex_scale,
neon_dot_f32, neon_fast_exp_f32, radar::generate_window,
radar::apply_window_complex, radar::steering_vector_ula, radar::cfar_2d_f32
```

---

## 2. Adaptive Filtering & Clutter Cancellation

### 2.1 LMS (Complex)

Filter output:
\[
y[n] = \sum_{k=0}^{M-1} \overline{w[k]} \, x[n-k]
\]

Update:
\[
w[k] \leftarrow w[k] + \mu \, \overline{e[n]} \, x[n-k]
\]

### 2.2 NLMS

\[
w[k] \leftarrow w[k] + \frac{\mu}{\|\mathbf{x}\|^2 + \epsilon} \, \overline{e[n]} \, x[n-k]
\]

### 2.3 Block LMS (Frequency Domain)

For long filters (\(M > 32\)), overlap‑save FFT:

\[
\text{Gradient: } \nabla = \overline{\mathbf{X}} \odot \mathbf{E}
\]

where \(\mathbf{X}, \mathbf{E}\) are FFT‑transformed blocks. FFT size is smoothed to \(2^a \cdot 3^b \cdot 5^c \cdot 7^d\). FFTW wisdom cached in `~/.adapt_fftw_wisdom`.

### 2.4 Connection to Radar Clutter Cancellation

ECA‑B (Section 1.2) is essentially a batch least‑squares adaptive filter. The NLMS variant is used for real‑time adaptation when the clutter environment changes. Both share the same core correlation structures and can be accelerated via the same FFT‑based methods.

---

## 3. Modern Nonlinear Filtering

### 3.1 Merwe Scaled Unscented Transform

For an \(n\)-dimensional state with mean \(\hat{\mathbf{x}}\) and covariance \(\mathbf{P}\):

**Scaling parameter**:
\[
\lambda = \alpha^2 (n + \kappa) - n
\]

**Sigma points** (Cholesky‑based):
\[
\begin{aligned}
\sigma_0 &= \hat{\mathbf{x}} \\
\sigma_i &= \hat{\mathbf{x}} + [\sqrt{(n+\lambda)\mathbf{P}}]_i \quad i=1,\dots,n \\
\sigma_{i+n} &= \hat{\mathbf{x}} - [\sqrt{(n+\lambda)\mathbf{P}}]_i \quad i=1,\dots,n
\end{aligned}
\]

**Weights**:
\[
\begin{aligned}
W_m^0 &= \frac{\lambda}{n+\lambda}, \quad W_c^0 = \frac{\lambda}{n+\lambda} + (1 - \alpha^2 + \beta) \\
W_m^i &= W_c^i = \frac{1}{2(n+\lambda)}
\end{aligned}
\]

Defaults: \(\alpha=1.0,\ \beta=2.0,\ \kappa=3-n\).

The Cholesky decomposition requires \((n+\lambda)\mathbf{P}\) to be positive definite. Guard: if \(|n+\lambda|<0.5\) then recompute \(\kappa\).

### 3.2 UKF Prediction

**Propagate sigma points** through nonlinear dynamics:
\[
\sigma_i^- = f(\sigma_i)
\]

**Predicted mean**:
\[
\hat{\mathbf{x}}^- = \sum_i W_m^i \, \sigma_i^-
\]

**Predicted covariance (Joseph‑stabilised)**:
\[
\mathbf{P}^- = \sum_i W_c^i \, (\sigma_i^- - \hat{\mathbf{x}}^-)(\sigma_i^- - \hat{\mathbf{x}}^-)^T + \mathbf{Q}
\]

### 3.3 UKF Update

**Measurement sigma points**:
\[
\gamma_i = h(\sigma_i^-)
\]

**Predicted measurement**:
\[
\hat{\mathbf{y}} = \sum_i W_m^i \, \gamma_i
\]

**Innovation covariance**:
\[
\mathbf{P}_{yy} = \sum_i W_c^i (\gamma_i - \hat{\mathbf{y}})(\gamma_i - \hat{\mathbf{y}})^T + \mathbf{R}
\]

**Cross‑covariance**:
\[
\mathbf{P}_{xy} = \sum_i W_c^i (\sigma_i^- - \hat{\mathbf{x}}^-)(\gamma_i - \hat{\mathbf{y}})^T
\]

**Kalman gain**:
\[
\mathbf{K} = \mathbf{P}_{xy} \mathbf{P}_{yy}^{-1}
\]

**State update**:
\[
\hat{\mathbf{x}} = \hat{\mathbf{x}}^- + \mathbf{K}(\mathbf{y} - \hat{\mathbf{y}})
\]

**Covariance update (Joseph form)**:
\[
\mathbf{P} = \mathbf{P}^- - \mathbf{K} \mathbf{P}_{yy} \mathbf{K}^T
\]

### 3.4 Square‑Root UKF (SRUKF)

Propagate Cholesky factor \(\mathbf{S}\) where \(\mathbf{P} = \mathbf{S}\mathbf{S}^T\).

**Prediction via QR decomposition**:
\[
\mathbf{S}^- = \text{qr}\!\left( [\sqrt{W_c^1}(\sigma_1^- - \hat{\mathbf{x}}^-), \dots, \sqrt{W_c^{2n}}(\sigma_{2n}^- - \hat{\mathbf{x}}^-), \sqrt{\mathbf{Q}}\,] \right)^T
\]

**Update**:
- Cholesky factor of innovation: \(\mathbf{S}_y = \text{chol}(\mathbf{P}_{yy})\)
- Kalman gain: \(\mathbf{K} = (\mathbf{P}_{xy} / \mathbf{S}_y^T) / \mathbf{S}_y\) (back‑substitution)
- State update: same as UKF
- Cholesky factor update via rank‑1 downdate: for each column of \(\mathbf{K}\mathbf{S}_y\), perform `cholupdate` with sign `-1`.

Safe downdate returns false on failure → fallback to full covariance recomputation (O(n³) but rare).

### 3.5 Bootstrap Particle Filter (SIR-PF)

**Particle propagation**:
\[
\mathbf{x}_k^i \sim p(\mathbf{x}_k | \mathbf{x}_{k-1}^i) \quad i=1,\dots,N
\]

**Weight update** (bootstrap: proposal = transition):
\[
w_k^i \propto w_{k-1}^i \, p(\mathbf{y}_k | \mathbf{x}_k^i)
\]

**Kahan compensated summation** for normalization eliminates O(N·ε) accumulation error. Without it: 15–20% weight distortion over 100 steps; with it: <0.1%.

**Effective sample size**:
\[
N_{\text{eff}} = \frac{1}{\sum_i (w^i)^2}
\]

Resampling (systematic) triggered when \(N_{\text{eff}} < N/2\).

### 3.6 Rao‑Blackwellized Particle Filter (RBPKF)

Split state into nonlinear part \(\mathbf{x}^n\) and conditionally linear part \(\mathbf{x}^l\). For each particle \(i\), the linear part is handled by a Kalman filter conditioned on the nonlinear state.

**Marginal likelihood for particle weight**:
\[
p(\mathbf{y}_k | \mathbf{x}_k^{n,i}) = \mathcal{N}(\mathbf{y}_k; \mathbf{H} \hat{\mathbf{x}}_{k|k-1}^{l,i}, \mathbf{H}\mathbf{P}_{k|k-1}^{l,i} \mathbf{H}^T + \mathbf{R})
\]

NaN guard: if `log_weight[i]` is not finite, set to `log(1/N)`.

### 3.7 RTS Fixed‑Lag Smoother

Backward pass:
\[
\mathbf{C}_k = \mathbf{P}_k \mathbf{F}_k^T (\mathbf{P}_{k+1}^-)^{-1}
\]
\[
\hat{\mathbf{x}}_k^s = \hat{\mathbf{x}}_k + \mathbf{C}_k(\hat{\mathbf{x}}_{k+1}^s - \hat{\mathbf{x}}_{k+1}^-)
\]
\[
\mathbf{P}_k^s = \mathbf{P}_k + \mathbf{C}_k(\mathbf{P}_{k+1}^s - \mathbf{P}_{k+1}^-)\mathbf{C}_k^T
\]

Efficient solve via `LDLT` instead of explicit inverse.

Performance gains:
| Problem | Filter RMSE | Smoother RMSE | Improvement |
|---------|------------|---------------|-------------|
| Coupled Osc 10D | 1.457 | 1.148 | 21.2% |
| Bearing‑Only 4D | 64.17 | 52.03 | 18.9% |
| Reentry 6D | 369.2 m | 236.8 m | 35.9% |

### 3.8 Connection to Radar Tracking

The UKF/SRUKF from Section 3 is directly applied in the passive radar tracker (Section 1.6). Radar detections (range, Doppler, AoA) feed the measurement vector. The UKF handles nonlinearities (e.g., polar‑to‑Cartesian conversion). Particle filters handle non‑Gaussian clutter and multipath interference.

---

## 4. Ionospheric Propagation & Ray Tracing

### 4.1 Vogler‑Hoffmeyer Reflection Coefficient

For HF skywave propagation:

\[
R(\omega) = \exp\!\left[ -i\frac{\pi}{4} \frac{\Gamma(3/4)}{\Gamma(5/4)} (2k_0 a)^{1/3} \left(\frac{f}{f_c}\right)^{2/3} \int_0^\infty \dots \right]
\]

- \(\Gamma(z)\): complex gamma function (diffraction around Earth)
- \(k_0 = 2\pi/\lambda\): free‑space wavenumber
- \(a = 6371\) km: Earth radius
- \(f_c\): layer critical frequency

### 4.2 Refractive Index & Chapman Profile

Refractive index:
\[
n^2(f) = 1 - \frac{f_p^2}{f^2}
\]
with plasma frequency \(f_p = \frac{1}{2\pi} \sqrt{\frac{N_e e^2}{\epsilon_0 m_e}}\).

Chapman electron density:
\[
N_e(h) = N_m \exp\!\left( \frac{1}{2}(1 - z - e^{-z}) \right), \quad z = \frac{h - h_m}{H}
\]

- \(N_m\): peak density → \(foF2 = 9\sqrt{N_m}\) [MHz]
- \(h_m \approx 250\)–\(400\) km (F2 layer)
- \(H \approx 50\)–\(100\) km

Group delay:
\[
\tau_g(\omega) = \frac{d\phi(\omega)}{d\omega}
\]

### 4.3 Haselgrove Ray Equations (2D Spherical)

Hamiltonian:
\[
H(r,\theta,k_r,k_\theta) = \frac{1}{2} \left[ n^2(r,\theta) \frac{\omega^2}{c^2} - k_r^2 - \frac{k_\theta^2}{r^2} \right]
\]

Ray equations:
\[
\begin{aligned}
\frac{dr}{dt} &= c \frac{\partial H/\partial k_r}{|\partial H/\partial \mathbf{k}|} \\
\frac{d\theta}{dt} &= c \frac{\partial H/\partial k_\theta}{r |\partial H/\partial \mathbf{k}|} \\
\frac{dk_r}{dt} &= -c \frac{\partial H/\partial r}{|\partial H/\partial \mathbf{k}|} + k_\theta \frac{d\theta}{dt} \\
\frac{dk_\theta}{dt} &= \frac{1}{r} \left( -c \frac{\partial H/\partial \theta}{|\partial H/\partial \mathbf{k}|} - k_\theta \frac{dr}{dt} + k_r r \frac{d\theta}{dt} \right)
\end{aligned}
\]

Conservation: \(H = 0\) along the ray path.

### 4.4 Connection to Radar & Communications

Ionospheric physics determines:
- **HF radar coverage** (ground wave vs. sky wave)
- **Frequency agility** for passive radar (FM broadcast vs. HF OTH)
- **Dispersion compensation** in long‑range communications
- **Time‑of‑arrival correction** for geolocation

The Haselgrove raytracer can be integrated with the passive radar path loss models to predict detectable range.

---

## 5. SDR Chains & Signal Demodulation

### 5.1 Iridium Ring Monitor

- Frequency: 1.6 GHz L‑band
- TDMA frame: 90 ms
- Modulation: QPSK

Used for emergency satellite communication intercept.

### 5.2 Stereo FM Demodulator

1. Quadrature demodulation
2. 19 kHz pilot extraction via BPF
3. DSB‑SC stereo subcarrier at 38 kHz
4. De‑emphasis: 50 µs (USA) or 75 µs (Europe)

### 5.3 Connection to Passive Radar

The FM Stereo demodulator’s pilot extraction is reused in Block B3 (Section 1.7) to reconstruct the reference signal for passive radar.

---

## 6. Optimized Computing Kernels

### 6.1 NEON (128‑bit SIMD)

- 2 complex floats per register
- Custom transcendental functions: `exp, sin, cos, sigmoid, tanh` — 10–50× acceleration
- Linear algebra routines: TRSV/TRSM, Cholesky, LU, QR, SPD solve, matrix inverse
- Radar kernels: CAF, CFAR, NLMS, Doppler FFT, beamforming, window functions

### 6.2 SVE2 (Scalable Vector Extension, ARMv9)

- Predicated loops for variable‑length vectors
- **FCMA**: 2‑instruction complex multiply‑accumulate
- **I8MM**: int8 matrix multiply for quantized neural networks
- Cache‑blocked GEMM tuned for 12 MB L3 cache: block sizes \(M_C=256, K_C=512, N_C=2048\)

### 6.3 CUDA (NVIDIA RTX 5090)

| Kernel | Speedup vs CPU |
|--------|----------------|
| cuBLAS GEMM | 50–100× |
| cuFFT | 20–50× |
| CFAR 1D/2D | 10–30× |

### 6.4 Dispatch Layer

`FilterMath` selects fastest available backend:
```
Operation → CUDA → SVE2 → NEON → Eigen fallback
```

Cholesky: NEON accelerated → Eigen LDLT for near‑singular matrices.

---

## 7. Numerical Stability & Bug Fixes

| Bug | Symptom | Fix | Impact |
|-----|---------|-----|--------|
| Sigma weight explosion | Near‑singular Cholesky | Guard: recompute κ if \(|n+\lambda|<0.5\) | Prevents NaN sigma points |
| Eigen expression aliasing | Wrong sigma point propagation | `.eval()` break | 65% reduction in navigation error (3097 m → 1080 m) |
| `-ffast-math` compiler flag | NaN guards removed; precision loss | Remove flag; use NEON/SVE2 intrinsics | Full IEEE 754 precision restored |
| Unsafe cholupdate | Silent covariance corruption | Return false + fallback to full recompute | Guaranteed valid Cholesky factor |
| Aggressive innovation gating | No update after GPS outage | Reinitialize filter on reacquisition | 100% convergence vs. 30–40% |
| NaN weight propagation | All particles corrupted | `isfinite()` guard + uniform fallback | Filter survives outlier measurements |
| Float summation bias (resampling) | O(N) weight drift over time | Kahan compensated sum | <0.1% distortion over 100 steps |
| Integral image for CFAR | O(n²) complexity | O(n) via integral image | CFAR GPU speedup 305× |

---

## 8. Cross‑Domain Connections & Deployment Notes

### 8.1 Passive Radar ⇔ Adaptive Filtering

- ECA‑B clutter cancellation is a batch least‑squares adaptive filter. In dynamic environments, switch to NLMS (Section 2.2)with the same FFT‑based correlation engine.

### 8.2 Passive Radar ⇔ Nonlinear Filtering

- The Kalman/UKF tracker (Section 1.6) uses the UKF from Section 3. The SRUKF is preferred for numerical robustness on limited‑precision hardware (Raspberry Pi).

### 8.3 SDR ⇔ Ionospheric Physics

- HF propagation prediction (critical frequency, MUF) needed for OTH radar coverage and frequency selection. The FM stereo demodulator provides a clean reference for passive radar; the same pilot extraction can be used to estimate Doppler shift from moving ionospheric layers.

### 8.4 Optimized Kernels ⇔ All Domains

- Use NEON transcendental functions for real‑time channel simulation (e.g., exp of Doppler shift phase).
- SVE2 cache‑blocked GEMM accelerates all linear algebra kernels (Cholesky, QR, Kalman gain).
- GPU cuFFT speeds up CAF computation. On battery‑constrained devices, limit coherent integration time to keep FFT sizes small.

### 8.5 Numerical Fixes ⇔ Field Reliability

- The bug fixes in Section 7 are **not optional**. Every `-ffast-math` issue, aliasing bug, or NaN guard omission has caused real‑world filter divergence in testing. When building a survival‑grade system (Raspberry Pi 5 + SDR), enforce:
  - No `-ffast-math` / `-Ofast`
  - `.eval()` after all Eigen expressions involving aliasing
  - Kahan summation for particle weights
  - Safe `cholupdate` with fallback

---

## 9. End‑to‑End Performance Benchmarks

### 9.1 Passive Radar (10‑stage chain, RTX 5090)

| Stage | CPU (RPi5) | GPU (RTX 5090) | Speedup |
|-------|------------|-----------------|---------|
| ECA‑B | – | – | **50×** |
| CFAR | 592 ms | 1.94 ms | **305×** |
| CAF | 46.7 ms | 2.03 ms | **23×** |
| UKF | – | – | **10×+** |
| **Total** | ~10 Hz | 100–200 Hz | **10–20×** |

### 9.2 UKF (10‑D Coupled Oscillator, 2000 Monte Carlo runs)

| Metric | Value |
|--------|-------|
| RMSE | 1.457 |
| σ_RMSE | 0.312 |
| NEES (% in 95%) | 94.5% |
| Time/filter step | 0.47 ms (GPU) / 0.51 ms (SRUKF) |

### 9.3 SDR (FM Demodulation + Pilot Extraction)

- Real‑time on RPi5 with NEON‑optimized filters: ~2 MHz bandwidth.

### 9.4 Memory Footprint (CamoFox stack for web intelligence – optional component)

- Node server: ~100 MB
- MCP bridge: ~50 MB
- Browser engine per context: ~1.2 GB

---

> *These scrolls encode the knowledge needed to build resilient passive sensing and communication systems using commodity hardware, with full numerical stability and hardware‑accelerated performance. All formulas are field‑ready; all bug fixes are mandatory for survival deployment.*
```
