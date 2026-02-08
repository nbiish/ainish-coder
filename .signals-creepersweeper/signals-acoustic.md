# Signals Acoustic Detection: Expert Technical Reference

> **Beyond Expert-Level Guide to Acoustic Surveillance Detection & Audio Signal Analysis**
>
> Part of the **signals detection** knowledge base — covering ShotSpotter/Raven acoustic sensors, ESP32 microphone integration, audio fingerprinting, and machine learning for sound classification.
>
> **Companion documents**: [Signals Detection](signals.md) — WiFi/BLE detection | [Signals Image/Video](signals-security-image-video.md) — camera systems

---

## Table of Contents

1. [Acoustic Surveillance Fundamentals](#1-acoustic-surveillance-fundamentals)
2. [ShotSpotter/Raven Acoustic Sensors](#2-shotshotterraven-acoustic-sensors)
3. [Sound Physics for Detection](#3-sound-physics-for-detection)
4. [ESP32 Microphone Integration](#4-esp32-microphone-integration)
5. [Audio Signal Processing](#5-audio-signal-processing)
6. [Machine Learning Audio Classification](#6-machine-learning-audio-classification)
7. [Python Audio Analysis Tools](#7-python-audio-analysis-tools)
8. [Detection Signatures & Patterns](#8-detection-signatures--patterns)
9. [Counter-Acoustic Surveillance](#9-counter-acoustic-surveillance)
10. [Code Patterns & Best Practices](#10-code-patterns--best-practices)

---

## 1. Acoustic Surveillance Fundamentals

### 1.1 Types of Acoustic Surveillance Systems

| System Type | Frequency Range | Detection Range | Common Deployments |
|-------------|-----------------|-----------------|-------------------|
| **Gunshot Detection** | 20 Hz - 20 kHz (focus: 1-10 kHz) | 1-3 km radius | Urban areas, schools |
| **Voice Surveillance** | 300 Hz - 3.4 kHz | 10-100m | Law enforcement, corporate |
| **Ultrasonic Beacons** | 18-22 kHz | 10-50m | Cross-device tracking |
| **Infrasound Monitoring** | 0.1-20 Hz | 10+ km | Explosion detection |
| **Environmental Acoustic** | Full spectrum | Varies | Wildlife, traffic monitoring |

### 1.2 Acoustic Triangulation Principles

Gunshot detection systems use **Time Difference of Arrival (TDoA)** across multiple sensors:

```
         Sensor A ●─────────────┐
              ↑                 │
         t₁ = 0.05s             │
              │                 │
    Sound Source 🔫 ────────────┤ TDoA = t₂ - t₁
              │                 │
         t₂ = 0.08s             │
              ↓                 │
         Sensor B ●─────────────┘
```

**Location Formula**:
```
Distance = Speed of Sound × Time Difference
d = 343 m/s × Δt

With 3+ sensors, hyperbolic intersection determines position
Accuracy: ±3-25 meters depending on sensor density
```

### 1.3 Speed of Sound Variables

| Condition | Speed (m/s) | Impact on Detection |
|-----------|-------------|---------------------|
| Dry air, 20°C | 343 | Baseline |
| Dry air, 0°C | 331 | -3.5% slower |
| Dry air, 35°C | 352 | +2.6% faster |
| High humidity | +0.5-1% | Minor effect |
| Wind (tailwind) | +wind speed | Directional bias |
| Wind (headwind) | -wind speed | Directional bias |

**Practical formula**:
```
v = 331.3 + (0.606 × T)
where T = temperature in Celsius
```

---

## 2. ShotSpotter/Raven Acoustic Sensors

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ShotSpotter/SoundThinking Architecture            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐       │
│   │  Raven 1  │  │  Raven 2  │  │  Raven 3  │  │  Raven N  │       │
│   │ (Sensor)  │  │ (Sensor)  │  │ (Sensor)  │  │ (Sensor)  │       │
│   │ LTE/WiFi  │  │ LTE/WiFi  │  │ LTE/WiFi  │  │ LTE/WiFi  │       │
│   └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       │
│         │              │              │              │              │
│         └──────────────┴──────────────┴──────────────┘              │
│                               │                                      │
│                     ┌─────────▼─────────┐                           │
│                     │  SoundThinking    │                           │
│                     │  Cloud Platform   │                           │
│                     │  (Audio Analysis) │                           │
│                     └─────────┬─────────┘                           │
│                               │                                      │
│                     ┌─────────▼─────────┐                           │
│                     │  Human Reviewers  │                           │
│                     │  (Verification)   │                           │
│                     └─────────┬─────────┘                           │
│                               │                                      │
│                     ┌─────────▼─────────┐                           │
│                     │  Law Enforcement  │                           │
│                     │     Dispatch      │                           │
│                     └───────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Raven Sensor Specifications (Inferred)

| Component | Specification | Detection Relevance |
|-----------|--------------|---------------------|
| **Microphones** | MEMS array (2-4 elements) | Multi-directional capture |
| **Frequency Response** | 20 Hz - 20 kHz | Full audio spectrum |
| **Sampling Rate** | 48 kHz (likely) | Nyquist for 20 kHz |
| **ADC Resolution** | 16-24 bit | High dynamic range |
| **Storage** | Flash buffer (pre-trigger) | Captures event lead-in |
| **Connectivity** | LTE Cat-M1, WiFi backup | Low power cellular |
| **Power** | Solar + battery | Continuous operation |
| **BLE Services** | See signals.md §4.3 | Fingerprinting vector |

### 2.3 Detection via BLE (Cross-Reference)

Raven sensors advertise BLE services that reveal operational state:

| BLE Characteristic | UUID | Data Type | Detection Use |
|-------------------|------|-----------|---------------|
| Audio Upload Count | 0x3403 | Integer | Activity indicator |
| Battery State | 0x3205 | String | Operational status |
| GPS Coordinates | 0x3101/0x3102 | Float | Sensor location |
| LTE RSSI | 0x3304 | String | Network health |

**Detection Strategy**: Monitor for BLE advertisements with Raven service UUIDs (0x3100-0x3500). See [signals.md §4.3](signals.md) for UUID fingerprinting code.

---

## 3. Sound Physics for Detection

### 3.1 Acoustic Energy Propagation

Sound intensity decreases with distance following the **inverse square law**:

```
I₂ = I₁ × (r₁/r₂)²

where:
I = intensity (W/m²)
r = distance from source
```

**dB SPL at distance**:
```
SPL₂ = SPL₁ - 20 × log₁₀(r₂/r₁)

Example: 140 dB gunshot at 1m → 80 dB at 100m
```

### 3.2 Gunshot Acoustic Signature

| Phase | Duration | Frequency Content | dB SPL (at source) |
|-------|----------|-------------------|-------------------|
| **Muzzle blast** | 1-5 ms | Wideband impulse | 140-170 dB |
| **Projectile shock wave** | Continuous | Supersonic crack >1 kHz | 120-140 dB |
| **Mechanical action** | 10-50 ms | Mid-frequency | 80-100 dB |
| **Reflections** | 50-500 ms | Building-dependent | Variable |

### 3.3 Frequency Characteristics by Weapon Type

| Weapon Category | Dominant Frequencies | Impulse Duration | Distinguishing Features |
|-----------------|---------------------|------------------|------------------------|
| **Handgun (9mm)** | 500 Hz - 4 kHz | 2-4 ms | Sharp, high-frequency |
| **Rifle (.223)** | 300 Hz - 6 kHz | 1-3 ms | Supersonic crack |
| **Shotgun** | 200 Hz - 2 kHz | 5-10 ms | Lower frequency, longer |
| **Firework** | 100 Hz - 3 kHz | 10-50 ms | Longer tail, irregular |
| **Car backfire** | 50 Hz - 1 kHz | 50-200 ms | Low frequency dominant |

---

## 4. ESP32 Microphone Integration

### 4.1 Recommended I2S Microphones

| Microphone | Interface | SNR | Sensitivity | Price | Use Case |
|------------|-----------|-----|-------------|-------|----------|
| **INMP441** | I2S | 61 dB | -26 dBFS | $3-5 | General audio |
| **SPH0645** | I2S PDM | 65 dB | -26 dBFS | $5-8 | Higher quality |
| **ICS-43434** | I2S | 65 dB | -26 dBFS | $4-6 | Low power |
| **MAX4466** | Analog | 46 dB | Adjustable | $3-5 | Simple projects |

### 4.2 INMP441 Wiring to ESP32-S3

```
INMP441          ESP32-S3
┌──────────┐     ┌──────────┐
│ VDD      │─────│ 3V3      │
│ GND      │─────│ GND      │
│ SD       │─────│ GPIO 4   │  (I2S Data)
│ WS       │─────│ GPIO 5   │  (I2S Word Select / LRCLK)
│ SCK      │─────│ GPIO 6   │  (I2S Clock / BCLK)
│ L/R      │─────│ GND      │  (Left channel)
└──────────┘     └──────────┘
```

### 4.3 ESP-IDF I2S Configuration

```c
#include "driver/i2s_std.h"
#include "driver/gpio.h"

#define I2S_NUM         I2S_NUM_0
#define I2S_BCK_PIN     GPIO_NUM_6
#define I2S_WS_PIN      GPIO_NUM_5
#define I2S_DATA_PIN    GPIO_NUM_4
#define SAMPLE_RATE     44100
#define SAMPLE_BITS     I2S_DATA_BIT_WIDTH_32BIT

static i2s_chan_handle_t rx_handle;

void init_i2s_microphone(void) {
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM, I2S_ROLE_MASTER);
    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, NULL, &rx_handle));

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(SAMPLE_RATE),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(SAMPLE_BITS, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = I2S_BCK_PIN,
            .ws = I2S_WS_PIN,
            .dout = I2S_GPIO_UNUSED,
            .din = I2S_DATA_PIN,
            .invert_flags = {
                .mclk_inv = false,
                .bclk_inv = false,
                .ws_inv = false,
            },
        },
    };
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(rx_handle, &std_cfg));
    ESP_ERROR_CHECK(i2s_channel_enable(rx_handle));
}

void read_audio_samples(int32_t* buffer, size_t sample_count) {
    size_t bytes_read;
    ESP_ERROR_CHECK(i2s_channel_read(rx_handle, buffer, sample_count * sizeof(int32_t), 
                                      &bytes_read, portMAX_DELAY));
}
```

### 4.4 Arduino I2S Example

```cpp
#include <driver/i2s.h>

#define I2S_PORT I2S_NUM_0
#define I2S_SAMPLE_RATE 44100
#define I2S_SAMPLE_BITS 32
#define I2S_READ_LEN 1024

void setupI2S() {
    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = I2S_SAMPLE_RATE,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 4,
        .dma_buf_len = I2S_READ_LEN,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0
    };

    i2s_pin_config_t pin_config = {
        .bck_io_num = 6,
        .ws_io_num = 5,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = 4
    };

    i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_PORT, &pin_config);
}

int32_t readMicrophoneLevel() {
    int32_t samples[I2S_READ_LEN];
    size_t bytes_read;
    
    i2s_read(I2S_PORT, samples, sizeof(samples), &bytes_read, portMAX_DELAY);
    
    // Calculate RMS amplitude
    int64_t sum = 0;
    int sample_count = bytes_read / sizeof(int32_t);
    for (int i = 0; i < sample_count; i++) {
        int32_t sample = samples[i] >> 14;  // Scale 32-bit to 18-bit
        sum += (int64_t)sample * sample;
    }
    return sqrt(sum / sample_count);
}
```

---

## 5. Audio Signal Processing

### 5.1 Digital Signal Processing Pipeline

```
┌────────────┐    ┌────────────┐    ┌────────────┐    ┌────────────┐
│   I2S      │───►│   Band     │───►│   FFT      │───►│  Feature   │
│  Samples   │    │  Pass      │    │  Analysis  │    │ Extraction │
│ (44.1kHz)  │    │ (100-8kHz) │    │ (1024-pt)  │    │            │
└────────────┘    └────────────┘    └────────────┘    └─────┬──────┘
                                                            │
┌────────────┐    ┌────────────┐    ┌────────────┐          │
│   Alert    │◄───│  Threshold │◄───│   ML       │◄─────────┘
│  Trigger   │    │   Check    │    │ Classifier │
└────────────┘    └────────────┘    └────────────┘
```

### 5.2 Fast Fourier Transform (FFT) on ESP32

```c
#include "esp_dsp.h"

#define FFT_SIZE 1024

float fft_input[FFT_SIZE];
float fft_output[FFT_SIZE];
float window[FFT_SIZE];

void init_fft(void) {
    // Initialize Hann window
    dsps_wind_hann_f32(window, FFT_SIZE);
    // Initialize FFT tables
    dsps_fft2r_init_fc32(NULL, FFT_SIZE);
}

void compute_fft(float* samples) {
    // Apply window function
    for (int i = 0; i < FFT_SIZE; i++) {
        fft_input[i] = samples[i] * window[i];
    }
    
    // Compute real FFT
    dsps_fft2r_fc32(fft_input, FFT_SIZE);
    dsps_bit_rev_fc32(fft_input, FFT_SIZE);
    dsps_cplx2reC_fc32(fft_input, FFT_SIZE);
    
    // Compute magnitude spectrum
    for (int i = 0; i < FFT_SIZE / 2; i++) {
        float real = fft_input[i * 2];
        float imag = fft_input[i * 2 + 1];
        fft_output[i] = sqrtf(real * real + imag * imag);
    }
}

float get_frequency_bin_hz(int bin) {
    return (float)bin * SAMPLE_RATE / FFT_SIZE;
}
```

### 5.3 Impulse Detection Algorithm

```c
#define NOISE_FLOOR_SAMPLES 100
#define IMPULSE_THRESHOLD_MULTIPLIER 6.0f
#define IMPULSE_MIN_DURATION_MS 1
#define IMPULSE_MAX_DURATION_MS 50

typedef struct {
    float noise_floor;
    float peak_level;
    uint32_t impulse_start_ms;
    bool impulse_active;
} ImpulseDetector;

static ImpulseDetector detector = {0};

void update_noise_floor(float rms_level) {
    static float noise_samples[NOISE_FLOOR_SAMPLES];
    static int sample_index = 0;
    
    noise_samples[sample_index] = rms_level;
    sample_index = (sample_index + 1) % NOISE_FLOOR_SAMPLES;
    
    // Compute running average
    float sum = 0;
    for (int i = 0; i < NOISE_FLOOR_SAMPLES; i++) {
        sum += noise_samples[i];
    }
    detector.noise_floor = sum / NOISE_FLOOR_SAMPLES;
}

bool detect_impulse(float rms_level, uint32_t current_ms) {
    float threshold = detector.noise_floor * IMPULSE_THRESHOLD_MULTIPLIER;
    
    if (!detector.impulse_active) {
        if (rms_level > threshold) {
            detector.impulse_active = true;
            detector.impulse_start_ms = current_ms;
            detector.peak_level = rms_level;
            return false;  // Wait for impulse to end
        }
    } else {
        if (rms_level > detector.peak_level) {
            detector.peak_level = rms_level;
        }
        
        uint32_t duration = current_ms - detector.impulse_start_ms;
        
        if (rms_level < threshold || duration > IMPULSE_MAX_DURATION_MS) {
            detector.impulse_active = false;
            
            if (duration >= IMPULSE_MIN_DURATION_MS && 
                duration <= IMPULSE_MAX_DURATION_MS) {
                // Valid impulse detected
                printf("IMPULSE: duration=%lums, peak=%.2f\n", 
                       duration, detector.peak_level);
                return true;
            }
        }
    }
    return false;
}
```

### 5.4 Band Energy Analysis

```c
typedef struct {
    float low_band;      // 20 Hz - 300 Hz
    float mid_band;      // 300 Hz - 2 kHz
    float high_band;     // 2 kHz - 8 kHz
    float ultra_band;    // 8 kHz - 20 kHz
} BandEnergy;

BandEnergy compute_band_energy(float* fft_output, int fft_size, int sample_rate) {
    BandEnergy energy = {0};
    
    for (int i = 0; i < fft_size / 2; i++) {
        float freq = (float)i * sample_rate / fft_size;
        float mag_squared = fft_output[i] * fft_output[i];
        
        if (freq >= 20 && freq < 300) {
            energy.low_band += mag_squared;
        } else if (freq >= 300 && freq < 2000) {
            energy.mid_band += mag_squared;
        } else if (freq >= 2000 && freq < 8000) {
            energy.high_band += mag_squared;
        } else if (freq >= 8000 && freq < 20000) {
            energy.ultra_band += mag_squared;
        }
    }
    
    // Convert to dB
    energy.low_band = 10 * log10f(energy.low_band + 1e-10f);
    energy.mid_band = 10 * log10f(energy.mid_band + 1e-10f);
    energy.high_band = 10 * log10f(energy.high_band + 1e-10f);
    energy.ultra_band = 10 * log10f(energy.ultra_band + 1e-10f);
    
    return energy;
}
```

---

## 6. Machine Learning Audio Classification

### 6.1 Feature Extraction for ML

| Feature | Description | Calculation | Use Case |
|---------|-------------|-------------|----------|
| **MFCC** | Mel-frequency cepstral coefficients | DCT of log mel-filterbank | Speech, general audio |
| **Spectral Centroid** | Center of mass of spectrum | Weighted mean frequency | Brightness detection |
| **Spectral Rolloff** | Frequency below which 85% energy | Cumulative energy threshold | Distinguish harmonic/noise |
| **Zero-Crossing Rate** | Rate of sign changes | Count sign changes / samples | Percussion detection |
| **RMS Energy** | Root mean square amplitude | sqrt(mean(samples²)) | Loudness |
| **Chroma** | Pitch class distribution | Project to 12 semitones | Musical content |

### 6.2 TensorFlow Lite for ESP32

**Model Preparation** (on development machine):

```python
import tensorflow as tf

# Load trained model
model = tf.keras.models.load_model('gunshot_classifier.h5')

# Convert to TFLite with quantization
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.int8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_model = converter.convert()

with open('gunshot_classifier.tflite', 'wb') as f:
    f.write(tflite_model)

# Generate C header
os.system('xxd -i gunshot_classifier.tflite > gunshot_model.h')
```

**ESP32 Inference**:

```cpp
#include "tensorflow/lite/micro/all_ops_resolver.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "gunshot_model.h"

constexpr int kTensorArenaSize = 32 * 1024;
uint8_t tensor_arena[kTensorArenaSize];

tflite::MicroInterpreter* interpreter;
TfLiteTensor* input;
TfLiteTensor* output;

void setup_ml_model() {
    const tflite::Model* model = tflite::GetModel(gunshot_classifier_tflite);
    
    static tflite::AllOpsResolver resolver;
    static tflite::MicroInterpreter static_interpreter(
        model, resolver, tensor_arena, kTensorArenaSize);
    interpreter = &static_interpreter;
    
    interpreter->AllocateTensors();
    input = interpreter->input(0);
    output = interpreter->output(0);
}

float classify_audio(float* mfcc_features, int feature_count) {
    // Copy features to input tensor
    for (int i = 0; i < feature_count; i++) {
        input->data.int8[i] = (int8_t)(mfcc_features[i] * 127);
    }
    
    // Run inference
    interpreter->Invoke();
    
    // Get gunshot probability
    return (float)output->data.int8[0] / 127.0f;
}
```

### 6.3 Training Dataset Sources

| Dataset | Contents | Size | License |
|---------|----------|------|---------|
| **UrbanSound8K** | Urban sounds (10 classes) | 8,732 clips | Free for research |
| **Gunshot Audio Dataset** | Various firearms | ~1,000 clips | Research only |
| **ESC-50** | Environmental sounds (50 classes) | 2,000 clips | CC BY-NC |
| **AudioSet** | YouTube audio (632 classes) | 2M+ clips | CC BY 4.0 |

---

## 7. Python Audio Analysis Tools

### 7.1 Real-Time Audio Capture

```python
#!/usr/bin/env python3
"""Real-time audio analysis for acoustic surveillance detection"""

import numpy as np
import sounddevice as sd
from scipy import signal
from collections import deque

SAMPLE_RATE = 44100
BLOCK_SIZE = 1024
IMPULSE_THRESHOLD = 6.0  # Multiplier over noise floor

class AcousticMonitor:
    def __init__(self):
        self.noise_floor = 0.01
        self.noise_samples = deque(maxlen=100)
        self.impulse_count = 0
        
    def update_noise_floor(self, rms):
        self.noise_samples.append(rms)
        self.noise_floor = np.mean(self.noise_samples)
        
    def detect_impulse(self, audio_block):
        rms = np.sqrt(np.mean(audio_block ** 2))
        threshold = self.noise_floor * IMPULSE_THRESHOLD
        
        if rms < threshold * 0.5:
            self.update_noise_floor(rms)
        
        if rms > threshold:
            self.impulse_count += 1
            return True, rms
        return False, rms
    
    def compute_spectral_features(self, audio_block):
        # Compute FFT
        fft_result = np.fft.rfft(audio_block)
        magnitude = np.abs(fft_result)
        freqs = np.fft.rfftfreq(len(audio_block), 1/SAMPLE_RATE)
        
        # Spectral centroid
        centroid = np.sum(freqs * magnitude) / np.sum(magnitude)
        
        # Band energies
        low_band = np.sum(magnitude[(freqs >= 20) & (freqs < 300)] ** 2)
        mid_band = np.sum(magnitude[(freqs >= 300) & (freqs < 2000)] ** 2)
        high_band = np.sum(magnitude[(freqs >= 2000) & (freqs < 8000)] ** 2)
        
        return {
            'centroid': centroid,
            'low_band_db': 10 * np.log10(low_band + 1e-10),
            'mid_band_db': 10 * np.log10(mid_band + 1e-10),
            'high_band_db': 10 * np.log10(high_band + 1e-10),
        }

def audio_callback(indata, frames, time, status):
    global monitor
    audio = indata[:, 0]
    
    is_impulse, rms = monitor.detect_impulse(audio)
    
    if is_impulse:
        features = monitor.compute_spectral_features(audio)
        print(f"🔊 IMPULSE #{monitor.impulse_count}: "
              f"RMS={rms:.4f}, Centroid={features['centroid']:.0f}Hz")

if __name__ == "__main__":
    monitor = AcousticMonitor()
    
    print("Starting acoustic monitoring...")
    with sd.InputStream(callback=audio_callback, 
                        channels=1, 
                        samplerate=SAMPLE_RATE,
                        blocksize=BLOCK_SIZE):
        sd.sleep(60000)  # Run for 60 seconds
```

### 7.2 MFCC Extraction with Librosa

```python
import librosa
import numpy as np

def extract_mfcc_features(audio_file, n_mfcc=13):
    """Extract MFCC features for classification"""
    # Load audio
    y, sr = librosa.load(audio_file, sr=44100)
    
    # Compute MFCCs
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=n_mfcc)
    
    # Compute delta and delta-delta
    mfcc_delta = librosa.feature.delta(mfccs)
    mfcc_delta2 = librosa.feature.delta(mfccs, order=2)
    
    # Stack all features
    features = np.vstack([mfccs, mfcc_delta, mfcc_delta2])
    
    # Return mean and std across time
    return np.concatenate([features.mean(axis=1), features.std(axis=1)])

def classify_gunshot(audio_file, model):
    """Classify if audio contains a gunshot"""
    features = extract_mfcc_features(audio_file)
    features = features.reshape(1, -1)
    
    probability = model.predict_proba(features)[0, 1]
    return probability > 0.5, probability
```

### 7.3 Spectral Analysis Visualization

```python
import matplotlib.pyplot as plt
import librosa.display

def plot_audio_analysis(audio_file, output_file='analysis.png'):
    y, sr = librosa.load(audio_file, sr=44100)
    
    fig, axes = plt.subplots(4, 1, figsize=(12, 10))
    
    # Waveform
    librosa.display.waveshow(y, sr=sr, ax=axes[0])
    axes[0].set_title('Waveform')
    
    # Spectrogram
    D = librosa.amplitude_to_db(np.abs(librosa.stft(y)), ref=np.max)
    librosa.display.specshow(D, sr=sr, x_axis='time', y_axis='hz', ax=axes[1])
    axes[1].set_title('Spectrogram')
    
    # Mel spectrogram
    M = librosa.feature.melspectrogram(y=y, sr=sr)
    librosa.display.specshow(librosa.power_to_db(M, ref=np.max),
                             sr=sr, x_axis='time', y_axis='mel', ax=axes[2])
    axes[2].set_title('Mel Spectrogram')
    
    # MFCCs
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    librosa.display.specshow(mfccs, sr=sr, x_axis='time', ax=axes[3])
    axes[3].set_title('MFCCs')
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150)
    plt.close()
```

---

## 8. Detection Signatures & Patterns

### 8.1 Acoustic Event Classification

| Event Type | Duration | Frequency Profile | Classification Confidence |
|------------|----------|-------------------|-------------------------|
| **Gunshot** | 1-10 ms impulse | Wideband, high energy 1-6 kHz | High (with training) |
| **Firework** | 10-100 ms | Irregular, multiple impulses | Medium (similar to gunshot) |
| **Car backfire** | 50-200 ms | Low frequency dominant (<1 kHz) | High |
| **Door slam** | 50-150 ms | Resonant, <500 Hz | High |
| **Glass break** | 20-100 ms | High frequency (2-8 kHz) | High |
| **Construction** | Variable | Repetitive pattern | Medium |

### 8.2 Ultrasonic Beacon Detection

Some surveillance systems use **ultrasonic beacons** (18-22 kHz) for cross-device tracking:

```python
def detect_ultrasonic_beacon(audio, sr=44100):
    """Detect ultrasonic beacons in the 18-22 kHz range"""
    # Bandpass filter for ultrasonic range
    nyquist = sr / 2
    low = 17000 / nyquist
    high = 22000 / nyquist
    b, a = signal.butter(4, [low, high], btype='band')
    filtered = signal.filtfilt(b, a, audio)
    
    # Compute energy in ultrasonic band
    energy = np.mean(filtered ** 2)
    
    # FFT for frequency analysis
    fft_result = np.fft.rfft(filtered)
    freqs = np.fft.rfftfreq(len(filtered), 1/sr)
    magnitude = np.abs(fft_result)
    
    # Find peak frequency
    ultrasonic_mask = (freqs >= 17000) & (freqs <= 22000)
    if np.any(ultrasonic_mask):
        peak_idx = np.argmax(magnitude[ultrasonic_mask])
        peak_freq = freqs[ultrasonic_mask][peak_idx]
        peak_mag = magnitude[ultrasonic_mask][peak_idx]
        
        return {
            'detected': energy > 1e-6,
            'peak_frequency': peak_freq,
            'peak_magnitude': peak_mag,
            'energy': energy
        }
    return {'detected': False}
```

---

## 9. Counter-Acoustic Surveillance

### 9.1 White Noise Generation

```python
import numpy as np
import sounddevice as sd

def generate_masking_noise(duration_seconds=60, volume=0.3):
    """Generate pink noise for acoustic masking"""
    sr = 44100
    samples = int(sr * duration_seconds)
    
    # Generate white noise
    white = np.random.randn(samples)
    
    # Convert to pink noise (1/f spectrum)
    # Simple approximation using IIR filter
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    pink = signal.lfilter(b, a, white)
    
    # Normalize and apply volume
    pink = pink / np.max(np.abs(pink)) * volume
    
    # Play audio
    sd.play(pink, sr)
    sd.wait()

def audio_jamming_pulse(frequency=2000, duration_ms=50, interval_ms=500):
    """Generate periodic jamming pulses"""
    sr = 44100
    t = np.linspace(0, duration_ms/1000, int(sr * duration_ms/1000))
    pulse = np.sin(2 * np.pi * frequency * t)
    
    # Apply envelope
    envelope = np.hanning(len(pulse))
    pulse = pulse * envelope
    
    while True:
        sd.play(pulse, sr)
        sd.wait()
        time.sleep(interval_ms / 1000)
```

### 9.2 Acoustic Anomaly Detection for Counter-Surveillance

```python
def detect_acoustic_anomaly(audio_stream, baseline_minutes=5):
    """Detect unusual acoustic activity that might indicate surveillance"""
    from sklearn.ensemble import IsolationForest
    
    # Collect baseline features
    baseline_features = []
    print(f"Collecting {baseline_minutes} minutes of baseline audio...")
    
    # Feature extraction loop (simplified)
    for _ in range(baseline_minutes * 60):
        block = audio_stream.read(1024)
        features = extract_spectral_features(block)
        baseline_features.append(features)
        time.sleep(1)
    
    # Train anomaly detector
    clf = IsolationForest(contamination=0.05, random_state=42)
    clf.fit(np.array(baseline_features))
    
    print("Monitoring for anomalies...")
    while True:
        block = audio_stream.read(1024)
        features = extract_spectral_features(block).reshape(1, -1)
        
        score = clf.decision_function(features)[0]
        if score < -0.5:
            print(f"⚠️ ACOUSTIC ANOMALY DETECTED (score: {score:.2f})")
        
        time.sleep(0.1)
```

---

## 10. Code Patterns & Best Practices

### 10.1 Audio Buffer Management (JPL Rule Compliance)

```c
#define AUDIO_BUFFER_SIZE 4096
#define AUDIO_BUFFER_COUNT 4
#define MAX_PROCESS_ITERATIONS 1000

typedef struct {
    int32_t samples[AUDIO_BUFFER_SIZE];
    volatile bool ready;
    volatile bool processing;
} AudioBuffer;

static AudioBuffer audio_buffers[AUDIO_BUFFER_COUNT];
static volatile int write_index = 0;
static volatile int read_index = 0;

// ISR-safe buffer write
void IRAM_ATTR audio_dma_callback(int32_t* data, size_t len) {
    AudioBuffer* buf = &audio_buffers[write_index];
    
    if (!buf->processing) {
        size_t copy_len = (len < AUDIO_BUFFER_SIZE) ? len : AUDIO_BUFFER_SIZE;
        memcpy(buf->samples, data, copy_len * sizeof(int32_t));
        buf->ready = true;
        write_index = (write_index + 1) % AUDIO_BUFFER_COUNT;
    }
}

// Main loop processing with bounded iterations
void process_audio_buffers(void) {
    int iterations = 0;
    
    while (iterations < MAX_PROCESS_ITERATIONS) {
        AudioBuffer* buf = &audio_buffers[read_index];
        
        if (!buf->ready) {
            break;  // No data available
        }
        
        buf->processing = true;
        
        // Process audio...
        detect_impulse(buf->samples, AUDIO_BUFFER_SIZE);
        
        buf->ready = false;
        buf->processing = false;
        read_index = (read_index + 1) % AUDIO_BUFFER_COUNT;
        iterations++;
    }
}
```

### 10.2 Impulse Event Logging

```c
#define MAX_EVENTS 100
#define EVENT_COOLDOWN_MS 1000

typedef struct {
    uint32_t timestamp_ms;
    float peak_amplitude;
    float centroid_hz;
    float duration_ms;
    char classification[32];
} ImpulseEvent;

static ImpulseEvent event_log[MAX_EVENTS];
static int event_count = 0;
static uint32_t last_event_time = 0;

bool log_impulse_event(float peak, float centroid, float duration, const char* classification) {
    uint32_t now = millis();
    
    // Rate limiting
    if (now - last_event_time < EVENT_COOLDOWN_MS) {
        return false;
    }
    
    if (event_count >= MAX_EVENTS) {
        // Shift events (FIFO)
        memmove(&event_log[0], &event_log[1], (MAX_EVENTS - 1) * sizeof(ImpulseEvent));
        event_count = MAX_EVENTS - 1;
    }
    
    ImpulseEvent* event = &event_log[event_count];
    event->timestamp_ms = now;
    event->peak_amplitude = peak;
    event->centroid_hz = centroid;
    event->duration_ms = duration;
    strncpy(event->classification, classification, 31);
    event->classification[31] = '\0';
    
    event_count++;
    last_event_time = now;
    
    return true;
}
```

---

## Quick Reference Card

### Key Frequencies

| Target | Frequency Range |
|--------|-----------------|
| Gunshot impulse | 500 Hz - 6 kHz |
| Ultrasonic beacon | 18 - 22 kHz |
| Voice band | 300 Hz - 3.4 kHz |
| Infrasound | 0.1 - 20 Hz |

### ESP32 Audio Pins (INMP441)

| INMP441 Pin | ESP32-S3 GPIO |
|-------------|---------------|
| SD (Data) | GPIO 4 |
| WS (LRCLK) | GPIO 5 |
| SCK (BCLK) | GPIO 6 |

### Python Audio Libraries

| Library | Purpose | Install |
|---------|---------|---------|
| sounddevice | Real-time I/O | `pip install sounddevice` |
| librosa | Feature extraction | `pip install librosa` |
| scipy.signal | DSP filters | `pip install scipy` |
| numpy | Array operations | `pip install numpy` |

### Detection Thresholds

| Metric | Typical Value | Adjustment |
|--------|---------------|------------|
| Impulse threshold | 6× noise floor | Increase for noisy environments |
| Impulse duration | 1-50 ms | Gunshot: 1-10 ms |
| Ultrasonic energy | >1e-6 | Lower for weak beacons |

---

## Resources & References

### Hardware

- **INMP441 Datasheet**: InvenSense I2S MEMS microphone
- **ESP32-S3 I2S Reference**: Espressif ESP-IDF I2S driver
- **SPH0645 Datasheet**: Knowles PDM MEMS microphone

### Software

- **ESP-DSP Library**: https://github.com/espressif/esp-dsp
- **TensorFlow Lite Micro**: https://www.tensorflow.org/lite/microcontrollers
- **Librosa Documentation**: https://librosa.org
- **sounddevice**: https://python-sounddevice.readthedocs.io

### Datasets

- **UrbanSound8K**: https://urbansounddataset.weebly.com
- **ESC-50**: https://github.com/karolpiczak/ESC-50
- **AudioSet**: https://research.google.com/audioset/

### Research

- ShotSpotter accuracy studies (Electronic Frontier Foundation)
- "Acoustic Gunshot Detection" - IEEE Signal Processing Magazine
- MFCC extraction for audio classification papers

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of ainish-coder signals detection suite*
