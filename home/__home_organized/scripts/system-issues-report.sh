#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/goringich}"
vault_root="${home_dir}/Desktop/Obsidian"
system_note="${vault_root}/System/System Violations Register.md"
system_health_note="${vault_root}/System/System Health/2026-03-23.md"
gpu_note="${vault_root}/System/GPU Incident 2026-03-10.md"

state_session="${home_dir}/.local/state/session-startup-guard/state.env"
state_gpu="${home_dir}/.local/state/gpu-watchdog/quarantine.env"
state_system="${home_dir}/.local/state/system-watchdog/state.env"
state_incident_capture="${home_dir}/.local/state/desktop-incident-capture/latest_bundle.env"

log_session="${home_dir}/__home_organized/logs/session-startup-guard.log"
log_gpu="${home_dir}/__home_organized/logs/gpu-health.log"
log_system="${home_dir}/__home_organized/logs/system-health.log"

have_rg=0
if command -v rg >/dev/null 2>&1; then
  have_rg=1
fi

use_color=0
if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
  use_color=1
fi

if (( use_color == 1 )); then
  c_reset=$'\033[0m'
  c_dim=$'\033[2m'
  c_muted=$'\033[38;5;245m'
  c_title=$'\033[1;38;5;117m'
  c_section=$'\033[1;38;5;81m'
  c_good=$'\033[1;38;5;82m'
  c_warn=$'\033[1;38;5;220m'
  c_bad=$'\033[1;38;5;196m'
  c_accent=$'\033[1;38;5;159m'
  c_panel=$'\033[48;5;236m'
  c_panel2=$'\033[48;5;238m'
else
  c_reset=""
  c_dim=""
  c_muted=""
  c_title=""
  c_section=""
  c_good=""
  c_warn=""
  c_bad=""
  c_accent=""
  c_panel=""
  c_panel2=""
fi

mode="full"
for arg in "$@"; do
  case "${arg}" in
    --compact|-c)
      mode="compact"
      ;;
    --full)
      mode="full"
      ;;
  esac
done

source_if_exists() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    # shellcheck disable=SC1090
    source "${file}"
  fi
}

run_maybe_root() {
  if sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    "$@"
  fi
}

print_rule() {
  printf '%b%s%b\n' "${c_dim}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${c_reset}"
}

print_section() {
  printf '\n'
  print_rule
  printf '%b%s%b\n' "${c_section}" "$1" "${c_reset}"
  print_rule
}

print_kv() {
  printf '%b%-24s%b %s\n' "${c_muted}" "$1" "${c_reset}" "$2"
}

badge_text() {
  local value="$1"
  case "${value}" in
    ok|NO|none|normal)
      printf '%b%s%b' "${c_good}" "${value}" "${c_reset}"
      ;;
    degraded|YES|present|open)
      printf '%b%s%b' "${c_bad}" "${value}" "${c_reset}"
      ;;
    unavailable*|unknown)
      printf '%b%s%b' "${c_warn}" "${value}" "${c_reset}"
      ;;
    *)
      printf '%b%s%b' "${c_accent}" "${value}" "${c_reset}"
      ;;
  esac
}

print_bullet() {
  printf '%b•%b %s\n' "${c_accent}" "${c_reset}" "$1"
}

print_block_label() {
  printf '%b[%s]%b\n' "${c_accent}" "$1" "${c_reset}"
}

print_excerpt() {
  local label="$1"
  local content="$2"
  local lines="${3:-8}"
  [[ -n "${content}" ]] || return 0
  print_block_label "${label}"
  take_last_lines "${content}" "${lines}" | sed "s/^/${c_muted}│${c_reset} /"
  printf '\n'
}

print_summary_row() {
  local label="$1"
  local value="$2"
  printf '  %-22s %s\n' "$label" "$value"
}

paint_status_word() {
  local value="$1"
  case "${value}" in
    ok|none|NO|disabled|normal)
      printf '%b%s%b' "${c_good}" "${value}" "${c_reset}"
      ;;
    degraded|YES|present|enabled|open)
      printf '%b%s%b' "${c_bad}" "${value}" "${c_reset}"
      ;;
    unavailable*|unknown|n/a)
      printf '%b%s%b' "${c_warn}" "${value}" "${c_reset}"
      ;;
    *)
      printf '%b%s%b' "${c_accent}" "${value}" "${c_reset}"
      ;;
  esac
}

print_status_chip() {
  local label="$1"
  local value="$2"
  local rendered
  rendered="$(paint_status_word "${value}")"
  printf '%b %s %b%s%b ' "${c_panel}" "${label}" "${c_reset}" "${rendered}" "${c_reset}"
}

print_metric_card() {
  local label="$1"
  local value="$2"
  printf '%b %-18s %b%s%b \n' "${c_panel2}" "${label}" "${c_reset}" "${value}" "${c_reset}"
}

