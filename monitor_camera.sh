#!/usr/bin/env bash
# ==============================================================================
# Script: monitor_camera.sh
# Purpose: Verify L3 reachability, RTSP video streaming, and PoE switch port health.
# ==============================================================================

set -euo pipefail

# Environment-configurable variables with safe fallbacks
CAMERA_IP="${CAMERA_IP:-192.168.1.120}"
RTSP_PORT="${RTSP_PORT:-554}"
RTSP_USER="${RTSP_USER:-admin}"
RTSP_PASSWORD="${RTSP_PASSWORD:-SafePassword123}"
RTSP_PATH="${RTSP_PATH:-/Streaming/Channels/101}"
SWITCH_IP="${SWITCH_IP:-192.168.1.2}"
SWITCH_COMMUNITY="${SWITCH_COMMUNITY:-public}"
PORT_INDEX="${PORT_INDEX:-2}"

echo "=== [1/3] Checking ICMP Reachability ==="
if ping -c 3 -W 2 "${CAMERA_IP}" > /dev/null 2>&1; then
    echo "[OK] Host ${CAMERA_IP} is reachable via ICMP."
else
    echo "[FAIL] Host ${CAMERA_IP} is unreachable. Check physical Layer 1/2 connection."
    exit 1
fi

echo "=== [2/3] Checking Port State via SNMP (dot3afPethPsePortDetectionStatus) ==="
POE_STATUS=$(snmpget -v2c -c "${SWITCH_COMMUNITY}" "${SWITCH_IP}" \
  "1.3.6.1.2.1.105.1.1.1.6.1.${PORT_INDEX}" 2>/dev/null | awk '{print $NF}' || echo "N/A")

echo "PoE Port ${PORT_INDEX} Status OID response: ${POE_STATUS}"
if [[ "${POE_STATUS}" == *"3"* ]] || [[ "${POE_STATUS}" == *"deliveringPower"* ]]; then
    echo "[OK] Switch is delivering power over PoE on port ${PORT_INDEX}."
else
    echo "[WARN] PoE controller status is abnormal or SNMP is disabled. Proceeding to RTSP check."
fi

echo "=== [3/3] Validating RTSP Media Feed ==="
RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASSWORD}@${CAMERA_IP}:${RTSP_PORT}${RTSP_PATH}"

if ffprobe -v error -rtsp_transport tcp -i "${RTSP_URL}" -show_entries stream=codec_type,width,height -of default=noprint_wrappers=1 2>&1 | grep -q "codec_type=video"; then
    echo "[OK] RTSP video stream received and parsed successfully."
else
    echo "[FAIL] Failed to pull video frame from ${CAMERA_IP}:${RTSP_PORT}."
    exit 2
fi

echo "=== [RESULT] All health checks passed. System is nominal. ==="
