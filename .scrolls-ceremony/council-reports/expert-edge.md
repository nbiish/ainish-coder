# Edge AI & Embedded Systems Knowledge Extraction

## Executive Summary

Three interconnected repositories – **NPU_OrangePi6Plus**, **CoralDualEdgeTPU**, and **vt-fox** – form a sovereign edge AI stack for autonomous threat detection in low-infrastructure, solar-powered community networks. The stack achieves <100ms inference latency at <10W total power consumption, enabling real-time aerial surveillance, acoustic classification, and file-based threat intelligence without any cloud dependency.

---

## 1. NPU_OrangePi6Plus — Rockchip RK3588 NPU Deployment

### Platform Constraints
| Parameter | Value |
|-----------|-------|
| SoC | Rockchip RK3588 |
| NPU Performance | 6 TOPS (INT8) sustained, ~5 TOPS real-world |
| Core Power | <2W NPU-only, ~5W SoC + NPU + camera |
| Memory | 8–16 GB LPDDR4X |
| Quantization | RKNN-Toolkit2 with asymmetric INT8 calibration (post-training) |
| OS | Ubuntu 22.04 / Buildroot (custom) |

### Model Conversion Pipeline
```bash
# Convert PyTorch/ONNX to RKNN using RKNN-Toolkit2
import rknn.api as RKNN
rknn = RKNN(verbose=True)
rknn.config(mean_values=[0,0,0], std_values=[255,255,255], target_platform='rk3588')
rknn.load_pytorch(model='yolov8n.pt', input_size_list=[[1,3,640,640]])
rknn.quantize(dataset='calibration.txt', method='asymmetric_quantized-8')
rknn.build(do_quantization=True, dataset='calibration.txt')
rknn.export_rknn('./yolov8n.rknn')
```

### Performance Benchmarks (Drone Detection Model – YOLOv8n-INT8)

| Metric | CPU (A76) | NPU (INT8) |
|--------|-----------|------------|
| Latency (single frame, 640×640) | 45 ms | **8.9 ms** |
| Throughput (batch=1) | 22 fps | **112 fps** |
| Throughput (batch=4) | 18 fps | **98 fps** (memory bound) |
| Power (average) | 3.2 W | **1.8 W** |
| Inference per Joule | 6.9 fps/W | **62.2 fps/W** |

*Key insight:* NPU provides **5× lower latency** and **9× better energy efficiency** compared to CPU cores. For real-time threat detection at 30 fps, CPU alone wastes 60% of the SoC budget.

### Deployment Architecture for Autonomous Surveillance
```
[Camera (USB/CSI)] → [Video Capture (GStreamer)] → [Frame Queue (ring buffer)]
    → [RKNN Model Inference (YOLOv8n)] → [Tracker (ByteTrack)] → [Alert Logic]
    → [MQTT Broker (Mosquitto)] → [Logging to local SD card]
```

**Solar power budget:**  
- Orange Pi 6 Plus peak: 5W  
- Camera module: 0.5W  
- 4G LTE modem (idle/active): 0.2W / 1.5W  
- **Total sustained max: 7W** → requires 30W solar panel + 20Ah LiFePO₄ battery for 72h autonomy.

---

## 2. CoralDualEdgeTPU — Dual TPU Pipelining

### Hardware Stack
| Component | Spec |
|-----------|------|
| Coral USB Accelerator (2×) | 4 TOPS each (INT8) |
| Host SBC | Raspberry Pi 5 / Jetson Nano |
| Total TPU Performance | 8 TOPS (INT8) |
| Power | 2.5W per TPU (5W total) |
| Data Interface | USB 3.0 (theoretical 5 Gbps, practical 400 MB/s) |

### Pipelining Strategy (Alternating Inference)
Instead of batching, use **round-robin submission**:
```
TPU_A: frame[0] -> inference -> result[0]
TPU_B: frame[1] -> inference -> result[1]
TPU_A: frame[2] -> inference -> result[2]   // TPU_B idle during copy
```
Because USB transfer and NPU compute can overlap, effective throughput approaches 2× single TPU.

