# Modern Computational Nonlinear Filtering: Complete Mathematical Extraction

> *A rigorous derivation of every sigma point, covariance factorization, resampling mechanism, and numerical safeguard from the repository. All equations are cited directly from code.*

---

## 1. The Merwe Scaled Unscented Transform

### 1.1 Sigma Point Parameterization

The core innovation of the UKF is deterministic sampling via the scaled unscented transform. Given an n-dimensional state with mean **x̂** and covariance **P**, the transform generates 2n+1 sigma points:

**Scaling Parameter**:
```
λ = α²(n + κ) - n
```

**Sigma Point Generation** (Cholesky-based):
```
σ₀ = x̂
σᵢ = x̂ + [√((n+λ)P)]ᵢ      for i = 1, ..., n
σ_{i+n} = x̂ - [√((n+λ)P)]ᵢ  for i = 1, ..., n
```

where `[√((n+λ)P)]ᵢ` denotes the i-th column of the matrix square root, computed via Cholesky decomposition of `(n+λ)P`.

**Weight Assignment**:
| Weight | Formula | Role |
|--------|---------|------|
| Wm₀ | λ/(n+λ) | Mean weight, central point |
| Wc₀ | λ/(n+λ) + (1-α²+β) | Covariance weight, central point |
| Wmᵢ | 1/(2(n+λ)) | Mean weight, i-th sigma point |
| Wcᵢ | 1/(2(n+λ)) | Covariance weight, i-th sigma point |

**Repository Defaults**: `α = 1.0`, `β = 2.0`, `κ = 3 - n`

The parameter α controls spread (typically 1e-4 ≤ α ≤ 1), β incorporates prior distribution information (β=2 optimal for Gaussian), and κ provides secondary scaling (κ=3-n ensures positive definiteness for Gaussian).

### 1.2 The Cholesky Decomposition Requirement

The critical numerical operation is:
```cpp
// Eigen implementation from the codebase
Eigen::LLT<Eigen::MatrixXd> lltOfSigma((n + lambda) * P);
MatrixXd S = lltOfSigma.matrixL();  // Lower triangular
```

This requires `(n+λ)P` to be symmetric positive definite. The **sigma point weight explosion invariant** from the bug fixes: if `|n+λ| < 0.5`, recompute κ to prevent near-singularity:
```math
\text{If } |n + λ| < 0.5 \quad \rightarrow \quad \kappa = n + \delta \text{ (where δ > 0.5)}
```

---

## 2. UKF Prediction Step

### 2.1 Propagation Through Nonlinear Dynamics

Given nonlinear process model `x_{k+1} = f(x_k) + q_k`:

**Propagate sigma points**:
```
σ⁻ᵢ = f(σᵢ)    for i = 0, ..., 2n
```

**Predicted mean** (weighted combination):
```
x̂⁻ = Σᵢ Wmᵢ · σ⁻ᵢ
```

**Predicted covariance** (Joseph-stabilized):
```
P⁻ = Σᵢ Wcᵢ · (σ⁻ᵢ - x̂⁻)(σ⁻ᵢ - x̂⁻)ᵀ + Q
```

### 2.2 The Aliasing Bug (From Bug Report #2)

The expression template aliasing in Eigen caused:
```cpp
// BROKEN: σ_points aliases with transformed points
sigma_points = f(sigma_points);   // Aliasing!

// FIXED: Explicit evaluation
sigma_points_pred = f(sigma_points).eval();  // Breaks aliasing
```

**Impact Without Fix** (INS/GPS simulation):
- Flywheel during GPS outage: position error → **3097m in 30s**
- With fix: position error → **~1080m in 30s**
- A 65% reduction in navigation error from a single `eval()` call

---

## 3. UKF Update Step

### 3.1 Measurement Prediction

Given measurement model `y = h(x) + r`:

**Transform sigma points into measurement space**:
```
γᵢ = h(σ⁻ᵢ)    for i = 0, ..., 2n
```

**Predicted measurement**:
```
ŷ = Σᵢ Wmᵢ · γᵢ
```

**Innovation covariance**:
```
Pyy = Σᵢ Wcᵢ · (γᵢ - ŷ)(γᵢ - ŷ)ᵀ + R
```

**Cross-covariance**:
```
Pxy = Σᵢ Wcᵢ · (σ⁻ᵢ - x̂⁻)(γᵢ - ŷ)ᵀ
```

### 3.2 Kalman Gain and Update (Joseph Form)

**Kalman gain**:
```
K = Pxy · Pyy⁻¹
```

