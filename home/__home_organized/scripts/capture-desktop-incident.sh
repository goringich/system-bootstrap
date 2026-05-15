#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/goringich}"
artifact_root="${home_dir}/__home_organized/artifacts/system-incidents"
state_dir="${home_dir}/.local/state/desktop-incident-capture"
latest_file="${state_dir}/latest_bundle.env"
vault_root="${home_dir}/Desktop/Obsidian"

pattern='NVRM: Xid|flip event timeout|lost display notification|error while waiting for gpu progress|Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)|xdg-desktop-portal-hyprland.service: Failed with result|libaquamarine|SkiaGPUWorker|libnvidia-eglcore|Failed to create sync file from fence'

mode="auto"
force=0
for arg in "$@"; do
  case "${arg}" in
    --force) force=1 ;;
    --mode=*) mode="${arg#--mode=}" ;;
    -h|--help)
      cat <<'EOF'
capture-desktop-incident.sh

Captures a focused Hyprland/NVIDIA incident bundle into:
  ~/__home_organized/artifacts/system-incidents/

Modes:
  --mode=auto       current-boot crash if present, otherwise recovery bundle
  --mode=crash      require current-boot crash evidence
  --mode=recovery   require previous-boot crash evidence and no current crash

Options:
  --force           ignore dedupe guard for the current boot + mode
EOF
      exit 0
      ;;
  esac
done

mkdir -p "${artifact_root}" "${state_dir}"

collect_matches() {
  local boot_ref="$1"
  journalctl -b "${boot_ref}" --no-pager 2>/dev/null | rg -i "${pattern}" | tail -n 80 || true
}

collect_unclean() {
  journalctl -b 0 --no-pager 2>/dev/null | rg -i 'corrupted or uncleanly shut down' | tail -n 20 || true
}

current_boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
previous_boot_id="$(journalctl --list-boots --no-pager 2>/dev/null | awk '$1 == -1 {print $2; exit}')"
ts="$(date '+%F %T %Z')"
stamp="$(date '+%F_%H-%M-%S')"
day="$(date '+%F')"

current_incidents="$(collect_matches 0)"
previous_incidents="$(collect_matches -1)"
unclean_markers="$(collect_unclean)"

capture_kind=""
case "${mode}" in
  auto)
    if [[ -n "${current_incidents}" ]]; then
      capture_kind="crash-current-boot"
    elif [[ -n "${previous_incidents}" ]]; then
      capture_kind="recovery-after-previous-boot"
    fi
    ;;
  crash)
    [[ -n "${current_incidents}" ]] && capture_kind="crash-current-boot"
    ;;
  recovery)
    if [[ -z "${current_incidents}" && -n "${previous_incidents}" ]]; then
      capture_kind="recovery-after-previous-boot"
    fi
    ;;
  *)
    printf 'Unknown mode: %s\n' "${mode}" >&2
    exit 2
    ;;
esac

[[ -n "${capture_kind}" ]] || exit 0

guard_file="${state_dir}/${current_boot_id}-${capture_kind}.done"
if [[ "${force}" != "1" && -f "${guard_file}" ]]; then
  exit 0
fi

short_boot="${current_boot_id%%-*}"
bundle_dir="${artifact_root}/${day}/${stamp}--${capture_kind}--${short_boot}"
mkdir -p "${bundle_dir}"

system_failed="$(systemctl --failed --no-pager --plain --no-legend 2>/dev/null | sed '/^$/d' || true)"
user_failed="$(systemctl --user --failed --no-pager --plain --no-legend 2>/dev/null | sed '/^$/d' || true)"
session_guard_tail="$(tail -n 80 "${home_dir}/__home_organized/logs/session-startup-guard.log" 2>/dev/null || true)"
gpu_watchdog_tail="$(tail -n 80 "${home_dir}/__home_organized/logs/gpu-health.log" 2>/dev/null || true)"
system_watchdog_tail="$(tail -n 80 "${home_dir}/__home_organized/logs/system-health.log" 2>/dev/null || true)"
packages="$(
  pacman -Q hyprland aquamarine hyprgraphics hyprutils xdg-desktop-portal-hyprland nvidia-utils nvidia-open-dkms nvidia-580xx-open-dkms nvidia-580xx-dkms linux-cachyos-lts-nvidia-open 2>/dev/null || true
)"
nvidia_smi="$(nvidia-smi 2>&1 || true)"
pcie_snapshot="$(nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,pstate,utilization.gpu --format=csv,noheader 2>/dev/null | head -n1 || true)"
sysfs_speed="$(cat /sys/bus/pci/devices/0000:01:00.0/current_link_speed 2>/dev/null || echo unknown)"
sysfs_width="$(cat /sys/bus/pci/devices/0000:01:00.0/current_link_width 2>/dev/null || echo unknown)"
if [[ -z "${pcie_snapshot}" || "${pcie_snapshot}" != *,* ]]; then
  pcie_snapshot="sysfs current=${sysfs_speed} width=${sysfs_width}"
