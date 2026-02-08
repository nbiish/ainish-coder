# Signals Machine Learning Detection: Expert Technical Reference

> **Beyond Expert-Level Guide to ML-Based Anomaly Detection for RF Surveillance**
>
> Part of the **signals detection** knowledge base — covering unsupervised anomaly detection, device behavior profiling, TensorFlow Lite on ESP32-S3, and advanced pattern recognition for surveillance device identification.
>
> **Companion documents**: [Signals Detection](signals.md) — WiFi/BLE | [Signals Acoustic](signals-acoustic.md) — audio ML

---

## Table of Contents

1. [ML Detection Fundamentals](#1-ml-detection-fundamentals)
2. [Feature Engineering for RF Signals](#2-feature-engineering-for-rf-signals)
3. [Unsupervised Anomaly Detection](#3-unsupervised-anomaly-detection)
4. [Device Behavior Profiling](#4-device-behavior-profiling)
5. [TensorFlow Lite on ESP32-S3](#5-tensorflow-lite-on-esp32-s3)
6. [Training Pipeline](#6-training-pipeline)
7. [Edge vs Cloud Inference](#7-edge-vs-cloud-inference)
8. [Model Evaluation & Metrics](#8-model-evaluation--metrics)
9. [Production Deployment](#9-production-deployment)
10. [Code Patterns & Best Practices](#10-code-patterns--best-practices)

---

## 1. ML Detection Fundamentals

### 1.1 Why ML for Surveillance Detection?

Traditional signature-based detection (MAC OUI, SSID patterns) has limitations:

| Challenge | Signature-Based | ML-Based |
|-----------|-----------------|----------|
| Unknown devices | ❌ Misses new variants | ✅ Detects anomalous behavior |
| MAC randomization | ❌ Defeats OUI matching | ✅ Behavior-based ID |
| Evolving threats | ❌ Requires manual updates | ✅ Adapts with retraining |
| False positives | ❌ Binary match/no-match | ✅ Confidence scores |
| Behavioral patterns | ❌ Cannot detect | ✅ Core capability |

### 1.2 ML Approach Categories

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ML Detection Approaches                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────┐    ┌─────────────────────┐                 │
│  │    SUPERVISED       │    │   UNSUPERVISED      │                 │
│  │ (Labeled examples)  │    │ (No labels needed)  │                 │
│  ├─────────────────────┤    ├─────────────────────┤                 │
│  │ • Classification    │    │ • Anomaly Detection │                 │
│  │   - Random Forest   │    │   - Isolation Forest│                 │
│  │   - SVM             │    │   - One-Class SVM   │                 │
│  │   - Neural Network  │    │   - Autoencoder     │                 │
│  │                     │    │   - DBSCAN clusters │                 │
│  │ Requires labeled    │    │ Learns "normal"     │                 │
│  │ surveillance data   │    │ from baseline only  │                 │
│  └─────────────────────┘    └─────────────────────┘                 │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    HYBRID APPROACH                               ││
│  │ Signature matching (known threats) + ML anomaly (unknown)       ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 Detection Pipeline

```
WiFi/BLE/LoRa Input
        │
        ▼
┌───────────────────┐
│ Feature Extraction│  Raw packets → numerical features
│ (§2)              │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Signature Check   │  Fast path: known patterns
│ (OUI, SSID, UUID) │
└─────────┬─────────┘
          │
    Match?├── Yes ───► ALERT (high confidence)
          │
          No
          │
          ▼
┌───────────────────┐
│ ML Inference      │  Anomaly score / classification
│ (§3, §5)          │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Threshold Check   │  Score > threshold?
│ + Confidence      │
└─────────┬─────────┘
          │
    Anomaly?├── Yes ───► ALERT (with confidence %)
             │
             No
             │
             ▼
         [Normal]
```

---

## 2. Feature Engineering for RF Signals

### 2.1 WiFi/BLE Feature Vector

| Feature Category | Features | Extraction Method |
|------------------|----------|-------------------|
| **Temporal** | Beacon interval, probe frequency, time since last seen | Timing analysis |
| **Signal** | RSSI mean/std, SNR, RSSI trend | Rolling statistics |
| **Behavioral** | Channel usage, SSID presence, advertisement types | Packet analysis |
| **Identity** | OUI prefix hash, name length, UUID count | Encoding |
| **Traffic** | Packet rate, payload size distribution | Aggregation |

### 2.2 Feature Extraction Implementation

```python
import numpy as np
from collections import defaultdict
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class DeviceObservation:
    mac: str
    rssi: float
    channel: int
    packet_type: str
    ssid: str
    timestamp: float
    service_uuids: List[str]

class FeatureExtractor:
    def __init__(self, window_seconds: float = 60.0):
        self.window_seconds = window_seconds
        self.device_history: Dict[str, List[DeviceObservation]] = defaultdict(list)
        
    def add_observation(self, obs: DeviceObservation):
        self.device_history[obs.mac].append(obs)
        # Prune old observations
        cutoff = obs.timestamp - self.window_seconds
        self.device_history[obs.mac] = [
            o for o in self.device_history[obs.mac] 
            if o.timestamp >= cutoff
        ]
    
    def extract_features(self, mac: str) -> np.ndarray:
        observations = self.device_history.get(mac, [])
        
        if len(observations) < 2:
            return np.zeros(20)  # Minimum feature vector
        
        rssi_values = [o.rssi for o in observations]
        timestamps = [o.timestamp for o in observations]
        channels = [o.channel for o in observations]
        
        # Calculate inter-arrival times
        intervals = np.diff(timestamps)
        
        features = [
            # RSSI features (4)
            np.mean(rssi_values),
            np.std(rssi_values),
            np.min(rssi_values),
            np.max(rssi_values),
            
            # Temporal features (4)
            np.mean(intervals) if len(intervals) > 0 else 0,
            np.std(intervals) if len(intervals) > 0 else 0,
            len(observations) / self.window_seconds,  # Packet rate
            timestamps[-1] - timestamps[0],  # Total duration
            
            # Channel features (3)
            len(set(channels)),  # Unique channels
            np.mean(channels),
            self._entropy(channels),
            
            # Identity features (4)
            self._oui_hash(mac),
            len(observations[0].ssid) if observations[0].ssid else 0,
            len(observations[0].service_uuids),
            self._has_surveillance_patterns(observations),
            
            # Behavioral features (5)
            self._probe_ratio(observations),
            self._beacon_ratio(observations),
            self._rssi_variability(rssi_values),
            self._channel_hopping_score(channels),
            self._timing_regularity(intervals),
        ]
        
        return np.array(features, dtype=np.float32)
    
    def _entropy(self, values: List) -> float:
        """Calculate Shannon entropy"""
        if not values:
            return 0
        counts = np.bincount(values)
        probs = counts[counts > 0] / len(values)
        return -np.sum(probs * np.log2(probs))
    
    def _oui_hash(self, mac: str) -> float:
        """Hash OUI to numeric feature (normalized)"""
        oui = mac.replace(':', '')[:6].upper()
        return hash(oui) % 10000 / 10000
    
    def _has_surveillance_patterns(self, observations: List[DeviceObservation]) -> float:
        """Check for known surveillance patterns (0-1 score)"""
        score = 0
        for obs in observations[:10]:  # Check recent observations
            ssid_upper = obs.ssid.upper() if obs.ssid else ""
            if any(p in ssid_upper for p in ['FLOCK', 'RAVEN', 'PENGUIN']):
                score += 0.5
            if any(u.startswith('00003') for u in obs.service_uuids):
                score += 0.3
        return min(score, 1.0)
    
    def _probe_ratio(self, observations: List[DeviceObservation]) -> float:
        probe_count = sum(1 for o in observations if o.packet_type == 'probe')
        return probe_count / len(observations) if observations else 0
    
    def _beacon_ratio(self, observations: List[DeviceObservation]) -> float:
        beacon_count = sum(1 for o in observations if o.packet_type == 'beacon')
        return beacon_count / len(observations) if observations else 0
    
    def _rssi_variability(self, rssi_values: List[float]) -> float:
        """Measure RSSI stability (low = stationary device)"""
        if len(rssi_values) < 2:
            return 0
        return np.std(rssi_values) / max(abs(np.mean(rssi_values)), 1)
    
    def _channel_hopping_score(self, channels: List[int]) -> float:
        """Score indicating channel hopping behavior"""
        if len(channels) < 2:
            return 0
        transitions = sum(1 for i in range(1, len(channels)) if channels[i] != channels[i-1])
        return transitions / (len(channels) - 1)
    
    def _timing_regularity(self, intervals: np.ndarray) -> float:
        """Score indicating regular transmission pattern (surveillance-like)"""
        if len(intervals) < 3:
            return 0
        cv = np.std(intervals) / max(np.mean(intervals), 0.001)
        return 1.0 / (1.0 + cv)  # Higher = more regular
```

### 2.3 ESP32 Feature Extraction (C++)

```cpp
#include <cmath>
#include <algorithm>

#define FEATURE_WINDOW_MS 60000
#define MAX_OBSERVATIONS 100
#define NUM_FEATURES 16

struct DeviceObservation {
    int8_t rssi;
    uint8_t channel;
    uint32_t timestamp_ms;
    uint8_t packet_type;  // 0=beacon, 1=probe, 2=data, 3=ble_adv
    bool has_ssid;
};

struct DeviceHistory {
    char mac[18];
    DeviceObservation observations[MAX_OBSERVATIONS];
    int count;
    int write_idx;
};

#define MAX_TRACKED_DEVICES 32
DeviceHistory device_history[MAX_TRACKED_DEVICES];
int device_count = 0;

void addObservation(const char* mac, DeviceObservation obs) {
    // Find or create device entry
    int idx = -1;
    for (int i = 0; i < device_count; i++) {
        if (strcmp(device_history[i].mac, mac) == 0) {
            idx = i;
            break;
        }
    }
    
    if (idx < 0 && device_count < MAX_TRACKED_DEVICES) {
        idx = device_count++;
        strncpy(device_history[idx].mac, mac, 17);
        device_history[idx].mac[17] = '\0';
        device_history[idx].count = 0;
        device_history[idx].write_idx = 0;
    }
    
    if (idx >= 0) {
        DeviceHistory* hist = &device_history[idx];
        hist->observations[hist->write_idx] = obs;
        hist->write_idx = (hist->write_idx + 1) % MAX_OBSERVATIONS;
        if (hist->count < MAX_OBSERVATIONS) hist->count++;
    }
}

void extractFeatures(const char* mac, float* features) {
    memset(features, 0, NUM_FEATURES * sizeof(float));
    
    // Find device
    int idx = -1;
    for (int i = 0; i < device_count; i++) {
        if (strcmp(device_history[i].mac, mac) == 0) {
            idx = i;
            break;
        }
    }
    
    if (idx < 0 || device_history[idx].count < 2) return;
    
    DeviceHistory* hist = &device_history[idx];
    uint32_t now = millis();
    
    // Collect recent observations
    int valid_count = 0;
    float rssi_sum = 0, rssi_sq_sum = 0;
    int min_rssi = 0, max_rssi = -127;
    uint32_t intervals[MAX_OBSERVATIONS];
    uint8_t channels[MAX_OBSERVATIONS];
    int interval_count = 0;
    int beacon_count = 0, probe_count = 0;
    uint32_t last_ts = 0;
    
    for (int i = 0; i < hist->count; i++) {
        DeviceObservation* obs = &hist->observations[i];
        
        if (now - obs->timestamp_ms > FEATURE_WINDOW_MS) continue;
        
        rssi_sum += obs->rssi;
        rssi_sq_sum += obs->rssi * obs->rssi;
        if (obs->rssi > max_rssi) max_rssi = obs->rssi;
        if (obs->rssi < min_rssi) min_rssi = obs->rssi;
        
        channels[valid_count] = obs->channel;
        
        if (last_ts > 0 && obs->timestamp_ms > last_ts) {
            intervals[interval_count++] = obs->timestamp_ms - last_ts;
        }
        last_ts = obs->timestamp_ms;
        
        if (obs->packet_type == 0) beacon_count++;
        if (obs->packet_type == 1) probe_count++;
        
        valid_count++;
    }
    
    if (valid_count < 2) return;
    
    // Calculate features
    float rssi_mean = rssi_sum / valid_count;
    float rssi_std = sqrt((rssi_sq_sum / valid_count) - (rssi_mean * rssi_mean));
    
    features[0] = rssi_mean;
    features[1] = rssi_std;
    features[2] = min_rssi;
    features[3] = max_rssi;
    
    // Interval features
    if (interval_count > 0) {
        float interval_sum = 0;
        for (int i = 0; i < interval_count; i++) interval_sum += intervals[i];
        features[4] = interval_sum / interval_count;
        
        float interval_sq_sum = 0;
        for (int i = 0; i < interval_count; i++) {
            float diff = intervals[i] - features[4];
            interval_sq_sum += diff * diff;
        }
        features[5] = sqrt(interval_sq_sum / interval_count);
    }
    
    features[6] = (float)valid_count / (FEATURE_WINDOW_MS / 1000.0f);  // Packet rate
    
    // Channel diversity
    int unique_channels = 1;
    for (int i = 1; i < valid_count; i++) {
        bool is_unique = true;
        for (int j = 0; j < i; j++) {
            if (channels[i] == channels[j]) {
                is_unique = false;
                break;
            }
        }
        if (is_unique) unique_channels++;
    }
    features[7] = unique_channels;
    
    // Behavioral ratios
    features[8] = (float)beacon_count / valid_count;
    features[9] = (float)probe_count / valid_count;
    
    // RSSI stability (surveillance devices often stationary)
    features[10] = rssi_std / fabs(rssi_mean + 0.001f);
    
    // Timing regularity (surveillance devices often regular)
    if (interval_count > 2 && features[4] > 0) {
        float cv = features[5] / features[4];
        features[11] = 1.0f / (1.0f + cv);
    }
}
```

---

## 3. Unsupervised Anomaly Detection

### 3.1 Isolation Forest

Isolation Forest is ideal for surveillance detection — it identifies anomalies without needing labeled examples:

```python
from sklearn.ensemble import IsolationForest
import numpy as np
import pickle

class SurveillanceAnomalyDetector:
    def __init__(self, contamination=0.05, n_estimators=100):
        self.model = IsolationForest(
            contamination=contamination,  # Expected % of anomalies
            n_estimators=n_estimators,
            random_state=42,
            n_jobs=-1
        )
        self.is_trained = False
        self.scaler = None
        
    def train(self, baseline_features: np.ndarray):
        """Train on baseline 'normal' traffic"""
        from sklearn.preprocessing import StandardScaler
        
        self.scaler = StandardScaler()
        normalized = self.scaler.fit_transform(baseline_features)
        
        self.model.fit(normalized)
        self.is_trained = True
        
        print(f"Trained on {len(baseline_features)} samples")
    
    def predict(self, features: np.ndarray) -> tuple:
        """
        Returns (is_anomaly: bool, anomaly_score: float)
        anomaly_score: negative = anomaly, positive = normal
        """
        if not self.is_trained:
            raise ValueError("Model not trained")
        
        normalized = self.scaler.transform(features.reshape(1, -1))
        prediction = self.model.predict(normalized)[0]
        score = self.model.decision_function(normalized)[0]
        
        is_anomaly = prediction == -1
        # Convert score to 0-1 range (higher = more anomalous)
        anomaly_confidence = 1.0 / (1.0 + np.exp(score))
        
        return is_anomaly, anomaly_confidence
    
    def save(self, filepath: str):
        with open(filepath, 'wb') as f:
            pickle.dump({
                'model': self.model,
                'scaler': self.scaler,
                'is_trained': self.is_trained
            }, f)
    
    def load(self, filepath: str):
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
            self.model = data['model']
            self.scaler = data['scaler']
            self.is_trained = data['is_trained']
```

### 3.2 One-Class SVM

For stricter anomaly boundaries:

```python
from sklearn.svm import OneClassSVM

class OneClassSVMDetector:
    def __init__(self, nu=0.05, kernel='rbf', gamma='scale'):
        self.model = OneClassSVM(
            nu=nu,  # Upper bound on fraction of outliers
            kernel=kernel,
            gamma=gamma
        )
        self.is_trained = False
        
    def train(self, baseline_features: np.ndarray):
        from sklearn.preprocessing import StandardScaler
        
        self.scaler = StandardScaler()
        normalized = self.scaler.fit_transform(baseline_features)
        
        self.model.fit(normalized)
        self.is_trained = True
    
    def predict(self, features: np.ndarray) -> tuple:
        normalized = self.scaler.transform(features.reshape(1, -1))
        prediction = self.model.predict(normalized)[0]
        distance = self.model.decision_function(normalized)[0]
        
        is_anomaly = prediction == -1
        anomaly_score = max(0, -distance)  # Higher = more anomalous
        
        return is_anomaly, anomaly_score
```

### 3.3 Autoencoder Anomaly Detection

Neural network approach — learns to reconstruct normal patterns:

```python
import tensorflow as tf
from tensorflow.keras import layers, Model

class AutoencoderDetector:
    def __init__(self, input_dim: int, encoding_dim: int = 8):
        self.input_dim = input_dim
        self.encoding_dim = encoding_dim
        self.model = self._build_model()
        self.threshold = None
        
    def _build_model(self) -> Model:
        inputs = layers.Input(shape=(self.input_dim,))
        
        # Encoder
        x = layers.Dense(64, activation='relu')(inputs)
        x = layers.Dropout(0.2)(x)
        x = layers.Dense(32, activation='relu')(x)
        encoded = layers.Dense(self.encoding_dim, activation='relu')(x)
        
        # Decoder
        x = layers.Dense(32, activation='relu')(encoded)
        x = layers.Dense(64, activation='relu')(x)
        decoded = layers.Dense(self.input_dim, activation='linear')(x)
        
        autoencoder = Model(inputs, decoded)
        autoencoder.compile(optimizer='adam', loss='mse')
        
        return autoencoder
    
    def train(self, baseline_features: np.ndarray, epochs: int = 50):
        from sklearn.preprocessing import StandardScaler
        
        self.scaler = StandardScaler()
        normalized = self.scaler.fit_transform(baseline_features)
        
        self.model.fit(
            normalized, normalized,
            epochs=epochs,
            batch_size=32,
            validation_split=0.1,
            verbose=1
        )
        
        # Set threshold based on training reconstruction errors
        reconstructions = self.model.predict(normalized)
        mse = np.mean(np.power(normalized - reconstructions, 2), axis=1)
        self.threshold = np.percentile(mse, 95)
        
        print(f"Threshold set to {self.threshold:.4f}")
    
    def predict(self, features: np.ndarray) -> tuple:
        normalized = self.scaler.transform(features.reshape(1, -1))
        reconstruction = self.model.predict(normalized, verbose=0)
        mse = np.mean(np.power(normalized - reconstruction, 2))
        
        is_anomaly = mse > self.threshold
        anomaly_score = mse / (self.threshold + 1e-6)
        
        return is_anomaly, min(anomaly_score, 5.0)  # Cap at 5x threshold
```

---

## 4. Device Behavior Profiling

### 4.1 Time-Series Behavioral Analysis

```python
from dataclasses import dataclass
from typing import Optional
import numpy as np

@dataclass
class BehaviorProfile:
    mac_address: str
    avg_interval_ms: float
    interval_variance: float
    typical_rssi: float
    rssi_stability: float
    active_hours: set  # Hours of day when device is seen
    channel_preference: int
    is_stationary: bool
    regularity_score: float  # 0-1, higher = more regular/suspicious
    
    def to_feature_vector(self) -> np.ndarray:
        return np.array([
            self.avg_interval_ms / 1000,  # Normalize to seconds
            self.interval_variance,
            self.typical_rssi,
            self.rssi_stability,
            len(self.active_hours) / 24,
            self.channel_preference / 14,  # Normalize channel
            float(self.is_stationary),
            self.regularity_score
        ])

class BehaviorProfiler:
    def __init__(self, min_observations: int = 10):
        self.min_observations = min_observations
        self.profiles = {}
        
    def update_profile(self, mac: str, observations: list) -> Optional[BehaviorProfile]:
        if len(observations) < self.min_observations:
            return None
        
        timestamps = [o.timestamp for o in observations]
        rssi_values = [o.rssi for o in observations]
        channels = [o.channel for o in observations]
        
        # Calculate intervals
        intervals = np.diff(timestamps)
        
        # Active hours
        from datetime import datetime
        hours = {datetime.fromtimestamp(t).hour for t in timestamps}
        
        # Regularity score (coefficient of variation inverse)
        if len(intervals) > 1 and np.mean(intervals) > 0:
            cv = np.std(intervals) / np.mean(intervals)
            regularity = 1.0 / (1.0 + cv)
        else:
            regularity = 0
        
        # RSSI stability
        rssi_stability = 1.0 / (1.0 + np.std(rssi_values)) if rssi_values else 0
        
        # Stationary detection
        is_stationary = np.std(rssi_values) < 3.0  # Low RSSI variance
        
        profile = BehaviorProfile(
            mac_address=mac,
            avg_interval_ms=np.mean(intervals) * 1000 if len(intervals) > 0 else 0,
            interval_variance=np.var(intervals) if len(intervals) > 1 else 0,
            typical_rssi=np.median(rssi_values),
            rssi_stability=rssi_stability,
            active_hours=hours,
            channel_preference=max(set(channels), key=channels.count),
            is_stationary=is_stationary,
            regularity_score=regularity
        )
        
        self.profiles[mac] = profile
        return profile
    
    def get_suspicious_devices(self, threshold: float = 0.7) -> list:
        """Return devices with high regularity (surveillance-like behavior)"""
        suspicious = []
        for mac, profile in self.profiles.items():
            if profile.regularity_score > threshold and profile.is_stationary:
                suspicious.append((mac, profile))
        return sorted(suspicious, key=lambda x: -x[1].regularity_score)
```

---

## 5. TensorFlow Lite on ESP32-S3

### 5.1 Model Architecture for Edge Inference

```python
# Training script (on development machine)
import tensorflow as tf

def create_edge_model(input_dim: int = 16, num_classes: int = 2):
    """Small model suitable for ESP32-S3 (under 100KB)"""
    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=(input_dim,)),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def convert_to_tflite(model, output_path: str):
    """Convert Keras model to quantized TFLite for ESP32"""
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Full integer quantization for ESP32
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.int8]
    converter.inference_input_type = tf.float32  # Keep float input
    converter.inference_output_type = tf.float32  # Keep float output
    
    tflite_model = converter.convert()
    
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"Model saved: {len(tflite_model)} bytes")
    return tflite_model

def generate_c_array(tflite_path: str, header_path: str):
    """Generate C header file for ESP32 embedding"""
    import os
    
    with open(tflite_path, 'rb') as f:
        data = f.read()
    
    with open(header_path, 'w') as f:
        f.write("// Auto-generated TFLite model\n")
        f.write(f"// Size: {len(data)} bytes\n\n")
        f.write("alignas(8) const unsigned char surveillance_model[] = {\n")
        
        for i, byte in enumerate(data):
            if i % 12 == 0:
                f.write("    ")
            f.write(f"0x{byte:02x}, ")
            if i % 12 == 11:
                f.write("\n")
        
        f.write("\n};\n")
        f.write(f"const unsigned int surveillance_model_len = {len(data)};\n")
    
    print(f"Header generated: {header_path}")
```

### 5.2 ESP32 TFLite Micro Inference

```cpp
#include "tensorflow/lite/micro/all_ops_resolver.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_log.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "surveillance_model.h"  // Generated C array

// Tensor arena - adjust based on model size
constexpr int kTensorArenaSize = 16 * 1024;
alignas(16) uint8_t tensor_arena[kTensorArenaSize];

// TFLite globals
tflite::AllOpsResolver resolver;
const tflite::Model* model = nullptr;
tflite::MicroInterpreter* interpreter = nullptr;
TfLiteTensor* input = nullptr;
TfLiteTensor* output = nullptr;

bool initML() {
    // Load model
    model = tflite::GetModel(surveillance_model);
    if (model->version() != TFLITE_SCHEMA_VERSION) {
        Serial.printf("Model version mismatch: %lu vs %d\n", 
                      model->version(), TFLITE_SCHEMA_VERSION);
        return false;
    }
    
    // Create interpreter
    static tflite::MicroInterpreter static_interpreter(
        model, resolver, tensor_arena, kTensorArenaSize);
    interpreter = &static_interpreter;
    
    // Allocate tensors
    TfLiteStatus status = interpreter->AllocateTensors();
    if (status != kTfLiteOk) {
        Serial.println("Tensor allocation failed");
        return false;
    }
    
    // Get input/output tensors
    input = interpreter->input(0);
    output = interpreter->output(0);
    
    Serial.printf("ML initialized: input shape [%d], output shape [%d]\n",
                  input->dims->data[1], output->dims->data[1]);
    
    return true;
}

float inferSurveillanceProbability(float* features, int num_features) {
    // Check input dimension
    if (num_features != input->dims->data[1]) {
        Serial.printf("Feature count mismatch: %d vs %d\n", 
                      num_features, input->dims->data[1]);
        return -1;
    }
    
    // Copy features to input tensor
    for (int i = 0; i < num_features; i++) {
        input->data.f[i] = features[i];
    }
    
    // Run inference
    TfLiteStatus status = interpreter->Invoke();
    if (status != kTfLiteOk) {
        Serial.println("Inference failed");
        return -1;
    }
    
    // Get probability of surveillance class (assuming class 1 = surveillance)
    float normal_prob = output->data.f[0];
    float surveillance_prob = output->data.f[1];
    
    return surveillance_prob;
}

// Usage in main detection loop
void checkDeviceWithML(const char* mac) {
    float features[NUM_FEATURES];
    extractFeatures(mac, features);
    
    float prob = inferSurveillanceProbability(features, NUM_FEATURES);
    
    if (prob > 0.7) {
        Serial.printf("⚠️ SUSPICIOUS DEVICE: %s (%.1f%% confidence)\n", 
                      mac, prob * 100);
        // Trigger alert
    } else if (prob > 0.4) {
        Serial.printf("Elevated: %s (%.1f%%)\n", mac, prob * 100);
    }
}
```

---

## 6. Training Pipeline

### 6.1 Data Collection Strategy

```python
import json
from datetime import datetime
import sqlite3

class TrainingDataCollector:
    def __init__(self, db_path: str = "training_data.db"):
        self.conn = sqlite3.connect(db_path)
        self._create_tables()
        
    def _create_tables(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS observations (
                id INTEGER PRIMARY KEY,
                timestamp REAL,
                mac TEXT,
                rssi INTEGER,
                channel INTEGER,
                ssid TEXT,
                packet_type TEXT,
                service_uuids TEXT,
                label INTEGER DEFAULT NULL
            )
        """)
        self.conn.commit()
    
    def add_observation(self, mac: str, rssi: int, channel: int, 
                        ssid: str, packet_type: str, service_uuids: list,
                        label: int = None):
        self.conn.execute("""
            INSERT INTO observations 
            (timestamp, mac, rssi, channel, ssid, packet_type, service_uuids, label)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            datetime.now().timestamp(),
            mac, rssi, channel, ssid, packet_type,
            json.dumps(service_uuids),
            label
        ))
        self.conn.commit()
    
    def export_features(self, extractor: 'FeatureExtractor') -> tuple:
        """Export features and labels for training"""
        cursor = self.conn.execute("""
            SELECT mac, label FROM observations 
            WHERE label IS NOT NULL
            GROUP BY mac
        """)
        
        features = []
        labels = []
        
        for mac, label in cursor:
            # Get all observations for this MAC
            obs_cursor = self.conn.execute("""
                SELECT * FROM observations WHERE mac = ?
            """, (mac,))
            
            observations = [
                DeviceObservation(
                    mac=row[2],
                    rssi=row[3],
                    channel=row[4],
                    packet_type=row[6],
                    ssid=row[5] or '',
                    timestamp=row[1],
                    service_uuids=json.loads(row[7])
                )
                for row in obs_cursor
            ]
            
            for obs in observations:
                extractor.add_observation(obs)
            
            feature_vec = extractor.extract_features(mac)
            features.append(feature_vec)
            labels.append(label)
        
        return np.array(features), np.array(labels)
```

### 6.2 Training Script

```python
#!/usr/bin/env python3
"""Train surveillance detection model"""

import argparse
import numpy as np
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', required=True, help='Training data DB path')
    parser.add_argument('--output', default='model', help='Output path prefix')
    parser.add_argument('--model-type', choices=['isolation_forest', 'classifier', 'autoencoder'],
                       default='isolation_forest')
    args = parser.parse_args()
    
    # Load data
    collector = TrainingDataCollector(args.data)
    extractor = FeatureExtractor()
    features, labels = collector.export_features(extractor)
    
    print(f"Dataset: {len(features)} samples")
    print(f"Label distribution: {dict(zip(*np.unique(labels, return_counts=True)))}")
    
    if args.model_type == 'isolation_forest':
        # Unsupervised - train only on normal (label=0)
        normal_features = features[labels == 0]
        
        detector = SurveillanceAnomalyDetector(contamination=0.05)
        detector.train(normal_features)
        detector.save(f"{args.output}_isolation_forest.pkl")
        
        # Evaluate
        predictions = [detector.predict(f)[0] for f in features]
        print("\nIsolation Forest Results:")
        print(classification_report(labels, predictions))
        
    elif args.model_type == 'classifier':
        # Supervised classification
        X_train, X_test, y_train, y_test = train_test_split(
            features, labels, test_size=0.2, random_state=42
        )
        
        model = create_edge_model(input_dim=features.shape[1])
        model.fit(X_train, y_train, epochs=50, validation_split=0.1, verbose=1)
        
        # Evaluate
        y_pred = model.predict(X_test).argmax(axis=1)
        print("\nClassifier Results:")
        print(classification_report(y_test, y_pred))
        
        # Convert to TFLite
        convert_to_tflite(model, f"{args.output}.tflite")
        generate_c_array(f"{args.output}.tflite", f"{args.output}_model.h")

if __name__ == "__main__":
    main()
```

---

## 7. Edge vs Cloud Inference

### 7.1 Comparison

| Factor | Edge (ESP32) | Cloud |
|--------|--------------|-------|
| **Latency** | <50ms | 100-500ms (network) |
| **Privacy** | Data stays local | Data transmitted |
| **Power** | ~50mA inference | +WiFi TX overhead |
| **Model Size** | <200KB | Unlimited |
| **Accuracy** | Good (simple models) | Better (complex models) |
| **Offline** | ✅ Works | ❌ Requires connection |

### 7.2 Hybrid Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Hybrid Detection Architecture                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ESP32 (Edge)                             Cloud/Pi (Server)        │
│   ┌───────────────────┐                   ┌────────────────────┐    │
│   │ Fast Signature    │──Match───────────►│ Alert Dashboard    │    │
│   │ Check (OUI/SSID)  │                   │                    │    │
│   └─────────┬─────────┘                   │                    │    │
│             │                             │                    │    │
│      No Match                             │                    │    │
│             │                             │                    │    │
│   ┌─────────▼─────────┐                   │                    │    │
│   │ TFLite Anomaly    │                   │                    │    │
│   │ Score             │                   │                    │    │
│   └─────────┬─────────┘                   │                    │    │
│             │                             │                    │    │
│      Score >0.6?                          │                    │    │
│       │      │                            │                    │    │
│     Yes      No                           │                    │    │
│       │      │                            │                    │    │
│       │      └──► [Normal, skip]          │                    │    │
│       │                                   │                    │    │
│   ┌───▼───────────────┐                   │                    │    │
│   │ Upload Features   │──WiFi/BLE────────►│ Advanced Analysis  │    │
│   │ for Cloud Review  │                   │ (Deep Learning)    │    │
│   └───────────────────┘                   │                    │    │
│                                           │                    │    │
│                                           │        │           │    │
│                                           │        ▼           │    │
│   ┌───────────────────┐                   │ ┌──────────────┐   │    │
│   │ Receive Verdict   │◄──────────────────│ │ Surveillance │   │    │
│   │ Update Threshold  │                   │ │ Probability  │   │    │
│   └───────────────────┘                   │ └──────────────┘   │    │
│                                           └────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Model Evaluation & Metrics

### 8.1 Key Metrics for Surveillance Detection

| Metric | Definition | Target | Priority |
|--------|------------|--------|----------|
| **Recall (Sensitivity)** | True surveillance / All surveillance | >95% | **Critical** — don't miss threats |
| **Precision** | True surveillance / Predicted surveillance | >80% | Important — reduce false alarms |
| **F1 Score** | Harmonic mean of precision/recall | >0.87 | Balanced metric |
| **False Positive Rate** | False alarms / Normal devices | <5% | User experience |

### 8.2 Evaluation Implementation

```python
from sklearn.metrics import precision_recall_curve, roc_curve, auc
import matplotlib.pyplot as plt

def evaluate_detector(detector, features: np.ndarray, labels: np.ndarray):
    """Comprehensive evaluation with visualization"""
    
    # Get predictions and scores
    predictions = []
    scores = []
    for f in features:
        is_anomaly, score = detector.predict(f)
        predictions.append(int(is_anomaly))
        scores.append(score)
    
    predictions = np.array(predictions)
    scores = np.array(scores)
    
    # Classification report
    print("Classification Report:")
    print(classification_report(labels, predictions, 
                               target_names=['Normal', 'Surveillance']))
    
    # Confusion matrix
    cm = confusion_matrix(labels, predictions)
    print(f"\nConfusion Matrix:\n{cm}")
    
    # ROC curve
    fpr, tpr, _ = roc_curve(labels, scores)
    roc_auc = auc(fpr, tpr)
    
    # Precision-Recall curve
    precision, recall, thresholds = precision_recall_curve(labels, scores)
    pr_auc = auc(recall, precision)
    
    # Plot
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    axes[0].plot(fpr, tpr, label=f'ROC (AUC = {roc_auc:.3f})')
    axes[0].plot([0, 1], [0, 1], 'k--')
    axes[0].set_xlabel('False Positive Rate')
    axes[0].set_ylabel('True Positive Rate')
    axes[0].set_title('ROC Curve')
    axes[0].legend()
    
    axes[1].plot(recall, precision, label=f'PR (AUC = {pr_auc:.3f})')
    axes[1].set_xlabel('Recall')
    axes[1].set_ylabel('Precision')
    axes[1].set_title('Precision-Recall Curve')
    axes[1].legend()
    
    plt.tight_layout()
    plt.savefig('evaluation_curves.png', dpi=150)
    plt.close()
    
    return {
        'roc_auc': roc_auc,
        'pr_auc': pr_auc,
        'confusion_matrix': cm
    }
```

---

## 9. Production Deployment

### 9.1 Model Update Workflow

```
1. Collect new observations (continuous)
         ↓
2. Periodic retraining (weekly/monthly)
         ↓
3. Evaluate on held-out test set
         ↓
4. If metrics improve:
   - Generate new TFLite model
   - Generate C header
   - OTA update to ESP32 fleet
```

### 9.2 ESP32 OTA Model Update

```cpp
#include <HTTPClient.h>
#include <SPIFFS.h>

#define MODEL_VERSION_URL "https://your-server.com/model_version.txt"
#define MODEL_DOWNLOAD_URL "https://your-server.com/model.tflite"

int current_model_version = 1;

bool checkForModelUpdate() {
    HTTPClient http;
    http.begin(MODEL_VERSION_URL);
    int code = http.GET();
    
    if (code == 200) {
        int server_version = http.getString().toInt();
        http.end();
        return server_version > current_model_version;
    }
    
    http.end();
    return false;
}

bool downloadAndUpdateModel() {
    HTTPClient http;
    http.begin(MODEL_DOWNLOAD_URL);
    int code = http.GET();
    
    if (code != 200) {
        http.end();
        return false;
    }
    
    // Write to SPIFFS
    File file = SPIFFS.open("/model.tflite", "w");
    if (!file) {
        http.end();
        return false;
    }
    
    http.writeToStream(&file);
    file.close();
    http.end();
    
    // Reinitialize ML with new model
    // (In practice, would need to reload from SPIFFS)
    return true;
}
```

---

## 10. Code Patterns & Best Practices

### 10.1 Inference Batching

```cpp
#define BATCH_SIZE 8
#define MAX_INFERENCE_MS 100  // Time limit per batch

float inference_queue[BATCH_SIZE][NUM_FEATURES];
int queue_count = 0;

void addToInferenceQueue(float* features) {
    if (queue_count < BATCH_SIZE) {
        memcpy(inference_queue[queue_count], features, NUM_FEATURES * sizeof(float));
        queue_count++;
    }
}

void processBatch() {
    if (queue_count == 0) return;
    
    uint32_t start = millis();
    
    for (int i = 0; i < queue_count && (millis() - start) < MAX_INFERENCE_MS; i++) {
        float prob = inferSurveillanceProbability(inference_queue[i], NUM_FEATURES);
        // Handle result...
    }
    
    queue_count = 0;
}
```

### 10.2 Feature Normalization

```cpp
// Pre-computed normalization parameters (from training)
const float feature_means[NUM_FEATURES] = { /* from scaler.mean_ */ };
const float feature_stds[NUM_FEATURES] = { /* from scaler.scale_ */ };

void normalizeFeatures(float* features) {
    for (int i = 0; i < NUM_FEATURES; i++) {
        features[i] = (features[i] - feature_means[i]) / (feature_stds[i] + 1e-6f);
    }
}
```

---

## Quick Reference Card

### Feature Vector (16 dimensions)

| Index | Feature | Range |
|-------|---------|-------|
| 0-3 | RSSI (mean, std, min, max) | -100 to 0 dBm |
| 4-5 | Interval (mean, std) | 0 to 60000 ms |
| 6 | Packet rate | 0 to 100 /sec |
| 7 | Unique channels | 1 to 14 |
| 8-9 | Beacon/probe ratio | 0 to 1 |
| 10 | RSSI stability | 0 to 1 |
| 11 | Timing regularity | 0 to 1 |

### Model Sizes

| Model Type | Typical Size | ESP32 Compatible |
|------------|--------------|------------------|
| Isolation Forest (pkl) | 50-200 KB | ❌ (sklearn) |
| TFLite (int8) | 20-100 KB | ✅ |
| TFLite (float32) | 50-200 KB | ✅ |

### Key Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Anomaly score | >0.7 | Alert |
| Surveillance probability | >0.8 | High-priority alert |
| Regularity score | >0.8 | Flag as suspicious |

---

## Resources & References

### Libraries
- **TensorFlow Lite Micro**: https://www.tensorflow.org/lite/microcontrollers
- **scikit-learn**: https://scikit-learn.org
- **ESP-TFLite-Micro**: https://github.com/espressif/esp-tflite-micro

### Research
- "Isolation Forest" - Liu et al. (2008)
- "One-Class SVM" - Schölkopf et al. (2001)
- "Deep Learning for Anomaly Detection" - Chalapathy & Chawla (2019)

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of ainish-coder signals detection suite*