**State update** (innovations form):
```
x̂ = x̂⁻ + K · (y - ŷ)
```

**Covariance update — Joseph stabilized form** (numerically superior to standard form):
```
P = P⁻ - K · Pyy · Kᵀ
```

This Joseph form guarantees symmetry and positive semidefiniteness even with roundoff errors, unlike the standard `P = (I - KH)P⁻` form.

### 3.3 Innovation Gating (Bug Fix #5)

The Mahalanobis distance gate:
```
d² = (y - ŷ)ᵀ · Pyy⁻¹ · (y - ŷ)
```

When `d² > χ²(p, 0.99)` (p = measurement dimension), the update is **gated**:
```cpp
// Problem: after GPS outage, d² is astronomical
// → updates effectively disabled (0.7% effectiveness)
// Solution: reinitialize covariance when outage ends
if (outage_detected && reacquisition) {
    P = P_nominal * 10;  // Inflate to trust measurements
    x̂ = y_mapped_to_state;  // Reinitialize from measurement
}
```

Result: **100% convergence** across Monte Carlo trials vs. 30-40% without reinitialization.

---

## 4. Square Root UKF (SRUKF)

### 4.1 Cholesky Factor Propagation

The SRUKF propagates `S` where `P = S·Sᵀ`. This guarantees positive definiteness and provides O(n²) updates instead of O(n³).

**Prediction step — QR decomposition**:
```
S⁻ = qr([√(Wc₁)·(σ⁻₁ - x̂⁻), ..., √(Wc₂ₙ)·(σ⁻₂ₙ - x̂⁻), √Q])ᵀ
```

The QR decomposition yields the upper triangular Cholesky factor directly, avoiding an O(n³) covariance formation followed by Cholesky.

### 4.2 Measurement Update — Cholesky Rank-1 Update/Downdate

**Innovation Cholesky factor**:
```
Sy = chol(Pyy)  via QR on weighted measurement deviations + √R
```

**Cross-covariance**:
```
Pxy = Σᵢ Wcᵢ · (σ⁻ᵢ - x̂⁻)(γᵢ - ŷ)ᵀ
```

**Kalman gain**:
```
K = (Pxy / Syᵀ) / Sy    // Back-substitution (O(n²))
```

**State update**: Same as UKF.

**Cholesky factor update** (downdate):
```cpp
// Rank-1 Cholesky update/downdate
for each column i of U = K * Sy:
    S_new = cholupdate(S_old, U.col(i), -1.0);  // downdate
```

### 4.3 Safe Downdate (Bug Fix #4)

The unsafe cholupdate silently set `r_sq = 1e-6 · S(k,k)²` on failure instead of throwing:
```cpp
// Safe Cholesky downdate implementation
bool safe_cholupdate(MatrixXd& S, const VectorXd& v, double sign) {
    if (sign < 0) {  // Downdate
        for (int k = 0; k < S.rows(); ++k) {
            double r_sq = S(k,k)*S(k,k) - v(k)*v(k);
            if (r_sq <= 0) {
                return false;  // Signal failure
            }
            S(k,k) = sqrt(r_sq);
            // ... update remaining entries ...
        }
    }
    return true;
}

// Fallback on failure:
if (!safe_cholupdate(S, u, -1.0)) {
    // Recompute P from sigma points, then fresh Cholesky
    P = sigma_point_covariance(x̂⁻, σ⁻, Wc);
    S = P.llt().matrixL();  // O(n³) fallback
}
```

---

## 5. Bootstrap Particle Filter (SIR-PF)

### 5.1 Sequential Importance Sampling

**Particle propagation**:
```
x_kⁱ ~ p(x_k | x_{k-1}ⁱ)    for i = 1, ..., N
```

**Weight update** (bootstrap filter, proposal = transition):
```
w_kⁱ ∝ w_{k-1}ⁱ · p(y_k | x_kⁱ)
```

**Normalization**:
```
w_kⁱ = w_kⁱ / Σⱼ w_kʲ
```

### 5.2 Kahan Compensated Summation (Bug Fix #6)

Standard O(N) summation of weights accumulates O(N·ε) float error:
```cpp
// Naive: error O(N·ε)
double sum = 0.0;
for (int i = 0; i < N; i++) sum += w[i];

// Kahan: error O(ε) independent of N
double sum = 0.0, comp = 0.0;
for (int i = 0; i < N; i++) {
    double y = w[i] - comp;
    double t = sum + y;
    comp = (t - sum) - y;  // Algebraically zero, captures rounding
    sum = t;
}
```

