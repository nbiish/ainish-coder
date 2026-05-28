## Comprehensive Signals, Radio, DSP, and Physics Extraction

### Repository 1: PassiveRadar_Kraken – Full Passive Bistatic Radar Processing

**Processing Chain (10 stages):**  
Source → PhaseCorr → AGC → Block B3 → ECA(C++) → CAF(C++) → Doppler(C++) → CFAR(C++) → Cluster(C++) → AoA(C++) → Tracker(C++) → Display  

**1. ECA-B Clutter Cancellation (ECA-B)**  
- Batch Toeplitz least‑squares solution:  
  \[
  \mathbf{w} = \arg\min_{\mathbf{w}} \left\| \mathbf{s}_{\text{surv}} - \mathbf{X}\mathbf{w} \right\|^2 + \lambda\|\mathbf{w}\|^2
  \]  
  where \(\mathbf{X}\) is the Toeplitz convolution matrix formed from the reference signal.  
- FFT‑based cross‑correlation:  
  \[
  R_{xr} = \mathcal{IFFT}\left( \mathcal{FFT}(\mathbf{s}_{\text{ref}}^*) \cdot \mathcal{FFT}(\mathbf{s}_{\text{surv}}) \right)
  \]  
  \[
  R_{xx} = \mathcal{IFFT}\left( \left| \mathcal{FFT}(\mathbf{s}_{\text{ref}}) \right|^2 \right)
  \]  
- Solve via Cholesky decomposition.  
- GPU speedup (cuSOLVER): **50×**  

**2. Cross‑Ambiguity Function (CAF)**  
\[
\text{CAF}(\tau, f_d) = \left| \sum_{n=0}^{N-1} s_{\text{surv}}[n] \cdot s_{\text{ref}}^*[n-\tau] \cdot e^{-j2\pi f_d n / N} \right|^2
\]  
- Batched FFT implementation.  
- Doppler resolution: \(\Delta f = f_s / N\)  
- Range resolution: \(\Delta R = \frac{c}{2 \cdot \text{BW}}\)  
- GPU performance (cuFFT): 46.7 ms → 2.03 ms (**23×**)  

**3. CFAR Detection (4 variants built)**  
- **CA‑CFAR**: Threshold \(\alpha \cdot \mu\), where  
  \[
  \alpha = N \left( P_{\text{fa}}^{-1/N} - 1 \right)
  \]  
  (N = number of training cells, \(P_{\text{fa}}\) = desired false alarm probability)  
- **GO/SO/OS‑CFAR** variants.  
- Integral image technique: O(n²) → O(n) complexity reduction.  
- GPU (RTX 5090): 592 ms → 1.94 ms (**305×**)  

**4. Angle of Arrival (AoA)**  
- **Bartlett**:  
  \[
  P(\theta) = \frac{ \left| \mathbf{a}(\theta)^H \mathbf{x} \right|^2 }{ \|\mathbf{a}(\theta)\|^2 }
  \]  
- **MUSIC**:  
  \[
  P(\theta) = \frac{1}{ \mathbf{a}^H \mathbf{U}_n \mathbf{U}_n^H \mathbf{a} }
  \]  
  (\(\mathbf{U}_n\) = noise subspace eigenvectors)  
- NEON‑accelerated steering vector generation for uniform linear array (ULA).  

**5. Kalman Tracker**  
- State vector: \([x, y, v_x, v_y]\) (constant‑velocity model).  
- Mahalanobis gating:  
  \[
  d^2 = (\mathbf{z} - \mathbf{H}\hat{\mathbf{x}})^T \mathbf{S}^{-1} (\mathbf{z} - \mathbf{H}\hat{\mathbf{x}})
  \]  
- Track lifecycle: tentative → active → coasting → deleted.  
- GPU UKF with parallel sigma‑point propagation (10×+ improvement).  

**6. Block B3 – FM Reference Reconstruction**  
- Quadrature FM demod → 1157‑tap LPF → 19 kHz pilot BPF (57819‑tap) → pre‑emphasis → remodulation.  
- Improves reference SNR by **10–15 dB**.  

**7. ATSC 3.0 Mode**  
- OFDM demod → LDPC FEC → SVD‑based pilot enhancement (retains 90% energy) → OFDM remodulation.  
- SVD yields **3–5 dB** SNR improvement; overall gain **15–20 dB**.  

**8. End‑to‑End GPU Performance (RTX 5090)**  
| Stage | CPU (RPi5) | GPU (RTX 5090) | Speedup |  
|-------|------------|-----------------|---------|  
| ECA‑B | – | – | **50×** |  
| CFAR  | 592 ms     | 1.94 ms        | **305×** |  
| CAF   | 46.7 ms   | 2.03 ms        | **23×** |  
| UKF   | –          | –               | **10×+** |  
| **Total** | ~10 Hz | 100–200 Hz | **10–20×** |  

**9. NEON Optimisation Kernels (13 functions)**  
- `neon_complex_conj_mul`, `neon_complex_exp`, `neon_complex_magnitude`,  
  `neon_complex_magnitude_squared`, `neon_complex_dot`, `neon_complex_scale`,  
  `neon_dot_f32`, `neon_fast_exp_f32`, `radar::generate_window`,  
  `radar::apply_window_complex`, `radar::steering_vector_ula`, `radar::cfar_2d_f32`.  