print_legend() {
  printf '%bLegend%b\n' "${c_section}" "${c_reset}"
  printf '  %s = healthy or clear\n' "$(badge_text ok)"
  printf '  %s = degraded or needs attention\n' "$(badge_text degraded)"
  printf '  %s = unavailable or indeterminate in current shell\n' "$(badge_text unavailable)"
  printf '\n'
}

print_spotlight() {
  local headline="$1"
  local detail="$2"
  print_section "Priority Spotlight"
  printf '%b%s%b\n' "${c_bad}" "${headline}" "${c_reset}"
  printf '%b%s%b\n' "${c_muted}" "${detail}" "${c_reset}"
  printf '\n'
}

count_lines() {
  local content="$1"
  if [[ -z "${content}" ]]; then
    printf '0'
  else
    printf '%s\n' "${content}" | sed '/^$/d' | wc -l | tr -d ' '
  fi
}

collect_journal_matches() {
  local boot_ref="$1"
  local pattern="$2"

  if (( have_rg == 1 )); then
    journalctl -b "${boot_ref}" --no-pager 2>/dev/null | rg -i "${pattern}" || true
  else
    journalctl -b "${boot_ref}" --no-pager 2>/dev/null | grep -Ei "${pattern}" || true
  fi
}

take_last_lines() {
  local content="$1"
  local lines="${2:-6}"
  if [[ -z "${content}" ]]; then
    return 0
  fi
  printf '%s\n' "${content}" | tail -n "${lines}"
}

status_tag() {
  local value="$1"
  case "${value}" in
    1|true|enabled|degraded|fail|yes) printf 'YES' ;;
    0|false|disabled|ok|no) printf 'NO' ;;
    *) printf '%s' "${value}" ;;
  esac
}

session_state="unknown"
session_reason="n/a"
gpu_quarantine="unknown"
gpu_reason="n/a"
system_reason="n/a"
system_prev_status="unknown"
latest_bundle="n/a"
latest_bundle_kind="n/a"
latest_bundle_at="n/a"

source_if_exists "${state_session}"
source_if_exists "${state_gpu}"
source_if_exists "${state_system}"
source_if_exists "${state_incident_capture}"

session_state="${SAFE_MODE:-unknown}"
session_reason="${SAFE_REASON:-n/a}"
gpu_quarantine="${GPU_QUARANTINE:-unknown}"
gpu_reason="${GPU_QUARANTINE_REASON:-n/a}"
system_prev_status="${prev_status:-unknown}"
system_reason="${prev_reason:-n/a}"
latest_bundle="${LATEST_BUNDLE:-n/a}"
latest_bundle_kind="${LATEST_BUNDLE_KIND:-n/a}"
latest_bundle_at="${LATEST_BUNDLE_AT:-n/a}"

failed_system="$(systemctl --failed --no-pager --plain --no-legend 2>/dev/null | sed '/^$/d' || true)"
failed_user="$(systemctl --user --failed --no-pager --plain --no-legend 2>/dev/null | sed '/^$/d' || true)"
if [[ -z "${failed_user}" ]]; then
  failed_user="none or unavailable in current shell"
fi

unclean_markers="$(collect_journal_matches 0 'corrupted or uncleanly shut down')"
gpu_markers_current="$(collect_journal_matches 0 'NVRM: Xid|flip event timeout|lost display notification|error while waiting for gpu progress|libaquamarine|xdg-desktop-portal-hyprland.service: Failed|Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)')"
gpu_markers_previous="$(collect_journal_matches -1 'NVRM: Xid|flip event timeout|lost display notification|error while waiting for gpu progress|libaquamarine|xdg-desktop-portal-hyprland.service: Failed|Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)')"
dbus_duplicates="$(collect_journal_matches 0 "duplicate name 'org\\.freedesktop\\.FileManager1'|org\\.erikreider\\.swaync\\.service")"
mdns_conflicts="$(collect_journal_matches 0 'Host name conflict|Detected another IPv[46] mDNS stack')"
bluetooth_warns="$(collect_journal_matches 0 'Failed to set default system config for hci0|HCI Enhanced Setup Synchronous Connection command is advertised, but not supported')"
audio_usb_warns="$(collect_journal_matches 0 "snd_hda_intel .* no codecs found|cannot get freq at ep 0x82|couldn't find an input interrupt endpoint")"
swaync_warns="$(collect_journal_matches 0 'swaync.*(Theme parser|Config not found|backlightUtil)')"

