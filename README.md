# Edge CCTV Infrastructure Recovery: Physical Layer Fault Isolation & Topology Remediation

A production post-mortem, incident resolution log, and automated verification suite addressing an edge IP camera outage caused by physical cable mechanical failure, terminal short-circuiting, and switch-port PoE controller degradation.

## Overview & Business Context

### The Challenge
A critical security camera in an enterprise physical access control perimeter went offline (`DOWN`). Remote administrative actions—including soft reboots and hardware PoE power-cycling on the managed switch—failed to restore link negotiation or device telemetry.

### The Business Impact
Loss of real-time perimeter surveillance posed a compliance breach under regional physical access auditing standards. Immediate recovery of L1–L7 connectivity was required without replacing functional high-cost edge sensors.

## Architecture & Technology Stack

```text
[ PoE Switch ]
      │
      ├─ [ Port 1 (Faulty/Disabled) ] ──x (Short circuit)
      │
      └─ [ Port 2 (Active PoE 802.3af) ]
            │
            └── [ Cat5e/6 UTP 23AWG (T-568B) ~15m ] ──► [ IP Camera (192.168.1.120) ]
                                                              │ (RTSP Stream)
                                                              ▼
                                                    [ NVR / VMS Collector ]
```

* **Layer 1 (Physical):** Cat5e/6 Pure Copper (CU) 23AWG, T-568B termination standard, IP67 waterproof strain relief.
* **Layer 2 (Data Link / Power):** IEEE 802.3af/at Power over Ethernet (PoE), 10/100/1000BASE-T RJ-45 switching.
* **Layer 3/4 (Network/Transport):** IPv4, TCP, ICMP, SNMPv2c.
* **Layer 7 (Application):** RTSP (Real-Time Streaming Protocol), ONVIF Profile S.
* **Tooling:** Network Cable Master/Remote Tester, Advanced IP Scanner, `nmap`, `ffprobe`, `snmpget`, Bash.

## Root Cause Analysis (RCA)

A multi-factor compounding fault masked the underlying issues during standard telemetry inspections:

1. **Mechanical Stress & Core Rupture:** Over-torqued cable fasteners caused structural pinching along the perimeter cable tray, severing Core 8 (Brown) and inducing an intermittent short circuit between pairs 7-8 and adjacent pairs.
2. **Controller Port Lockout / Failure:** The intermittent short circuit tripped the PoE port protection circuit on Switch Port 1, causing irreversible hardware controller fault on that specific port while the rest of the managed switch chassis continued normal operation.
3. **Tooling Anomaly:** Mid-incident failure of mechanical crimping equipment caused improper pin seated depth, producing transient opens on Pin 8 during initial replacement patches.

## Incident Remediation Workflow

### 1. Isolated Benchtop Diagnostics
* Dismounted edge unit and established direct back-to-back link to the switch fabric using a certified reference patch cord.
* Confirmed camera logic and sensor were fully operational, ruling out optical or motherboard failure.

### 2. Physical Layer Reconstruction
* Spliced and re-pulled an insulated 15-meter run of pure copper (CU) 23AWG unshielded twisted pair to preserve signal integrity and eliminate resistance voltage drops under load.
* Terminated both ends under the **ANSI/TIA-568-B** standard:
  ```text
  Pin 1: White-Orange  | Pin 5: White-Blue
  Pin 2: Orange        | Pin 6: Green
  Pin 3: White-Green   | Pin 7: White-Brown
  Pin 4: Blue          | Pin 8: Brown
  ```
* Verified all 8 cores end-to-end via hardware sequential pin tester (1 through 8 continuous).

### 3. Port Migration & Reconfiguration
* Identified silent hardware failure on switch port 1.
* Reallocated the cable drop to switch port 2.
* Configured port isolation, set dynamic PoE priority to High, and labeled port 1 as defective for scheduled board-level maintenance.
* Sealed edge terminations inside an IP67-rated waterproof compression gland.

## Deployment & Verification

### Prerequisites
* `bash` 4.0+
* `ffmpeg` / `ffprobe`
* `snmp` (optional, for MIB checks)
* `iputils-ping`

### Quickstart
1. Clone this repository:
   ```bash
   git clone https://github.com
   cd cctv-infrastructure-recovery
   ```
2. Make the verification script executable:
   ```bash
   chmod +x monitor_camera.sh
   ```
3. Set deployment parameters and run verification:
   ```bash
   export CAMERA_IP="192.168.1.120"
   export RTSP_USER="svc_cctv_collector"
   export RTSP_PASSWORD="EncryptedSecretHere"
   export RTSP_PATH="/Streaming/Channels/101"
   export SWITCH_IP="192.168.1.2"
   export PORT_INDEX="2"

   ./monitor_camera.sh
   ```

### Verification Output
```text
=== [1/3] Checking ICMP Reachability ===
[OK] Host 192.168.1.120 is reachable via ICMP.
=== [2/3] Checking Port State via SNMP (dot3afPethPsePortDetectionStatus) ===
PoE Port 2 Status OID response: deliveringPower
[OK] Switch is delivering power over PoE on port 2.
=== [3/3] Validating RTSP Media Feed ===
[OK] RTSP video stream received and parsed successfully.
=== [RESULT] All health checks passed. System is nominal. ===
```

## Key Lessons Learned

* **Avoid Single-Port Assumptions:** Never assume a switch has survived a cable-level short circuit simply because adjacent chassis ports remain operational. Test against adjacent known-good ports early.
* **Bench Isolation First:** Testing devices directly against the network core ("on-the-bench" test) instantly eliminates 50% of unknown variables in hybrid power/data failures.
* **Copper Quality Matters:** High-grade 23AWG pure copper runs reduce resistance and prevent thermal throttling when operating high-draw IR illuminators over standard distances.

