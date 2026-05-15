#!/usr/bin/env bash
set -euo pipefail

gpu_bdf="0000:01:00.0"
log_dir="${HOME}/__home_organized/logs"
state_dir="${HOME}/.local/state/gpu-watchdog"
log_file="${log_dir}/gpu-health.log"
state_file="${state_dir}/state.env"
quarantine_file="${state_dir}/quarantine.env"
capture_script="${HOME}/__home_organized/scripts/capture-desktop-incident.sh"
vault_root="${HOME}/Desktop/Obsidian"
obsidian_dir="${vault_root}/System/GPU Health"
obsidian_index="${obsidian_dir}/index.md"
incident_note="System/GPU Incident 2026-03-10"

mkdir -p "${log_dir}" "${state_dir}" "${obsidian_dir}"

collect_gpu_incidents() {
  local boot_ref="$1"
  local out=""

  out+="$(
    journalctl -k -b "${boot_ref}" --no-pager 2>/dev/null \
      | rg -i 'nvrm: xid|flip event timeout|lost display notification|error while waiting for gpu progress' \
      | tail -n 20 || true
  )"

  out+=$'\n'

  out+="$(
    journalctl -b "${boot_ref}" --no-pager 2>/dev/null \
      | rg -i 'Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)|xdg-desktop-portal-hyprland.service: Failed with result' \
      | tail -n 20 || true
  )"

  printf '%s\n' "${out}" | sed '/^$/d'
}

trim_csv_field() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

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

trim_file() {
  local file="$1"
  local max_lines="$2"
  [[ -f "${file}" ]] || return 0
  local lines
  lines="$(wc -l < "${file}")"
  if (( lines > max_lines )); then
    tail -n "${max_lines}" "${file}" > "${file}.tmp"
    mv "${file}.tmp" "${file}"
  fi
}

extract_xid_processes() {
  printf '%s\n' "$1" \
    | sed -nE 's/.*name=([^, ]+).*/\1/p' \
    | sort -u \
    | paste -sd ',' -
}

ts="$(date '+%F %T %Z')"
day="$(date '+%F')"
speed="$(cat "/sys/bus/pci/devices/${gpu_bdf}/current_link_speed" 2>/dev/null || echo 'unknown')"
width="$(cat "/sys/bus/pci/devices/${gpu_bdf}/current_link_width" 2>/dev/null || echo 'unknown')"
max_speed="$(cat "/sys/bus/pci/devices/${gpu_bdf}/max_link_speed" 2>/dev/null || echo 'unknown')"
max_width="$(cat "/sys/bus/pci/devices/${gpu_bdf}/max_link_width" 2>/dev/null || echo 'unknown')"
nvml_output="$(nvidia-smi 2>&1 || true)"
pcie_csv="$(nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,pstate,utilization.gpu --format=csv,noheader 2>/dev/null | head -n1 || true)"
current_boot_incidents="$(collect_gpu_incidents 0)"
previous_boot_incidents="$(collect_gpu_incidents -1)"
current_xid_processes="$(extract_xid_processes "${current_boot_incidents}")"

nvml="ok"
if ! grep -q 'NVIDIA-SMI' <<<"${nvml_output}"; then
  nvml="fail"
fi

status="ok"
reason="GPU health looks normal"
if [[ "${nvml}" == "fail" ]]; then
  status="degraded"
  reason="NVML unavailable"
fi

if [[ -n "${pcie_csv}" ]]; then
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
  if [[ "${width_max_nvidia}" =~ ^[0-9]+$ ]]; then
    max_width="${width_max_nvidia}"
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

if [[ -n "${current_boot_incidents}" ]]; then
  status="degraded"
  if [[ "${reason}" == "GPU health looks normal" ]]; then
    reason="Current boot contains NVIDIA/Hyprland crash signals"
  else
    reason="${reason}; current boot contains NVIDIA/Hyprland crash signals"
  fi
fi

if [[ -n "${previous_boot_incidents}" ]]; then
  status="degraded"
  if [[ "${reason}" == "GPU health looks normal" ]]; then
    reason="Previous boot ended with NVIDIA/Hyprland crash signals"
  else
    reason="${reason}; previous boot ended with NVIDIA/Hyprland crash signals"
  fi
fi

quarantine=0
quarantine_reason=""
if [[ "${nvml}" == "fail" || -n "${current_boot_incidents}" || -n "${previous_boot_incidents}" ]]; then
  quarantine=1
  quarantine_reason="${reason}"
fi

