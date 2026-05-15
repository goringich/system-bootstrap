#!/usr/bin/env bash
set -euo pipefail

log_dir="${HOME}/__home_organized/logs"
log_file="${log_dir}/gpu-health.log"
mkdir -p "${log_dir}"

gen_to_speed() {
  case "$1" in
    1) printf '2.5 GT/s PCIe' ;;
    2) printf '5.0 GT/s PCIe' ;;
    3) printf '8.0 GT/s PCIe' ;;
    4) printf '16.0 GT/s PCIe' ;;
    5) printf '32.0 GT/s PCIe' ;;
    6) printf '64.0 GT/s PCIe' ;;
    *) printf 'unknown' ;;
  esac
}

trim_csv_field() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

ts="$(date '+%F %T %Z')"
speed="$(cat /sys/bus/pci/devices/0000:01:00.0/current_link_speed 2>/dev/null || echo 'unknown')"
width="$(cat /sys/bus/pci/devices/0000:01:00.0/current_link_width 2>/dev/null || echo 'unknown')"
max_speed="$(cat /sys/bus/pci/devices/0000:01:00.0/max_link_speed 2>/dev/null || echo 'unknown')"
nvml_ok=1
nvml_output="$(nvidia-smi 2>&1 || true)"
pcie_csv="$(nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,pstate,utilization.gpu --format=csv,noheader 2>/dev/null | head -n1 || true)"

if ! grep -q 'NVIDIA-SMI' <<<"${nvml_output}"; then
  nvml_ok=0
fi

status="ok"
reason="GPU health looks normal"
if [[ ${nvml_ok} -eq 0 ]]; then
  status="degraded"
  reason="NVML unavailable"
fi

if [[ "${status}" == "ok" && -n "${pcie_csv}" ]]; then
  IFS=',' read -r gen_current_raw gen_max_raw width_current_raw width_max_raw pstate_raw util_raw <<< "${pcie_csv}"
  gen_current="$(trim_csv_field "${gen_current_raw:-}")"
  gen_max="$(trim_csv_field "${gen_max_raw:-}")"
  width_current_nvidia="$(trim_csv_field "${width_current_raw:-}")"
  width_max_nvidia="$(trim_csv_field "${width_max_raw:-}")"
  pstate="$(trim_csv_field "${pstate_raw:-}")"
  util="$(trim_csv_field "${util_raw:-0}")"

  if [[ "${gen_current}" =~ ^[0-9]+$ ]]; then
    speed="$(gen_to_speed "${gen_current}")"
  fi
  if [[ "${gen_max}" =~ ^[0-9]+$ ]]; then
    max_speed="$(gen_to_speed "${gen_max}")"
  fi
  if [[ "${width_current_nvidia}" =~ ^[0-9]+$ ]]; then
    width="${width_current_nvidia}"
  fi

  util="${util%%%}"
  if [[ "${util}" =~ ^[0-9]+$ ]]; then
    gpu_busy=0
    if (( util >= 40 )) || [[ "${pstate}" =~ ^P[0-2]$ ]]; then
      gpu_busy=1
    fi

    if [[ "${width_current_nvidia}" =~ ^[0-9]+$ && "${width_max_nvidia}" =~ ^[0-9]+$ ]] && (( width_current_nvidia < width_max_nvidia )); then
      status="degraded"
      reason="PCIe width is x${width_current_nvidia} (max x${width_max_nvidia})"
    elif [[ "${gen_current}" =~ ^[0-9]+$ && "${gen_max}" =~ ^[0-9]+$ ]] && (( gpu_busy == 1 && gen_current + 1 < gen_max )); then
      status="degraded"
      reason="GPU is busy (${util}% util, ${pstate:-unknown}) but PCIe is still Gen${gen_current} (max Gen${gen_max})"
    fi
  fi
fi

printf '[%s] status=%s speed=%s width=%s max_speed=%s nvml=%s\n' \
  "${ts}" "${status}" "${speed}" "${width}" "${max_speed}" "$([[ ${nvml_ok} -eq 1 ]] && echo ok || echo fail)" \
  >> "${log_file}"

if [[ "${status}" != "ok" ]]; then
  printf '[%s] detail=%s\n' "${ts}" "${reason}" >> "${log_file}"
  printf '%s\n' "${nvml_output}" | sed 's/^/[nvidia-smi] /' >> "${log_file}"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "GPU degraded at login" "${reason}. See ${log_file}" || true
  fi
fi