**Impact**: Without Kahan summation, resampling bias of ~0.5% per step accumulates to 15-20% weight distortion over 100 steps. With Kahan: < 0.1% distortion.

### 5.3 Effective Sample Size and Resampling

**Effective sample size**:
```
N_eff = 1 / Σᵢ (wⁱ)²
```

**Resampling trigger**: `N_eff < N/2`

**Systematic resampling** (lowest variance method):
```
1. u ~ Uniform[0, 1/N)
2. For i = 1:N:
       u_i = u + (i-1)/N
       Find smallest j s.t. cumulative_weight[j] >= u_i
       x_new[i] = x[j]
       w_new[i] = 1/N
```

### 5.4 Essential Division-by-Zero Guard

```cpp
double compute_ess(const VectorXd& weights) {
    double sum_sq = weights.squaredNorm();
    if (sum_sq <= std::numeric_limits<double>::epsilon()) {
        return weights.size();  // ESS = N (uniform weights)
    }
    return 1.0 / sum_sq;
}
```

---

## 6. Rao-Blackwellized Particle Filter (RBPKF)

### 6.1 Conditional Linear Structure Decomposition

Partition state into nonlinear **x**ⁿ and conditionally linear **x**ˡ:
```
x_{k+1}ⁿ = fⁿ(x_kⁿ) + Gⁿ(x_kⁿ)·v_kⁿ
x_{k+1}ˡ = A(x_kⁿ)·x_kˡ + B(x_kⁿ)·u_k + v_kˡ
y_k = H(x_kⁿ)·x_kˡ + D(x_kⁿ) + w_k
```

### 6.2 Per-Particle Kalman Filter

For each particle `i`, given the nonlinear state trajectory `x_{0:k}ⁿⁱ`:

**Predict**:
```
x̂_{k|k-1}ˡⁱ = A(x_kⁿⁱ)·x̂_{k-1|k-1}ˡⁱ
P_{k|k-1}ˡⁱ = A·P_{k-1|k-1}ˡⁱ·Aᵀ + Qˡⁱ
```

**Update**:
```
Kⁱ = P_{k|k-1}ˡⁱ·Hᵀ·(H·P_{k|k-1}ˡⁱ·Hᵀ + R)⁻¹
x̂_{k|k}ˡⁱ = x̂_{k|k-1}ˡⁱ + Kⁱ·(y - H·x̂_{k|k-1}ˡⁱ)
P_{k|k}ˡⁱ = (I - Kⁱ·H)·P_{k|k-1}ˡⁱ
```

**Marginal likelihood for particle weight**:
```
p(y_k | x_kⁿⁱ) = N(y_k; H·x̂_{k|k-1}ˡⁱ, H·P_{k|k-1}ˡⁱ·Hᵀ + R)
```

### 6.3 NaN Guard (Bug Fix #6b)

A single NaN weight corrupts all particles through normalization:
```cpp
// Check for NaN in each particle weight
for (int i = 0; i < N; i++) {
    if (!std::isfinite(log_weight[i])) {
        // Fallback to uniform weight
        log_weight[i] = -log(N);  // log(1/N)
    }
}

// ESS zero-division guard (duplicated from PF for safety)
double ess = compute_ess(weights);
if (ess < 1.0) ess = N;  // Catch numerical edge case
```

---

## 7. RTS Fixed-Lag Smoother

### 7.1 Smoothing Gain

The Rauch-Tung-Striebel backward pass:
```
C_k = P_k · F_kᵀ · (P_{k+1}⁻)⁻¹
```

where `F_k` is the **linearized** dynamics Jacobian at time k (or the sigma point equivalent for UKF).

### 7.2 Smoothed State and Covariance

```
x̂_kˢ = x̂_k + C_k · (x̂_{k+1}ˢ - x̂_{k+1}⁻)
P_kˢ = P_k + C_k · (P_{k+1}ˢ - P_{k+1}⁻) · C_kᵀ
```

### 7.3 Smoothing Gain Computation via SPD Solve (O(n²))

Instead of explicit inverse:
```cpp
// Efficient: solve linear system instead of inverse
// C_k = P_k * F_k^T * inv(P_{k+1}^-)
// Solve P_{k+1}^- * X^T = F_k * P_k
// Then C_k = X^T
MatrixXd X = P_next_minus.ldlt().solve(Fk * Pk).transpose();
// Equivalent to: Ck = Pk * Fk^T * P_next_minus^{-1}
```

### 7.4 Performance Gains from Smoothing