sysfs_speed="$(cat /sys/bus/pci/devices/0000:01:00.0/current_link_speed 2>/dev/null || echo 'unknown')"
sysfs_width="$(cat /sys/bus/pci/devices/0000:01:00.0/current_link_width 2>/dev/null || echo 'unknown')"
pcie_snapshot="$(run_maybe_root nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,pstate,utilization.gpu --format=csv,noheader 2>/dev/null | head -n 1 || true)"
if [[ -z "${pcie_snapshot}" || "${pcie_snapshot}" != *,* ]]; then
  pcie_snapshot="sysfs current=${sysfs_speed} width=${sysfs_width}"
fi
boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo 'unknown')"

overall="ok"
if [[ -n "${unclean_markers}" || -n "${gpu_markers_current}" || "${session_state}" == "1" || "${gpu_quarantine}" == "1" || "${system_prev_status}" == "degraded" ]]; then
  overall="degraded"
fi

dirty_count="$(count_lines "${unclean_markers}")"
gpu_current_count="$(count_lines "${gpu_markers_current}")"
gpu_previous_count="$(count_lines "${gpu_markers_previous}")"
dbus_count="$(count_lines "${dbus_duplicates}")"
mdns_count="$(count_lines "${mdns_conflicts}")"
bluetooth_count="$(count_lines "${bluetooth_warns}")"
audio_usb_count="$(count_lines "${audio_usb_warns}")"
swaync_count="$(count_lines "${swaync_warns}")"
failed_system_count="$( [[ "${failed_system:-none}" == "none" || -z "${failed_system:-}" ]] && echo 0 || printf '%s\n' "${failed_system}" | sed '/^$/d' | wc -l | tr -d ' ' )"
failed_user_count="$( [[ "${failed_user}" == "none or unavailable in current shell" || -z "${failed_user}" ]] && echo 0 || printf '%s\n' "${failed_user}" | sed '/^$/d' | wc -l | tr -d ' ' )"

spotlight_headline="System is degraded but not in an active GPU crash loop right now."
spotlight_detail="The dominant current condition is dirty-shutdown recovery plus recurring non-GPU boot noise. Historical GPU incidents remain the top high-risk class."
if [[ -n "${gpu_markers_current}" ]]; then
  spotlight_headline="Active current-boot GPU or desktop crash signals detected."
  spotlight_detail="Treat this as a live compositor or NVIDIA incident first. Ignore cosmetic noise until the GPU/session stack is stable."
elif [[ "${session_state}" == "1" ]]; then
  spotlight_headline="Session safe mode is active."
  spotlight_detail="Guard rails are currently reducing autostarts because the previous shutdown or boot history looked unsafe."
fi

print_rule
printf '%b%s%b\n' "${c_title}" "System Issue Analytics" "${c_reset}"
printf '%b%s%b\n' "${c_muted}" "One-shot view of current boot health, repeated incident classes, and note pointers." "${c_reset}"
print_rule
printf '\n'

print_legend
print_spotlight "${spotlight_headline}" "${spotlight_detail}"

printf '%bStatus Strip%b\n' "${c_section}" "${c_reset}"
print_status_chip "overall" "${overall}"
print_status_chip "safe-mode" "$(status_tag "${session_state}")"
print_status_chip "gpu-quarantine" "$(status_tag "${gpu_quarantine}")"
print_status_chip "watchdog" "${system_prev_status}"
printf '\n\n'

printf '%bIncident Counters%b\n' "${c_section}" "${c_reset}"
print_metric_card "dirty journal" "${dirty_count}"
print_metric_card "gpu current" "${gpu_current_count}"
print_metric_card "gpu previous" "${gpu_previous_count}"
print_metric_card "dbus duplicates" "${dbus_count}"
print_metric_card "mdns conflicts" "${mdns_count}"
print_metric_card "bluetooth warns" "${bluetooth_count}"
print_metric_card "usb/audio warns" "${audio_usb_count}"
print_metric_card "swaync warns" "${swaync_count}"
print_metric_card "failed system" "${failed_system_count}"
print_metric_card "failed user" "${failed_user_count}"
printf '\n'

printf '%bOverview%b\n' "${c_section}" "${c_reset}"
print_summary_row "timestamp" "$(date --iso-8601=seconds)"
print_summary_row "host" "$(hostname 2>/dev/null || echo unknown)"
print_summary_row "kernel" "$(uname -r)"
print_summary_row "boot id" "${boot_id}"
print_summary_row "latest bundle" "${latest_bundle_kind}"
if [[ "${latest_bundle}" != "n/a" ]]; then
  print_summary_row "bundle path" "${latest_bundle}"
fi
print_summary_row "overall" "$(badge_text "${overall}")"
printf '\n'