**10. Audit Fixes (2026‑03‑23)**  
- ECA‑B buffer overread in delay samples.  
- AGC gain clamped to 1e3 to prevent spike.  
- CFAR GO edge case with empty leading half.  
- FFT shift standardised to NumPy convention \( (N+1)/2 \).  
- CFAR complexity reduced from O(n²) to O(n) via integral image.  

---

### Repository 2: AdaptiveFiltering – LMS/NLMS/Block Adaptive Filters

**Algorithms**  
- **LMS (complex)**  
  \[
  y[n] = \sum_{k=0}^{M-1} \overline{w[k]} \, x[n-k]
  \]  
  \[
  w[k] \leftarrow w[k] + \mu \, \overline{e[n]} \, x[n-k]
  \]  
  (overbar denotes complex conjugate)  
- **NLMS**  
  \[
  w[k] \leftarrow w[k] + \frac{\mu}{\|\mathbf{x}\|^2 + \epsilon} \, \overline{e[n]} \, x[n-k]
  \]  
- **Block LMS / Normalized Block LMS**  
  - Frequency‑domain via FFT overlap‑save for \(M > 32\) taps.  
  - Padding to smooth FFT size: \(2^a \cdot 3^b \cdot 5^c \cdot 7^d\).  
  - Gradient in frequency domain:  
    \[
    \nabla = \overline{\mathbf{X}} \cdot \mathbf{E}
    \]  
    (element‑wise, \(\mathbf{X}, \mathbf{E}\) are FFT‑transformed blocks)  

**Implementation Details**  
- FFTW wisdom caching in `~/.adapt_fftw_wisdom`.  
- 22 unit tests all passing on Raspberry Pi 5.  
- NEON SIMD acceleration for complex multiplications and updates.  

---

### Repository 3: OptimizedKernelsForRaspberryPi5_NvidiaCUDA

**SIMD / Vector ISA**  
- **NEON**: 128‑bit SIMD, processes 2 complex floats per register.  
- **SVE2**:  
  - Predicated loops for variable‑length vectors.  
  - **FCMA**: 2‑instruction complex multiply‑accumulate.  
  - **I8MM**: int8 matrix multiplication for quantised networks.  
- **Cache‑blocked GEMM** tuned for 12 MB L3 cache:  
  \[
  \text{MC} = 256,\quad \text{KC} = 512,\quad \text{NC} = 2048
  \]  

**CUDA Performance**  
| Kernel | Speedup vs CPU |  
|--------|----------------|  
| cuBLAS GEMM | 50–100× |  
| cuFFT | 20–50× |  
| CFAR 1D/2D | 10–30× |  

**Radar‑Specific Kernels**  
- CAF, CFAR (1D & 2D), clutter filtering (NLMS + projection), Doppler FFT,  
  beamforming (delay‑sum and phase‑shift), window functions.  

**NEON Transcendentals** (10–50× vs scalar)  
- `exp()`, `sin()`, `cos()`, `sigmoid()`, `tanh()`.  

**NEON Linear Algebra Routines**  
- TRSV/TRSM (triangular solve), Cholesky, LU, QR, general solve,  
  symmetric positive‑definite (SPD) solve, matrix inverse.  

---

### Repository 4: GnuRadio‑SHTUFF – SDR Signal Chains

**Iridium Ring Monitor**  
- Frequency: 1.6 GHz L‑band.  
- TDMA frame length: 90 ms.  
- Modulation: QPSK.  

**Stereo FM Demodulator**  
- Quadrature demodulation.  
- 19 kHz pilot extraction → 38 kHz DSB‑SC stereo subcarrier.  
- De‑emphasis filter (standard 50 µs or 75 µs).  

---

### Synthesis for the Digital Midewiwin Scrolls (Survival Architecture)

| Domain | Key Formulas / Constants | Performance Figures | Implementation Pattern |  
|--------|--------------------------|---------------------|------------------------|  
| **Passive Radar** | CAF, CFAR threshold (\(\alpha\)), Doppler resolution, Range resolution, Bartlett/MUSIC AoA, Kalman Mahalanobis distance | 10 Hz → 200 Hz E2E; 305× CFAR; 50× ECA | Batch FFTs, Toeplitz least‑squares, integral images, Cholesky, UKF |  
| **Adaptive Filtering** | NLMS update, Block LMS frequency‑domain gradient, FFT size \(2^a3^b5^c7^d\) | 22 tests pass on RPi5 | Overlap‑save, FFTW caching, NEON vectorisation |  
| **Optimised Kernels** | Cache blocking (MC/KC/NC), SVE2 FCMA, NEON transcendental & linear algebra | cuBLAS 50‑100×, cuFFT 20‑50×, NEON 10‑50× | 128‑bit SIMD, predicated loops, integer matmul, matrix factorisation |  
| **SDR Blocks** | FM stereo: pilot 19 kHz, DSB‑SC 38 kHz; Iridium: 1.6 GHz QPSK | – | Quadrature demod, LDPC FEC, TDMA framing |  

All mathematical rigor and empirical benchmarks are retained for immediate field deployment. These scrolls document the exact algorithms, hardware acceleration strategies, and performance ceilings needed to construct resilient passive sensing and communication systems under extreme conditions.
