#!/usr/bin/env bash
set -euo pipefail

owner_user="${SUDO_USER:-goringich}"
owner_home="$(getent passwd "${owner_user}" | cut -d: -f6)"
log_dir="${owner_home}/__home_organized/logs"
max_logs=30
mkdir -p "${log_dir}"
stamp="$(date '+%F_%H-%M-%S')"
report="${log_dir}/system-self-check-${stamp}.log"
latest="${log_dir}/system-self-check-latest.log"

exec > >(tee "${report}") 2>&1

section() {
  printf '\n=== %s ===\n' "$1"
}

run_maybe_root() {
  if sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    "$@"
  fi
}

run_user_systemctl() {
  local uid
  uid="$(id -u "${owner_user}")"
  if [[ -S "/run/user/${uid}/bus" ]]; then
    sudo -n -u "${owner_user}" \
      env XDG_RUNTIME_DIR="/run/user/${uid}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
      systemctl --user "$@"
  else
    echo "User bus for ${owner_user} is not available"
  fi
}

print_btrfs_scrub_summary() {
  local scrub_output
  scrub_output="$(btrfs scrub status / 2>/dev/null || true)"
  if [[ -z "${scrub_output}" ]]; then
    echo "Btrfs scrub: status unavailable"
    return
  fi
  if grep -q "no stats available" <<<"${scrub_output}"; then
    echo "Btrfs scrub: no completed scrub stats recorded yet"
    return
  fi
  grep -E '^(UUID|Status|Started|Finished|Total to scrub|Rate|Error summary):' <<<"${scrub_output}" || echo "${scrub_output}"
}

print_obsidian_git_summary() {
  local vault="${owner_home}/Desktop/Obsidian"
  if [[ ! -d "${vault}/.git" ]]; then
    echo "Obsidian vault repo: missing"
    return
  fi

  local branch head last_commit dirty tracked untracked
  branch="$(git -C "${vault}" branch --show-current 2>/dev/null || true)"
  head="$(git -C "${vault}" rev-parse --short HEAD 2>/dev/null || true)"
  last_commit="$(git -C "${vault}" log -1 --format='%ad %h %s' --date=iso-strict 2>/dev/null || true)"
  dirty="$(git -C "${vault}" status --short 2>/dev/null | wc -l | tr -d ' ')"
  tracked="$(git -C "${vault}" status --short 2>/dev/null | awk '$1 != "??" {count++} END {print count+0}')"
  untracked="$(git -C "${vault}" status --short 2>/dev/null | awk '$1 == "??" {count++} END {print count+0}')"

  printf 'Branch: %s\n' "${branch:-unknown}"
  printf 'HEAD: %s\n' "${head:-unknown}"
  printf 'Working tree changes: %s (tracked=%s, untracked=%s)\n' "${dirty:-0}" "${tracked:-0}" "${untracked:-0}"
  if [[ -n "${last_commit}" ]]; then
    printf 'Last commit: %s\n' "${last_commit}"
  fi
  git -C "${vault}" status --short 2>/dev/null | sed -n '1,12p' || true
}

print_codex_sync_summary() {
  local state_file="${owner_home}/.local/state/codex-obsidian-sync/state.json"
  local export_root="${owner_home}/Desktop/Obsidian/codex-conversations"

  if [[ -f "${state_file}" ]]; then
    printf 'State file: %s\n' "${state_file}"
    printf 'State updated: %s\n' "$(date -r "${state_file}" --iso-8601=seconds 2>/dev/null || stat -c '%y' "${state_file}" 2>/dev/null || echo unknown)"
    printf 'Tracked sessions: %s\n' "$(python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); print(len(d))' "${state_file}" 2>/dev/null || echo unknown)"
  else
    echo "State file: missing"
  fi

  if [[ -d "${export_root}" ]]; then
    printf 'Exported notes: %s\n' "$(find "${export_root}" -type f -name '*.md' ! -name 'index.md' | wc -l | tr -d ' ')"
    find "${export_root}" -type f -name '*.md' ! -name 'index.md' -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort | tail -n 3 || true
  else
    echo "Export root: missing"
  fi
}

section "Meta"
date --iso-8601=seconds
hostnamectl 2>/dev/null | sed -n '1,12p' || true
printf 'Kernel: '
uname -r

section "Boot"
run_maybe_root grep -E '^(default_entry|remember_last_entry|timeout):' /boot/limine.conf 2>/dev/null || true