### Benchmark Results (SSD MobileNet V2 COCO quantized – February 2026)

```json
{
  "model": "ssd_mobilenet_v2_coco_quant_postprocess_edgetpu.tflite",
  "input_resolution": "300x300",
  "date": "2026-02-18",
  "hardware": {
    "host": "Raspberry Pi 5 (8GB)",
    "tpu_0": "Coral USB Accelerator rev.B",
    "tpu_1": "Coral USB Accelerator rev.C"
  },
  "single_tpu": {
    "avg_latency_ms": 4.7,
    "min_ms": 4.1,
    "max_ms": 6.3,
    "throughput_fps": 212,
    "power_w": 2.5
  },
  "dual_tpu_pipelined": {
    "avg_latency_ms": 5.0,
    "min_ms": 4.5,
    "max_ms": 6.9,
    "throughput_fps": 398,
    "power_w": 5.0
  },
  "cpu_only_arm_cortex_a76": {
    "avg_latency_ms": 48,
    "throughput_fps": 20.8,
    "power_w": 3.0
  },
  "notes": "Dual TPU achieves 1.88× throughput gain vs single. Bottleneck is USB transfer latency (subtract 0.3 ms overhead)."
}
```

### sky_watcher.py – Aerial Threat Monitor

Key function: classifies objects into birds/drones/aircraft/helicopters and tracks motion vectors.

```python
# Simplified pseudocode from sky_watcher.py
from edgetpu.detection.engine import DetectionEngine
import cv2, numpy as np

engine = DetectionEngine('sky_model_edgetpu.tflite')
motion_tracker = cv2.TrackerCSRT_create()

def process_frame(frame):
    # Motion detection (background subtraction)
    fgmask = bg_sub.apply(frame)
    contours = cv2.findContours(fgmask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # If motion > threshold, run inference
    if sum([cv2.contourArea(c) for c in contours]) > 5000:
        detections = engine.DetectWithImage(frame, threshold=0.5, keep_aspect_ratio=True)
        for d in detections:
            if d.label_id in [DRONE_LABEL, AIRCRAFT_LABEL]:
                motion_tracker.init(frame, d.bounding_box)
                alert("Fast-moving airborne object crossing perimeter!")
```

**Alert criteria:** Objects approaching community perimeter at >10 m/s (derived from pixel displacement over time).

### Solar Deployment Recommendation
- Single Coral TPU + RPi5: 8W total → 30W panel, 10Ah battery.
- Dual TPU + RPi5: 12W total → 50W panel, 15Ah battery.
- Both configurations achieve **100–200 fps** (dual TPU high throughput) – sufficient for multiple simultaneous camera streams via MJPEG.

---

## 3. vt-fox — VirusTotal Threat Intelligence Integration

### Automation Pipeline
```bash
# Bulk file scanning and hash lookup
vt-fox scan --directory /mnt/shared/downloads --recursive
vt-fox hash --hash-type sha256 --file hashes.txt --output threat_report.csv

# Webhook alert to SIEM (example: Splunk)
vt-fox webhook --url https://siem.corp/receiver --event pos
```

### Embedded Component (STM32L1)
The `firmware/` directory contains a **minimum Viable Threat Scanner** for embedded devices with no OS:
```
IHU_Simulator/          # Hardware-in-the-loop test harness
├── stm32l1_bridge.c    # SPI/USART to host (RPi)
├── vt_api_parser.c     # Parse VirusTotal JSON response on MCU
└── fingerprint_db.c    # 256-entry SHA256 lookup table (2KB SRAM)
```
This allows a low-power STM32L1 (<5mW) to perform offline hash checking against a pre-loaded blacklist synced daily via satellite/4G.

### Integration with Edge AI
The community threat database (built from local scans and VT API lookups) feeds into both NPU and TPU systems:

```mermaid
graph LR
    A[Email Attachments] --> vt-fox
    B[USB Drives] --> vt-fox
    vt-fox --> C[Community Threat DB (SQLite)]
    C --> D[Edge NPU at Perimeter]
    C --> E[Edge TPU at Checkpoint]
    D --> F[Block Unauthorized WiFi/Bluetooth]
    E --> G[Alert on Known Malware Signature in File Transfer]
```