| Problem | Filter RMSE | Smoother RMSE | Improvement |
|---------|------------|---------------|-------------|
| Coupled Oscillators 10D | 1.457 | 1.148 | **21.2%** |
| Bearing-Only 4D | 64.17 | 52.03 | **18.9%** |
| Reentry 6D | 369.2m | 236.8m | **35.9%** |
| Drag Ball 3D | ~50 units | ~25 units | **48-53%** |

---

## 8. The FilterMath Dispatch Layer

### 8.1 Unified GEMM Interface

```cpp
// SVE2 tuned for Cortex-A720 (12MB L3)
// Block size: 64×64 fits in L2, 128×128 in L3
template <typename T>
void gemm_sve2(T* C, const T* A, const T* B, 
               int M, int N, int K, float alpha, float beta);
```

### 8.2 Dispatch Logic

| Operation | Primary | Fallback |
|-----------|---------|----------|
| GEMM | CUDA cuBLAS → SVE2 cache-blocked → NEON blocked → Eigen |
| Cholesky | NEON accelerated → Eigen LDLT |
| Kalman gain solve | SPD via `ldlt()` (O(n²)) | Explicit inverse (O(n³)) |
| Matrix square root | Cholesky LLT | LDLT for near-singular |

### 8.3 Compiler Optimization Pitfall (Bug Fix #3)

**The `-ffast-math` problem**:
```makefile
# WRONG: Optimizes away NaN guards
CXXFLAGS += -ffast-math -O3

# CORRECT: Preserve IEEE 754
CXXFLAGS += -O3 -march=armv9-a+sve2 -DNDEBUG
```

**What `-ffast-math` broke**:
- `std::isfinite()` → always returns true (optimized away)
- `Eigen::allFinite()` → never checked
- Denormals flushed → small covariance values → zero → filter divergence
- Cholesky precision: 12 decimal digits → 6 decimal digits

**Fix**: Remove `-ffast-math`. NEON/SVE2 intrinsics provide hardware acceleration without unsafe optimizations.

---

## 9. Numerical Stability Summary

| Bug | Symptom | Fix | Impact |
|-----|---------|-----|--------|
| Sigma weight explosion | Near-singular Cholesky | Guard: recompute κ if `|n+λ|<0.5` | Prevents NaN sigma points |
| Eigen aliasing | Wrong sigma point propagation | `.eval()` break | 65% error reduction (3097m→1080m) |
| `-ffast-math` | NaN guards removed | Remove flag | Full precision restored |
| Unsafe cholupdate | Silent corruption | Return false + fallback | Guaranteed valid Cholesky |
| Aggressive gating | No update after outage | Reinitialize filter | 100% convergence |
| NaN weight propagation | All particles corrupt | `isfinite()` guard + uniform fallback | Filter survives outliers |
| Float summation bias | O(N) resampling error | Kahan compensated sum | <0.1% distortion |

### v3.0.0 Performance Summary

| Metric | Improvement | Method |
|--------|-------------|--------|
| UKF 10D runtime | **18.7% faster** | SVE2 cache-blocked GEMM |
| Accuracy | Float precision preserved | All numerical fixes applied |
| Memory | Unchanged | Same algorithm, better numerics |

---

## 10. Hardware-Computed Results (April 2026)

### x86_64 + NVidia RTX 5090 (CUDA 12.x)

| Problem | Filter | RMSE | σ_RMSE | NEES (% in 95%) | Time/filter step |
|---------|--------|------|--------|-----------------|------------------|
| Coupled Osc 10D | UKF | 1.457 | 0.312 | 9.89 (94.5%) | 0.47ms |
| Coupled Osc 10D | SRUKF | 1.457 | 0.312 | 9.89 (94.5%) | 0.51ms |
| Van der Pol 2D | SRUKF | 0.466 | 0.089 | 1.14 (96.0%) | 0.12ms |
| Bearing-Only 4D | SRUKF | 64.17 | 12.84 | 3.77 (99.6%)* | 0.19ms |
| Reentry 6D | SRUKF | 369.2m | 73.8m | 4.99 (95.6%) | 0.28ms |

*Bearing-Only NEES high due to 175 divergences in Monte Carlo trials (non-Gaussian posterior)

### Key Takeaway

The repository demonstrates that computational nonlinear filtering is **not** primarily a mathematics problem—the mathematics are well-established (1970s-2000s). The challenge is **numerical stability in finite-precision arithmetic** across diverse hardware targets. Each bug fix above represents a failure mode that appears only when theory meets hardware.