fi
coredumps="$(coredumpctl list --no-pager 2>/dev/null | rg 'Hyprland|xdg-desktop-por|SkiaGPUWorker' | tail -n 30 || true)"
boot_list="$(journalctl --list-boots --no-pager 2>/dev/null | tail -n 12 || true)"

printf '%s\n' "${current_incidents}" > "${bundle_dir}/current-boot-incidents.log"
printf '%s\n' "${previous_incidents}" > "${bundle_dir}/previous-boot-incidents.log"
printf '%s\n' "${unclean_markers}" > "${bundle_dir}/unclean-markers.log"
printf '%s\n' "${system_failed}" > "${bundle_dir}/failed-system-units.log"
printf '%s\n' "${user_failed}" > "${bundle_dir}/failed-user-units.log"
printf '%s\n' "${session_guard_tail}" > "${bundle_dir}/session-startup-guard-tail.log"
printf '%s\n' "${gpu_watchdog_tail}" > "${bundle_dir}/gpu-watchdog-tail.log"
printf '%s\n' "${system_watchdog_tail}" > "${bundle_dir}/system-watchdog-tail.log"
printf '%s\n' "${packages}" > "${bundle_dir}/packages.txt"
printf '%s\n' "${nvidia_smi}" > "${bundle_dir}/nvidia-smi.txt"
printf '%s\n' "${pcie_snapshot}" > "${bundle_dir}/pcie-snapshot.txt"
printf '%s\n' "${coredumps}" > "${bundle_dir}/coredumps.log"
printf '%s\n' "${boot_list}" > "${bundle_dir}/boot-list.log"

{
  printf '# Desktop Incident Capture\n\n'
  printf -- '- Captured at: `%s`\n' "${ts}"
  printf -- '- Kind: `%s`\n' "${capture_kind}"
  printf -- '- Current boot ID: `%s`\n' "${current_boot_id}"
  if [[ -n "${previous_boot_id}" ]]; then
    printf -- '- Previous boot ID: `%s`\n' "${previous_boot_id}"
  fi
  printf -- '- Bundle dir: `%s`\n\n' "${bundle_dir}"

  printf '## Why this bundle exists\n\n'
  if [[ "${capture_kind}" == "crash-current-boot" ]]; then
    printf -- '- Current boot already contains direct Hyprland/NVIDIA crash evidence.\n'
    printf -- '- This bundle freezes the narrow evidence set before a later reboot hides the original sequence.\n\n'
  else
    printf -- '- Current boot looks like a recovery boot after a crash-signalling previous boot.\n'
    printf -- '- This bundle keeps both sides of the transition together so the next debug session can compare failure and recovery immediately.\n\n'
  fi

  printf '## Focused snapshot\n\n'
  printf -- '- Packages in play:\n\n```text\n%s\n```\n\n' "${packages}"
  if [[ -n "${pcie_snapshot}" ]]; then
    printf -- '- NVIDIA PCIe snapshot:\n\n```text\n%s\n```\n\n' "${pcie_snapshot}"
  fi
  if [[ -n "${current_incidents}" ]]; then
    printf -- '- Current boot incidents:\n\n```text\n%s\n```\n\n' "${current_incidents}"
  fi
  if [[ -n "${previous_incidents}" ]]; then
    printf -- '- Previous boot incidents:\n\n```text\n%s\n```\n\n' "${previous_incidents}"
  fi
  if [[ -n "${unclean_markers}" ]]; then
    printf -- '- Dirty journal markers:\n\n```text\n%s\n```\n\n' "${unclean_markers}"
  fi

  printf '## Files in this bundle\n\n'
  printf -- '- `current-boot-incidents.log`\n'
  printf -- '- `previous-boot-incidents.log`\n'
  printf -- '- `unclean-markers.log`\n'
  printf -- '- `failed-system-units.log`\n'
  printf -- '- `failed-user-units.log`\n'
  printf -- '- `session-startup-guard-tail.log`\n'
  printf -- '- `gpu-watchdog-tail.log`\n'
  printf -- '- `system-watchdog-tail.log`\n'
  printf -- '- `packages.txt`\n'
  printf -- '- `nvidia-smi.txt`\n'
  printf -- '- `pcie-snapshot.txt`\n'
  printf -- '- `coredumps.log`\n'
  printf -- '- `boot-list.log`\n'

  printf '\n## How to use this bundle\n\n'
  printf -- '- Start with `summary.md`, then compare `previous-boot-incidents.log` to `current-boot-incidents.log`.\n'
  printf -- '- If this is a recovery bundle, treat the previous boot as the primary failure window and the current boot as the recovery window.\n'
  printf -- '- Update or create the matching note in `Desktop/Obsidian/System/` and link this bundle path there.\n'
  printf -- '- Use `~/__home_organized/scripts/system-issues-report.sh --compact` to confirm that this bundle is now the active debug entry point.\n'
} > "${bundle_dir}/summary.md"

cat > "${latest_file}" <<EOF
LATEST_BUNDLE='${bundle_dir}'
LATEST_BUNDLE_KIND='${capture_kind}'
LATEST_BUNDLE_BOOT_ID='${current_boot_id}'
LATEST_BUNDLE_AT='${ts}'
EOF

: > "${guard_file}"