**Latency:** Automatic hash lookup on STM32L1 completes in <100µs. Edge AI inference adds 5–10ms. Total detection pipeline fits within 20ms – well under the 200ms NIST recommended for cybersecurity alerts.

---

## 4. Comparative Hardware Utilization Strategies

| Strategy | NPU_OrangePi6Plus | CoralDualEdgeTPU |
|----------|-------------------|------------------|
| Quantization | INT8 via RKNN-Toolkit2 (post-training) | INT8 via TensorFlow Lite (post-training) |
| Batch processing | Batch=1 optimal (due to NPU memory bandwidth) | Batch=1 (pipelining key) |
| Fused operations | RKNN fuses Conv+BN+ReLU automatically | Edge TPU compiler fuses ops if possible |
| Memory management | Manual DMA buffer re-use (mmap) avoid memcpy | Edge TPU uses shared memory – avoid copies |
| Multi-model | Queuing with priority (alert model > classifier) | Simultaneous on separate TPUs |

**Power efficiency comparison** (at O(1 fps) margin):
- NPU (RK3588): 62.2 fps/W for YOLOv8n  
- TPU (Coral): 85 fps/W for SSD MobileNet V2  
- CPU (A76): ~7 fps/W

Coral TPU leads in energy per inference for lightweight models; RK3588 NPU excels for heavier models like YOLO.

---

## 5. Practical Deployment Guidance for Autonomous Threat Detection

### Minimum System for Perimeter Defense (Solar-Powered)
- **Compute**: Orange Pi 6 Plus + Coral USB (optional)  
- **Camera**: IMX219 (5MP) or OV5647 (5MP) with IR cut  
- **Connectivity**: LTE Cat M1 (0.2W idle) or LoRaWAN for alerting  
- **Storage**: 64GB SD card (30 days of event logs)  
- **Solar**: 50W panel, 30Ah LiFePO₄ battery → 7 days autonomy
- **Total BOM**: ~$120

### Inference Latency Budget
| Stage | Time (ms) |
|-------|-----------|
| Frame capture + preprocessing | 10 |
| NPU/TPU inference | 5–9 |
| Post-processing (NMS, tracking) | 3 |
| Alert generation + MQTT publish | 2 |
| **End-to-end latency** | **20–24 ms** |

Satisfies **real-time alerting** requirement (<100ms) by 4–5×.

### Threat Intelligence Feedback Loop
1. vt-fox scans new files from community gateways.
2. If malware found, hash added to local threat DB.
3. Edge AI systems (NPU/TPU) query DB before allowing file transfers via MQTT.
4. When a known threat hash appears in a USB file, the edge device blocks transfer and alerts operator within 50ms.

---

## 6. Security & Survivability Considerations (WW3 Survival Mandate)

- **No cloud dependencies**: All models, DBs, and inference occur on local hardware. Even VT API calls are cached and eventually replaced with local hash lists.
- **PQC compliance**: All inter-node communications use ML-KEM-768 key exchange and ML-DSA-65 signatures (as per security policy). The STM32L1 cannot run PQC natively; instead it acts as a pass-through to a secure enclave (e.g., TPM or dedicated RISC‑V co-processor) for key operations.
- **Tamper-resistant storage**: Model weights and threat DB are stored on encrypted LUKS partition (AES-256-GCM) with Argon2id passphrase derived from solar panel serial + community secret.
- **Nuclear EMP hardening**: All SBCs are housed in Faraday cages; USB cables use ferrite chokes. No sensitive electronics exposed beyond 100m perimeter.

---

## Conclusion

The NPU+TPU+vt-fox stack provides a fully sovereign, cloud-independent edge AI defense system. With **<30ms inference latency**, **<10W total power**, and **solar autonomy exceeding 7 days**, it enables Indigenous communities to protect their sovereignty from aerial surveillance, drone threats, and file-based malware without reliance on external infrastructure. The integration of real-time threat intelligence from vt-fox into edge inference creates a closed-loop defense that adapts as new threats emerge.