print_section "State"
print_kv "Safe mode active" "$(badge_text "$(status_tag "${session_state}")")"
print_kv "Safe mode reason" "${session_reason}"
print_kv "GPU quarantine" "$(badge_text "$(status_tag "${gpu_quarantine}")")"
print_kv "GPU quarantine reason" "${gpu_reason}"
print_kv "System watchdog" "$(badge_text "${system_prev_status}")"
print_kv "System watchdog reason" "${system_reason}"
print_kv "PCIe runtime" "${sysfs_speed} x${sysfs_width}"
print_kv "NVIDIA snapshot" "$(badge_text "${pcie_snapshot:-unavailable}")"
if [[ "${latest_bundle}" != "n/a" ]]; then
  print_kv "Incident bundle" "${latest_bundle}"
  print_kv "Bundle captured at" "${latest_bundle_at}"
  print_kv "Bundle summary" "${latest_bundle}/summary.md"
fi
printf '\n'

print_section "Signals"
print_kv "Dirty journal markers" "$(badge_text "$( [[ -n "${unclean_markers}" ]] && echo present || echo none )")"
print_kv "Current GPU crash signals" "$(badge_text "$( [[ -n "${gpu_markers_current}" ]] && echo present || echo none )")"
print_kv "Previous GPU crash signals" "$(badge_text "$( [[ -n "${gpu_markers_previous}" ]] && echo present || echo none )")"
print_kv "D-Bus duplicate services" "$(badge_text "$( [[ -n "${dbus_duplicates}" ]] && echo present || echo none )")"
print_kv "mDNS/hostname conflict" "$(badge_text "$( [[ -n "${mdns_conflicts}" ]] && echo present || echo none )")"
print_kv "Bluetooth warnings" "$(badge_text "$( [[ -n "${bluetooth_warns}" ]] && echo present || echo none )")"
print_kv "USB/audio warnings" "$(badge_text "$( [[ -n "${audio_usb_warns}" ]] && echo present || echo none )")"
print_kv "swaync warnings this boot" "$(badge_text "$( [[ -n "${swaync_warns}" ]] && echo present || echo none )")"
printf '\n'

if [[ "${mode}" == "compact" ]]; then
  print_section "Compact Summary"
  print_bullet "Run without flags for the full dashboard and log excerpts."
  print_bullet "Open ${system_note} when overall status is degraded."
  print_bullet "Current PCIe runtime: ${sysfs_speed} x${sysfs_width}."
  if [[ "${latest_bundle}" != "n/a" ]]; then
    print_bullet "Latest incident bundle: ${latest_bundle}."
    print_bullet "Start with ${latest_bundle}/summary.md before reading raw journal again."
  fi
  print_bullet "Top current issue: ${session_reason}."
  exit 0
fi

print_section "Failed Units"
print_block_label "system"
printf '%s\n\n' "${failed_system:-none}" | sed "s/^/${c_muted}│${c_reset} /"
print_block_label "user"
printf '%s\n\n' "${failed_user}" | sed "s/^/${c_muted}│${c_reset} /"

if [[ -n "${unclean_markers}" ]]; then
  print_section "Dirty Journal Evidence"
  take_last_lines "${unclean_markers}" 8 | sed "s/^/${c_muted}│${c_reset} /"
  printf '\n'
fi

if [[ -n "${gpu_markers_current}" ]]; then
  print_section "Current Boot GPU/Desktop Evidence"
  take_last_lines "${gpu_markers_current}" 12 | sed "s/^/${c_muted}│${c_reset} /"
  printf '\n'
fi

if [[ -n "${dbus_duplicates}" || -n "${mdns_conflicts}" || -n "${bluetooth_warns}" || -n "${audio_usb_warns}" || -n "${swaync_warns}" ]]; then
  print_section "Current Boot Non-GPU Noise"
  print_excerpt "dbus" "${dbus_duplicates}" 8
  print_excerpt "mdns" "${mdns_conflicts}" 6
  print_excerpt "bluetooth" "${bluetooth_warns}" 6
  print_excerpt "usb-audio" "${audio_usb_warns}" 8
  print_excerpt "swaync" "${swaync_warns}" 10
fi

print_section "References"
print_kv "Violation register" "${system_note}"
print_kv "System health note" "${system_health_note}"
print_kv "GPU incident note" "${gpu_note}"
print_kv "System watchdog log" "${log_system}"
print_kv "GPU watchdog log" "${log_gpu}"
print_kv "Session guard log" "${log_session}"
printf '\n'

print_section "Recommended Next Actions"
if [[ "${latest_bundle}" != "n/a" ]]; then
  print_bullet "Use ${latest_bundle}/summary.md as the primary entry point for this incident instead of rereading broad journal output."
fi
print_bullet "If Xid or libaquamarine crashes return after the Hyprland rollback, capture the next bundle and compare it directly against the previous failing bundle."
print_bullet "If the rollback does not stop the incident class, the next narrow change is driver-path validation on the same bundle evidence, not random user-session tweaks."
print_bullet "Treat D-Bus, mDNS, Bluetooth, and USB/audio warnings as secondary until the GPU/compositor path is clean again."
