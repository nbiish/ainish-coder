# Signals Security Image and Video: Expert Technical Reference

> **Beyond Expert-Level Guide to Security Camera Image Capture, Streaming, and Visual Processing**
>
> Part of the **espi-watching-you** project — a multi-camera security system built on XIAO ESP32-S3 Sense boards streaming to a Raspberry Pi dashboard.
>
> This document covers the image and video side of the system: OV2640 sensor configuration, JPEG compression, MJPEG streaming, HTTP transport, NGINX proxying, dashboard rendering, and future directions for on-device and server-side visual processing.
>
> **Companion document**: [Signals Detection](signals.md) — covers RF signal detection, WiFi/BLE scanning, device fingerprinting, and channel/signal analysis.

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [OV2640 Image Sensor](#2-ov2640-image-sensor)
3. [JPEG Compression on ESP32-S3](#3-jpeg-compression-on-esp32-s3)
4. [HTTP Image Transport](#4-http-image-transport)
5. [MJPEG Streaming Protocol](#5-mjpeg-streaming-protocol)
6. [NGINX Reverse Proxy for Video](#6-nginx-reverse-proxy-for-video)
7. [Dashboard Image Rendering](#7-dashboard-image-rendering)
8. [PSRAM Memory Architecture](#8-psram-memory-architecture)
9. [Image Quality Tuning](#9-image-quality-tuning)
10. [Thermal Management](#10-thermal-management)
11. [Multi-Camera Scaling](#11-multi-camera-scaling)
12. [Future: On-Device Image Processing](#12-future-on-device-image-processing)
13. [Future: Server-Side Video Processing](#13-future-server-side-video-processing)
14. [Security Considerations](#14-security-considerations)

---

## 1. System Architecture

### 1.1 Image Pipeline Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Image Pipeline                                │
│                                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐   │
│  │ OV2640   │───►│ ESP32-S3 │───►│  WiFi    │───►│ NGINX Proxy  │   │
│  │ Sensor   │    │ JPEG Enc │    │ HTTP/1.1 │    │ TLS + Auth   │   │
│  │ 800x600  │    │ PSRAM FB │    │ /capture │    │ /camN/capture│   │
│  └──────────┘    └──────────┘    └──────────┘    └──────┬───────┘   │
│                                                         │           │
│                                                  ┌──────▼───────┐   │
│                                                  │  Dashboard   │   │
│                                                  │  <img> poll  │   │
│                                                  │  every 3s    │   │
│                                                  └──────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow Per Frame

| Stage | Format | Size | Latency |
|-------|--------|------|---------|
| Sensor capture | Raw Bayer | ~960 KB (SVGA) | ~40ms |
| JPEG encode (hardware) | JPEG | 20-40 KB (q=10) | ~15ms |
| PSRAM buffer | JPEG in PSRAM | 20-40 KB | <1ms |
| HTTP response | `image/jpeg` | 20-40 KB | ~5ms |
| WiFi transmit | TCP/IP | 20-40 KB | ~10ms |
| NGINX proxy | Pass-through | 20-40 KB | ~2ms |
| Browser render | Decoded bitmap | ~1.4 MB (800x600x3) | ~5ms |

**Total end-to-end latency**: ~80ms per frame (theoretical), ~200ms observed with WiFi overhead.

### 1.3 Bandwidth Budget

| Cameras | Resolution | Quality | Frame Rate | Bandwidth |
|---------|-----------|---------|------------|-----------|
| 1 | SVGA 800x600 | q=10 | 0.33 fps (3s poll) | ~80 Kbps |
| 4 | SVGA 800x600 | q=10 | 0.33 fps each | ~320 Kbps |
| 8 | SVGA 800x600 | q=10 | 0.33 fps each | ~640 Kbps |
| 1 | SVGA 800x600 | q=10 | 15 fps (MJPEG) | ~4.8 Mbps |
| 4 | SVGA 800x600 | q=10 | 15 fps (MJPEG) | ~19 Mbps |

**Polling at 3s intervals** keeps bandwidth extremely low — ideal for multi-camera setups on a shared home network.

---

## 2. OV2640 Image Sensor

### 2.1 Sensor Specifications

| Property | Value |
|----------|-------|
| **Manufacturer** | OmniVision |
| **Max Resolution** | UXGA 1600x1200 (2 megapixel) |
| **Pixel Size** | 2.2 µm x 2.2 µm |
| **Lens** | Fixed focus, ~120° FOV (XIAO module) |
| **Interface** | 8-bit parallel DVP |
| **Output Formats** | JPEG, YUV422, RGB565, Grayscale |
| **Max Frame Rate** | 15 fps @ UXGA, 30 fps @ SVGA, 60 fps @ CIF |
| **Dynamic Range** | 50 dB |
| **SNR** | 40 dB |
| **Operating Temp** | -30°C to 70°C |

### 2.2 Resolution Ladder

| Frame Size | Pixels | Aspect | Sensor FPS | WiFi FPS | JPEG Size (q=10) | Use Case |
|-----------|--------|--------|------------|----------|-------------------|----------|
| QQVGA | 160x120 | 4:3 | 60 | 45 | 2-4 KB | Motion detect thumbnails |
| QVGA | 320x240 | 4:3 | 60 | 40 | 5-10 KB | Low-bandwidth streaming |
| CIF | 352x288 | ~4:3 | 60 | 40 | 6-12 KB | Legacy compatibility |
| VGA | 640x480 | 4:3 | 30 | 20 | 12-25 KB | Good balance |
| **SVGA** | **800x600** | **4:3** | **30** | **15-20** | **20-40 KB** | **Surveillance optimal** |
| XGA | 1024x768 | 4:3 | 15 | 5-7 | 40-80 KB | High-quality stills |
| SXGA | 1280x1024 | 5:4 | 15 | 3-5 | 60-120 KB | Stills only |
| UXGA | 1600x1200 | 4:3 | 15 | 2-3 | 80-150 KB | Max resolution stills |

### 2.3 Sensor Control Registers

The OV2640 exposes control registers via SCCB (I2C-like protocol). ESP-IDF wraps these in the `sensor_t` struct:

```c
sensor_t *sensor = esp_camera_sensor_get();

// Exposure & Gain
sensor->set_exposure_ctrl(sensor, 1);     // Auto exposure
sensor->set_aec2(sensor, 1);             // Auto exposure (DSP level)
sensor->set_ae_level(sensor, 0);         // -2 to +2 exposure compensation
sensor->set_gain_ctrl(sensor, 1);        // Auto gain
sensor->set_agc_gain(sensor, 0);         // Manual gain (0-30)

// White Balance
sensor->set_whitebal(sensor, 1);         // Auto white balance
sensor->set_awb_gain(sensor, 1);         // AWB gain enable
sensor->set_wb_mode(sensor, 0);          // 0=Auto, 1=Sunny, 2=Cloudy, 3=Office, 4=Home

// Image Processing
sensor->set_brightness(sensor, 0);       // -2 to +2
sensor->set_contrast(sensor, 0);         // -2 to +2
sensor->set_saturation(sensor, 0);       // -2 to +2
sensor->set_sharpness(sensor, 0);        // -2 to +2 (not all sensors)

// Lens Correction
sensor->set_lenc(sensor, 1);             // Lens correction enable
sensor->set_raw_gma(sensor, 1);          // Gamma correction
sensor->set_bpc(sensor, 1);             // Black pixel correction
sensor->set_wpc(sensor, 1);             // White pixel correction

// Special Effects
sensor->set_special_effect(sensor, 0);   // 0=None, 1=Negative, 2=Grayscale, 3=RedTint...
sensor->set_hmirror(sensor, 0);          // Horizontal mirror
sensor->set_vflip(sensor, 0);           // Vertical flip

// Resolution (runtime change)
sensor->set_framesize(sensor, FRAMESIZE_SVGA);
```

### 2.4 Night Vision Considerations

The OV2640 on the XIAO ESP32-S3 Sense has **no IR filter** and **no IR LEDs**:

| Condition | Quality | Notes |
|-----------|---------|-------|
| Daylight | Excellent | Full color, good detail |
| Indoor lighting | Good | May need `ae_level` adjustment |
| Low light | Poor | High noise, slow shutter, motion blur |
| Complete darkness | None | No IR illumination available |

**Improving low-light performance**:
```c
sensor->set_agc_gain(sensor, 30);        // Max analog gain
sensor->set_ae_level(sensor, 2);         // Max exposure compensation
sensor->set_aec_value(sensor, 1200);     // Long exposure (causes motion blur)
```

For true night vision, an external IR LED array (850nm or 940nm) and an IR-pass filter would be needed.

---

## 3. JPEG Compression on ESP32-S3

### 3.1 Hardware JPEG Encoder

The ESP32-S3's camera interface includes a **hardware JPEG encoder** that compresses frames in real-time as they arrive from the sensor. This is not software compression — it happens in the DMA pipeline.

```
OV2640 (DVP) ──► DMA ──► JPEG Encoder ──► PSRAM Frame Buffer
                          (hardware)        (ready to serve)
```

### 3.2 Quality Parameter

The `jpeg_quality` parameter (0-63) controls the JPEG quantization table:

| Quality Value | Compression | File Size (SVGA) | Visual Quality | Streaming FPS |
|--------------|-------------|-------------------|----------------|---------------|
| 4 | Minimal | 80-120 KB | Near-lossless | 5-8 |
| 8 | Low | 40-70 KB | Excellent | 10-15 |
| **10** | **Moderate** | **20-40 KB** | **Very good** | **15-20** |
| 12 | Medium | 15-30 KB | Good | 18-22 |
| 20 | High | 8-15 KB | Acceptable | 22-25 |
| 40 | Very high | 4-8 KB | Visible artifacts | 25-30 |
| 63 | Maximum | 2-5 KB | Poor | 30+ |

**Current setting**: `jpeg_quality = 10` — best balance of quality and bandwidth for surveillance.

### 3.3 JPEG Structure

Each captured frame is a standard JFIF JPEG:

```
┌────────────┬──────────────┬────────────┬──────────────┬─────────┐
│ SOI Marker │ JFIF Header  │ Quant Tbls │ Huffman Tbls │ Scan    │
│ FF D8      │ APP0         │ DQT        │ DHT          │ SOS+ECS │
│ 2 bytes    │ ~18 bytes    │ ~130 bytes │ ~420 bytes   │ Payload │
└────────────┴──────────────┴────────────┴──────────────┴─────────┘
```

**Validation** (from firmware test capture):
```
file /tmp/test.jpg
/tmp/test.jpg: JPEG image data, JFIF standard 1.01, resolution (DPI),
density 0x0, segment length 16, baseline, precision 8, 800x600, components 3
```

---

## 4. HTTP Image Transport

### 4.1 Capture Endpoint (`GET /capture`)

Returns a single JPEG frame. Used by the dashboard for polling.

**Request**:
```http
GET /capture?t=1707245400000 HTTP/1.1
Host: 192.168.1.65
```

**Response**:
```http
HTTP/1.1 200 OK
Content-Type: image/jpeg
Content-Length: 28154
Cache-Control: no-cache, no-store

<JPEG binary data>
```

**Implementation** (`firmware/src/main.cpp`):
```c
void handleCapture(void) {
    esp_task_wdt_reset();
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
        server.send(500, "text/plain", "capture failed");
        return;
    }
    frameCount++;
    server.sendHeader("Cache-Control", "no-cache, no-store");
    server.send_P(200, "image/jpeg", (const char *)fb->buf, fb->len);
    esp_camera_fb_return(fb);
}
```

### 4.2 Health Endpoint (`GET /health`)

Returns JSON with camera status, WiFi signal, memory, and frame count.

**Response**:
```json
{
    "status": "healthy",
    "camera": "cam1",
    "ip": "192.168.1.65",
    "rssi": -26,
    "uptime": 3600,
    "frames": 1200,
    "heap": 259076,
    "psram": 7602747
}
```

### 4.3 Root Endpoint (`GET /`)

Self-contained HTML page with auto-refreshing `<img>` tag. Useful for direct browser access to individual cameras without the Pi dashboard.

```html
<img id="cam" src="/capture">
<script>
setInterval(() => {
    document.getElementById('cam').src = '/capture?t=' + Date.now();
}, 3000);
</script>
```

---

## 5. MJPEG Streaming Protocol

### 5.1 Protocol Overview

MJPEG (Motion JPEG) streams individual JPEG frames as a multipart HTTP response. Each frame is a complete JPEG image separated by a boundary string.

```
HTTP/1.1 200 OK
Content-Type: multipart/x-mixed-replace; boundary=frame

--frame
Content-Type: image/jpeg
Content-Length: 28154

<JPEG data for frame 1>
--frame
Content-Type: image/jpeg
Content-Length: 27890

<JPEG data for frame 2>
...
```

### 5.2 Implementation (`GET /stream`)

```c
void handleStream(void) {
    WiFiClient client = server.client();
    if (!client.connected()) return;

    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: multipart/x-mixed-replace; boundary=frame");
    client.println("Cache-Control: no-cache, no-store");
    client.println("Connection: close");
    client.println();

    while (client.connected()) {
        esp_task_wdt_reset();
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) { delay(100); continue; }

        client.printf("--frame\r\n"
                      "Content-Type: image/jpeg\r\n"
                      "Content-Length: %u\r\n\r\n", fb->len);
        client.write(fb->buf, fb->len);
        client.println();

        esp_camera_fb_return(fb);
        delay(CAPTURE_INTERVAL_MS);
    }
}
```

### 5.3 MJPEG vs Capture Polling

| Method | Latency | Bandwidth | Proxy Compatible | Browser Support | Current Use |
|--------|---------|-----------|------------------|-----------------|-------------|
| **MJPEG `/stream`** | Real-time | High (~5 Mbps) | Breaks through NGINX | Native `<img>` | Direct access only |
| **Polling `/capture`** | 3s intervals | Low (~80 Kbps) | Works through NGINX | Native `<img>` | **Dashboard (current)** |

**Why polling was chosen**: MJPEG multipart boundary headers get corrupted when proxied through NGINX reverse proxy. Polling `/capture` every 3 seconds is simpler, reliable through proxies, and uses far less bandwidth for multi-camera setups.

### 5.4 Direct MJPEG Access

For real-time viewing without the proxy, connect directly to the camera:

```
http://192.168.1.65/stream
```

This bypasses NGINX and delivers full-framerate MJPEG. Useful for debugging or single-camera monitoring.

---

## 6. NGINX Reverse Proxy for Video

### 6.1 Proxy Configuration

Each camera gets an upstream and location block in `/etc/nginx/sites-available/cameras`:

```nginx
upstream cam1 {
    server 192.168.1.65:80;
    keepalive 2;
}

location /cam1/ {
    proxy_pass http://cam1/;
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_set_header Connection "";
    proxy_connect_timeout 10s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}
```

### 6.2 Critical Settings for Image/Video

| Setting | Value | Why |
|---------|-------|-----|
| `proxy_buffering off` | Required | Prevents NGINX from buffering JPEG responses |
| `proxy_cache off` | For streams | Prevents caching of dynamic content |
| `chunked_transfer_encoding off` | For MJPEG | Multipart responses are not chunked |
| `proxy_read_timeout 3600s` | For MJPEG | Long-lived stream connections |
| `keepalive 2` | Upstream | Reuse connections to camera |

### 6.3 TLS Termination

NGINX handles TLS 1.3 encryption. The ESP32 serves plain HTTP — TLS would be too resource-intensive for the microcontroller.

```
Browser ──HTTPS──► NGINX ──HTTP──► ESP32
         TLS 1.3          Plain
         + Auth            No auth
```

---

## 7. Dashboard Image Rendering

### 7.1 Capture Polling Architecture

The dashboard (`server/web/app.js`) creates an `<img>` tag per camera and refreshes it every 3 seconds:

```javascript
// Initial image load
img.src = getCaptureUrl(camera) + '?t=' + Date.now();

// Poll for new frames
setInterval(() => {
    if (document.visibilityState === 'visible') {
        img.src = getCaptureUrl(camera) + '?t=' + Date.now();
    }
}, refreshInterval);
```

**Key details**:
- `?t=Date.now()` cache-busts to prevent browser caching
- `document.visibilityState` check pauses polling when the tab is hidden (saves bandwidth)
- Each camera polls independently — no synchronization needed

### 7.2 Camera Card Layout

Each camera renders as a card in a responsive CSS grid:

```
┌─────────────────────────────────┐
│ Front Door          ● Online    │  ← Header (label + status)
├─────────────────────────────────┤
│                                 │
│        [Camera Image]           │  ← 4:3 aspect ratio container
│         800 x 600               │
│                                 │
├─────────────────────────────────┤
│ RSSI: -26dBm | Heap: 253KB     │  ← Footer (health info)
│                   📷  ⛶         │  ← Actions (snapshot, fullscreen)
└─────────────────────────────────┘
```

### 7.3 Grid Scaling

The CSS grid auto-fits cameras based on viewport width:

```css
.camera-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(480px, 1fr));
    gap: 1.5rem;
}
```

| Cameras | Layout | Viewport |
|---------|--------|----------|
| 1 | 1 column, full width | Any |
| 2 | 2 columns | > 960px |
| 3-4 | 2-3 columns | > 1440px |
| 5-8 | 3-4 columns | > 1920px |

### 7.4 Status Indicators

| Status | Color | Trigger |
|--------|-------|---------|
| **Online** | Green pulse | Health check returns 200 |
| **Connecting** | Yellow pulse | Initial load, reconnecting |
| **Offline** | Red solid | Health check fails or image error |

---

## 8. PSRAM Memory Architecture

### 8.1 XIAO ESP32-S3 Memory Map

| Memory | Size | Speed | Use |
|--------|------|-------|-----|
| Internal SRAM | 512 KB | Fast | Stack, heap, WiFi buffers |
| OPI PSRAM | 8 MB | Moderate | Camera frame buffers |
| Flash | 8 MB | Slow | Firmware, NVS |

### 8.2 Frame Buffer Allocation

The camera driver allocates frame buffers in PSRAM at init time:

```c
// Init at UXGA (1600x1200) to pre-allocate max buffer
config.frame_size = FRAMESIZE_UXGA;
config.fb_count = 2;
config.fb_location = CAMERA_FB_IN_PSRAM;
config.grab_mode = CAMERA_GRAB_LATEST;
```

**Memory budget** (SVGA, q=10, 2 buffers):

| Allocation | Size | Location |
|-----------|------|----------|
| Frame buffer 1 | ~960 KB | PSRAM |
| Frame buffer 2 | ~960 KB | PSRAM |
| WiFi stack | ~50 KB | Internal SRAM |
| HTTP server | ~20 KB | Internal SRAM |
| Free PSRAM | ~6 MB | Available |
| Free internal heap | ~250 KB | Available |

### 8.3 Double Buffering

With `fb_count=2` and `CAMERA_GRAB_LATEST`:
- Buffer A: being written by sensor DMA
- Buffer B: being read by HTTP handler
- No frame tearing, always serves the latest complete frame

---

## 9. Image Quality Tuning

### 9.1 Resolution vs Quality Trade-offs

For surveillance, the goal is **recognizable activity at distance**, not pixel-perfect detail.

| Priority | Setting | Rationale |
|----------|---------|-----------|
| **Identify people** | SVGA (800x600) | Sufficient detail at 5-15m range |
| **Smooth motion** | q=10, 3s poll | Low bandwidth, consistent updates |
| **Night awareness** | ae_level=+1 | Brighter exposure in low light |
| **Wide coverage** | Default FOV (~120°) | XIAO module has wide-angle lens |

### 9.2 Scene-Specific Adjustments

```c
// Outdoor (bright, high contrast)
sensor->set_ae_level(sensor, -1);
sensor->set_contrast(sensor, 1);
sensor->set_saturation(sensor, 1);

// Indoor (even lighting)
sensor->set_ae_level(sensor, 0);
sensor->set_contrast(sensor, 0);

// Backlit (window behind subject)
sensor->set_ae_level(sensor, 2);
sensor->set_aec2(sensor, 1);

// Night (minimal light)
sensor->set_agc_gain(sensor, 20);
sensor->set_ae_level(sensor, 2);
```

---

## 10. Thermal Management

### 10.1 Heat Sources

The XIAO ESP32-S3 Sense generates significant heat during sustained operation:

| Component | Power Draw | Heat Contribution |
|-----------|-----------|-------------------|
| ESP32-S3 CPU (240 MHz) | ~100 mA | Moderate |
| WiFi radio (TX) | ~300 mA | High |
| OV2640 sensor | ~60 mA | Low |
| PSRAM access | ~30 mA | Low |
| **Total** | **~490 mA** | **Board gets very hot** |

### 10.2 Mitigation Strategies

| Strategy | Effectiveness | Implementation |
|----------|--------------|----------------|
| **Heatsink** | High | Adhesive aluminum heatsink on ESP32-S3 chip |
| **Reduce resolution** | Medium | SVGA instead of XGA/UXGA |
| **Increase poll interval** | Medium | 5s instead of 3s reduces CPU duty cycle |
| **Increase JPEG quality number** | Low | q=15 instead of q=10 reduces encoder work |
| **WiFi.setSleep(true)** | Medium | Allows modem sleep between polls (breaks streaming) |

Seeed explicitly warns: the XIAO ESP32-S3 gets **very hot** during sustained streaming. A heatsink is recommended for continuous operation.

---

## 11. Multi-Camera Scaling

### 11.1 Adding Cameras

Each new XIAO ESP32-S3 Sense camera requires:

1. **Flash firmware** with unique `CAMERA_NAME` and `CAMERA_LABEL`
2. **Register on Pi** with NGINX upstream + dashboard config entry
3. **Refresh browser** to see the new camera card

See `SETUP.md` for the full procedure.

### 11.2 Scaling Limits

| Constraint | Limit | Bottleneck |
|-----------|-------|------------|
| WiFi bandwidth | ~8 cameras @ 3s poll | Home router 2.4GHz capacity |
| NGINX connections | ~20 cameras | Pi CPU for proxy overhead |
| Dashboard rendering | ~12 cameras | Browser memory for simultaneous images |
| Router DHCP | ~50 cameras | Typical home router lease pool |

### 11.3 Static IP Recommendations

DHCP-assigned IPs may change after router/camera reboots. For production deployments, set **static DHCP leases** on the router for each camera's MAC address.

```
cam1  10:20:ba:03:a2:80  →  192.168.1.65
cam2  10:20:ba:04:b3:91  →  192.168.1.66
cam3  10:20:ba:05:c4:a2  →  192.168.1.67
```

---

## 12. Future: On-Device Image Processing

### 12.1 ESP32-S3 AI Capabilities

The ESP32-S3 has a vector instruction set that can run lightweight neural networks:

| Feature | Capability |
|---------|-----------|
| **ESP-DL** | TensorFlow Lite Micro inference |
| **Vector extensions** | SIMD operations for matrix math |
| **PSRAM** | 8 MB for model weights + activations |
| **Practical models** | Person detection, motion detection, face detection |

### 12.2 Motion Detection (No ML)

Simple frame-differencing motion detection can run on the ESP32 without ML:

```c
// Pseudocode — compare consecutive frames
uint8_t *prev_frame = NULL;

bool detectMotion(camera_fb_t *fb) {
    if (!prev_frame) {
        prev_frame = (uint8_t *)ps_malloc(fb->len);
        memcpy(prev_frame, fb->buf, fb->len);
        return false;
    }

    int diff = 0;
    for (int i = 0; i < fb->len; i++) {
        diff += abs(fb->buf[i] - prev_frame[i]);
    }

    memcpy(prev_frame, fb->buf, fb->len);
    float avg_diff = (float)diff / fb->len;
    return avg_diff > MOTION_THRESHOLD;
}
```

### 12.3 Person Detection (ESP-WHO)

Espressif's ESP-WHO framework includes a pre-trained person detection model:

```c
#include "human_face_detect_msr01.hpp"

// Runs on QVGA (320x240) grayscale at ~5 FPS
// Returns bounding boxes of detected faces
```

**Trade-off**: Running inference reduces streaming FPS significantly. Best used as a trigger (detect → capture high-res still → alert).

---

## 13. Future: Server-Side Video Processing

### 13.1 Pi-Side Processing Options

The Raspberry Pi 5 has sufficient CPU for server-side image analysis:

| Tool | Purpose | Install |
|------|---------|---------|
| **OpenCV** | Image processing, motion detection | `pip install opencv-python-headless` |
| **TensorFlow Lite** | Object detection, classification | `pip install tflite-runtime` |
| **FFmpeg** | Video recording, transcoding | `sudo apt install ffmpeg` |
| **ImageMagick** | Image manipulation, annotation | `sudo apt install imagemagick` |

### 13.2 Recording Captures to Disk

```bash
# Capture a frame every 3 seconds, save with timestamp
while true; do
    curl -s http://192.168.1.65/capture \
        -o "/var/captures/cam1_$(date +%Y%m%d_%H%M%S).jpg"
    sleep 3
done
```

### 13.3 Creating Timelapse from Captures

```bash
# FFmpeg timelapse from captured JPEGs
ffmpeg -framerate 30 -pattern_type glob \
    -i '/var/captures/cam1_*.jpg' \
    -c:v libx264 -pix_fmt yuv420p \
    timelapse_cam1.mp4
```

### 13.4 OpenCV Motion Detection (Pi-Side)

```python
import cv2
import requests
import numpy as np
import time

CAM_URL = "http://192.168.1.65/capture"
THRESHOLD = 25
MIN_AREA = 500

prev_gray = None

while True:
    resp = requests.get(CAM_URL, timeout=5)
    img_array = np.frombuffer(resp.content, dtype=np.uint8)
    frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (21, 21), 0)

    if prev_gray is None:
        prev_gray = gray
        continue

    delta = cv2.absdiff(prev_gray, gray)
    thresh = cv2.threshold(delta, THRESHOLD, 255, cv2.THRESH_BINARY)[1]
    thresh = cv2.dilate(thresh, None, iterations=2)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    for contour in contours:
        if cv2.contourArea(contour) > MIN_AREA:
            print(f"Motion detected! Area: {cv2.contourArea(contour)}")

    prev_gray = gray
    time.sleep(3)
```

---

## 14. Security Considerations

### 14.1 Image Transport Security

| Layer | Protection | Implementation |
|-------|-----------|----------------|
| **WiFi** | WPA2-PSK encryption | Home router handles |
| **TLS** | TLS 1.3 (NGINX) | Self-signed cert, HTTPS only |
| **Auth** | HTTP Basic Auth | NGINX `.htpasswd` |
| **Network** | Local subnet only | Router firewall, no port forwarding |

### 14.2 Image Data Privacy

| Concern | Mitigation |
|---------|-----------|
| Images stored on Pi | Not currently stored — polling is live only |
| Images in browser cache | `Cache-Control: no-cache, no-store` headers |
| Images in NGINX logs | Access logs don't contain image data |
| ESP32 stores images | Frame buffers are overwritten every capture cycle |

### 14.3 Camera Tampering

| Attack | Detection |
|--------|-----------|
| Camera physically moved | Health check RSSI change (different distance to router) |
| Camera unplugged | Dashboard shows "Offline" status |
| Camera covered | Motion detection would show zero motion (future feature) |
| WiFi jamming | All cameras go offline simultaneously |

---

## Quick Reference Card

### Endpoints

| Endpoint | Method | Response | Use |
|----------|--------|----------|-----|
| `/` | GET | HTML page | Direct browser access |
| `/capture` | GET | JPEG image | Dashboard polling |
| `/stream` | GET | MJPEG stream | Direct real-time view |
| `/health` | GET | JSON status | Health monitoring |

### Key Settings

| Setting | Value | File |
|---------|-------|------|
| Resolution | SVGA 800x600 | `camera_config.h` |
| JPEG quality | 10 | `camera_config.h` |
| Poll interval | 3000ms | `main.cpp` |
| Frame buffers | 2 (PSRAM) | `camera_config.h` |
| WiFi sleep | Disabled | `main.cpp` |

### Diagnostic Commands

```bash
# Check camera health
curl http://<camera-ip>/health

# Save a capture
curl http://<camera-ip>/capture -o frame.jpg

# View JPEG metadata
file frame.jpg
identify frame.jpg  # ImageMagick

# Check JPEG file size
ls -la frame.jpg

# View MJPEG stream directly
firefox http://<camera-ip>/stream
```

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of espi-watching-you*