if [[ -x "${capture_script}" ]]; then
  if [[ -n "${current_boot_incidents}" || -n "${previous_boot_incidents}" ]]; then
    "${capture_script}" >/dev/null 2>&1 || true
  fi
fi

prev_status=""
prev_reason=""
if [[ -f "${state_file}" ]]; then
  # shellcheck disable=SC1090
  source "${state_file}"
fi

printf '[%s] status=%s speed=%s width=%s max_speed=%s max_width=%s nvml=%s\n' \
  "${ts}" "${status}" "${speed}" "${width}" "${max_speed}" "${max_width}" "${nvml}" >> "${log_file}"

cat > "${quarantine_file}" <<EOF
GPU_QUARANTINE='${quarantine}'
GPU_QUARANTINE_REASON='${quarantine_reason}'
GPU_QUARANTINE_AT='${ts}'
GPU_XID_PROCESSES='${current_xid_processes}'
EOF

if [[ "${status}" != "${prev_status}" || "${reason}" != "${prev_reason}" ]]; then
  printf '[%s] detail=%s\n' "${ts}" "${reason}" >> "${log_file}"
  if [[ "${nvml}" == "fail" ]]; then
    printf '%s\n' "${nvml_output}" | sed 's/^/[nvidia-smi] /' >> "${log_file}"
  fi
  if [[ -n "${current_boot_incidents}" ]]; then
    printf '%s\n' "${current_boot_incidents}" | sed 's/^/[current-boot] /' >> "${log_file}"
  fi
  if [[ -n "${current_xid_processes}" ]]; then
    printf '[%s] xid_processes=%s\n' "${ts}" "${current_xid_processes}" >> "${log_file}"
  fi
  if [[ -n "${previous_boot_incidents}" ]]; then
    printf '%s\n' "${previous_boot_incidents}" | sed 's/^/[previous-boot] /' >> "${log_file}"
  fi

  note_file="${obsidian_dir}/${day}.md"
  if [[ ! -f "${note_file}" ]]; then
    {
      printf '# GPU Health %s\n\n' "${day}"
      printf -- '- Incident note: [[%s]]\n' "${incident_note}"
      printf -- '- Codex conversations: [[codex-conversations/index]]\n'
      printf -- '- Structured log: `%s`\n\n' "${log_file}"
      printf '## Events\n\n'
    } > "${note_file}"
  fi

  {
    printf '### %s\n\n' "${ts}"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Reason: %s\n' "${reason}"
    printf -- '- PCIe: `%s x%s` (max `%s x%s`)\n' "${speed}" "${width}" "${max_speed}" "${max_width}"
    printf -- '- NVML: `%s`\n' "${nvml}"
    if [[ -n "${current_xid_processes}" ]]; then
      printf -- '- Xid processes this boot: `%s`\n' "${current_xid_processes}"
    fi
    printf -- '- GPU quarantine: `%s`\n' "$([[ "${quarantine}" == "1" ]] && echo enabled || echo disabled)"
    if [[ -n "${pcie_csv}" ]]; then
      printf -- '- NVIDIA PCIe snapshot: `%s`\n' "${pcie_csv}"
    fi
    if [[ -n "${current_boot_incidents}" ]]; then
      printf -- '- Current boot incidents: yes\n'
      printf '\n```text\n%s\n```\n' "${current_boot_incidents}"
    fi
    if [[ -n "${previous_boot_incidents}" ]]; then
      printf -- '- Previous boot incidents: yes\n'
      printf '\n```text\n%s\n```\n' "${previous_boot_incidents}"
    fi
    if [[ "${nvml}" == "fail" ]]; then
      printf '\n```text\n%s\n```\n' "${nvml_output}"
    fi
    printf '\nBack: [[System/GPU Health/index|GPU Health Index]]\n\n'
  } >> "${note_file}"

  {
    printf '# GPU Health Index\n\n'
    printf -- '- Updated: `%s`\n\n' "$(date --iso-8601=seconds)"
    find "${obsidian_dir}" -maxdepth 1 -type f -name '20*.md' -printf '%f\n' | sort -r | while read -r file; do
      day_name="${file%.md}"
      printf -- '- [[System/GPU Health/%s|%s]]\n' "${day_name}" "${day_name}"
    done
  } > "${obsidian_index}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "GPU watchdog: ${status}" "${reason}" >/dev/null 2>&1 || true
  fi
fi

cat > "${state_file}" <<EOF
prev_status='${status}'
prev_reason='${reason}'
EOF

trim_file "${log_file}" 2000
