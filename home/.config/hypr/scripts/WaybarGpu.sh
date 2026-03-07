#!/usr/bin/env bash

set -euo pipefail

if ! command -v nvidia-smi >/dev/null 2>&1; then
  printf '{"text":"󰢮 n/a","tooltip":"nvidia-smi not found","class":"offline"}\n'
  exit 0
fi

metrics=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)

if [[ -z "${metrics}" ]]; then
  printf '{"text":"󰢮 n/a","tooltip":"GPU metrics unavailable","class":"offline"}\n'
  exit 0
fi

IFS=',' read -r util mem_used mem_total temp <<<"${metrics}"
util=${util//[[:space:]]/}
mem_used=${mem_used//[[:space:]]/}
mem_total=${mem_total//[[:space:]]/}
temp=${temp//[[:space:]]/}

if ! [[ "${util}" =~ ^[0-9]+$ && "${mem_used}" =~ ^[0-9]+$ && "${mem_total}" =~ ^[0-9]+$ && "${temp}" =~ ^[0-9]+$ ]]; then
  printf '{"text":"󰢮 n/a","tooltip":"GPU telemetry unavailable (nvidia-smi/NVML)","class":"offline"}\n'
  exit 0
fi

mem_pct=0
if (( mem_total > 0 )); then
  mem_pct=$(( mem_used * 100 / mem_total ))
fi

class="cool"
if (( temp >= 82 )); then
  class="hot"
elif (( temp >= 70 )); then
  class="warm"
fi

printf '{"text":"󰢮 %s%% 󰍛 %s%%","tooltip":"GPU: %s%%\\nVRAM: %s/%s MiB (%s%%)\\nTemp: %s°C","class":"%s"}\n' \
  "${util:-0}" "${temp:-0}" "${util:-0}" "${mem_used:-0}" "${mem_total:-0}" "${mem_pct}" "${temp:-0}" "${class}"