section "Systemd Failed"
run_maybe_root systemctl --failed --no-pager --plain --no-legend || true

section "User Failed"
run_user_systemctl --failed --no-pager --plain --no-legend || true

section "Timers"
run_maybe_root systemctl list-timers --all --no-pager | sed -n '1,40p' || true
echo
run_user_systemctl list-timers --all --no-pager | sed -n '1,40p' || true

section "Safety Layers"
run_maybe_root systemctl status btrfs-scrub-root.timer --no-pager -n 0 2>/dev/null || true
echo
run_maybe_root systemctl status system-safety-backup.timer --no-pager -n 0 2>/dev/null || true
echo
run_maybe_root test -f /etc/pacman.d/hooks/95-system-safety-audit.hook && echo "pacman safety hook: installed" || echo "pacman safety hook: missing"
echo
run_user_systemctl status gpu-watchdog.timer --no-pager -n 0 2>/dev/null || true
echo
run_user_systemctl status system-watchdog.timer --no-pager -n 0 2>/dev/null || true
echo
run_user_systemctl status codex-obsidian-sync.timer --no-pager -n 0 2>/dev/null || true

section "Storage"
findmnt -t btrfs,ext4,xfs || true
echo
df -h / /boot /home || true
echo
print_btrfs_scrub_summary
echo
btrfs filesystem usage -T / 2>/dev/null | sed -n '1,20p' || true

section "NVMe SMART"
if command -v smartctl >/dev/null 2>&1; then
  run_maybe_root smartctl -H /dev/nvme0n1 2>/dev/null || true
fi

section "Safety Backups"
if [[ -d "${owner_home}/__home_organized/artifacts/system-safety" ]]; then
  ls -lh "${owner_home}/__home_organized/artifacts/system-safety" | tail -n 10 || true
  echo
  latest_backup="$(readlink -f "${owner_home}/__home_organized/artifacts/system-safety/latest" 2>/dev/null || true)"
  if [[ -n "${latest_backup}" && -f "${latest_backup}" ]]; then
    printf 'Latest backup: %s\n' "${latest_backup}"
  else
    echo "Latest backup: missing"
  fi
else
  echo "Safety backup directory is missing"
fi

section "Obsidian Vault"
print_obsidian_git_summary
echo
print_codex_sync_summary

section "GPU"
run_maybe_root nvidia-smi || true
echo
cat /proc/driver/nvidia/version 2>/dev/null || true
echo
printf 'NVML PCIe snapshot: '
nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,pstate,utilization.gpu --format=csv,noheader 2>/dev/null | head -n1 || true
printf 'sysfs current='
cat /sys/bus/pci/devices/0000:01:00.0/current_link_speed 2>/dev/null || true
printf 'sysfs width='
cat /sys/bus/pci/devices/0000:01:00.0/current_link_width 2>/dev/null || true
printf 'sysfs max='
cat /sys/bus/pci/devices/0000:01:00.0/max_link_speed 2>/dev/null || true
printf 'sysfs max width='
cat /sys/bus/pci/devices/0000:01:00.0/max_link_width 2>/dev/null || true
echo
journalctl -k -b --no-pager | rg -i 'nvrm: xid|flip event timeout|lost display notification|error while waiting for gpu progress' || true

section "Hyprland Runtime Logs"
runtime_hypr="/run/user/$(id -u "${owner_user}")/hypr"
archive_hypr="${owner_home}/__home_organized/logs/hyprland-runtime"
if [[ -d "${runtime_hypr}" ]]; then
  du -sh "${runtime_hypr}" 2>/dev/null || true
  find "${runtime_hypr}" -maxdepth 2 -type f -name 'hyprland.log' -printf '%b blocks %s bytes %p\n' 2>/dev/null | sort -n || true
else
  echo "Hyprland runtime directory is missing"
fi
echo
if [[ -d "${archive_hypr}" ]]; then
  du -sh "${archive_hypr}" 2>/dev/null || true
  find "${archive_hypr}" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %9s %f\n' 2>/dev/null | sort | tail -n 12 || true
else
  echo "Hyprland archive directory is missing"
fi

section "Journal Errors"
journalctl -p 3 -b --no-pager | tail -n 80 || true

ln -sfn "${report}" "${latest}"
find "${log_dir}" -maxdepth 1 -type f -name 'system-self-check-*.log' | sort -r | awk "NR>${max_logs}" | xargs -r rm -f
chown -R "${owner_user}:${owner_user}" "${log_dir}"
printf '\nReport saved to %s\n' "${report}"
