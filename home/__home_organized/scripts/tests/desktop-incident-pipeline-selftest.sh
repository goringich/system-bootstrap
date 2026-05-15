#!/usr/bin/env bash
set -euo pipefail

script_root="/home/goringich/__home_organized/scripts"
capture_script="${script_root}/capture-desktop-incident.sh"
report_script="${script_root}/system-issues-report.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

export HOME="${tmpdir}/home"
mkdir -p "${HOME}/__home_organized/logs" \
  "${HOME}/Desktop/Obsidian/System" \
  "${HOME}/.local/state/session-startup-guard" \
  "${HOME}/.local/state/gpu-watchdog" \
  "${HOME}/.local/state/system-watchdog"

cat > "${HOME}/.local/state/session-startup-guard/state.env" <<'EOF'
SAFE_MODE='1'
SAFE_REASON='current boot detected dirty journal recovery'
EOF

cat > "${HOME}/.local/state/gpu-watchdog/quarantine.env" <<'EOF'
GPU_QUARANTINE='0'
GPU_QUARANTINE_REASON='n/a'
EOF

cat > "${HOME}/.local/state/system-watchdog/state.env" <<'EOF'
prev_status='degraded'
prev_reason='previous boot ended with Hyprland/GPU crash signals'
EOF

printf 'session guard tail\n' > "${HOME}/__home_organized/logs/session-startup-guard.log"
printf 'gpu watchdog tail\n' > "${HOME}/__home_organized/logs/gpu-health.log"
printf 'system watchdog tail\n' > "${HOME}/__home_organized/logs/system-health.log"

fakebin="${tmpdir}/fakebin"
mkdir -p "${fakebin}"
export PATH="${fakebin}:${PATH}"

cat > "${fakebin}/journalctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [[ "${args}" == *"--list-boots"* ]]; then
  cat <<'OUT'
-1 boot-prev previous
 0 boot-current current
OUT
  exit 0
fi
if [[ "${args}" == *"-b -1"* ]]; then
  cat <<'OUT'
Mar 28 15:02:27 host kernel: NVRM: Xid (PCI:0000:01:00): 31, pid=2817, name=Hyprland, MMU Fault
Mar 28 15:02:32 host systemd-coredump[1]: Process 2817 (Hyprland) terminated abnormally with signal 6/ABRT, processing...
Mar 28 15:02:32 host systemd-coredump[1]: Process 3001 (xdg-desktop-portal-hyprland) dumped core.
OUT
  exit 0
fi
if [[ "${args}" == *"-b 0"* ]]; then
  cat <<'OUT'
Mar 28 15:06:54 host systemd-journald[1]: /var/log/journal/xxx/system.journal: Journal file uses a different sequence number ID, rotating.
Mar 28 15:06:54 host systemd-journald[1]: Journal file /var/log/journal/xxx/system.journal is corrupted or uncleanly shut down, renaming and replacing.
Mar 28 15:07:01 host dbus-broker-launch[1]: Ignoring duplicate name 'org.freedesktop.FileManager1' in service file '/usr/share/dbus-1/services/org.freedesktop.FileManager1.service'
OUT
  exit 0
fi
exit 0
EOF
chmod +x "${fakebin}/journalctl"

cat > "${fakebin}/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${fakebin}/systemctl"

cat > "${fakebin}/pacman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
hyprland 0.53.3-2
aquamarine 0.10.0-2.1
hyprgraphics 0.5.0-2
hyprutils 0.11.1-1
xdg-desktop-portal-hyprland 1.3.11-3.1
nvidia-utils 590.48.01-6
linux-cachyos-lts-nvidia-open 6.18.16-1
OUT
EOF
chmod +x "${fakebin}/pacman"

cat > "${fakebin}/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"--query-gpu="* ]]; then
  printf '4, 4, 16, 16, P8, 7 %%\n'
else
  printf 'NVIDIA-SMI 590.48.01\n'
fi
EOF
chmod +x "${fakebin}/nvidia-smi"

cat > "${fakebin}/coredumpctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
Fri 2026-03-28 15:02:32 MSK 2817 1000 1000 SIGABRT present /usr/bin/Hyprland
OUT
EOF
chmod +x "${fakebin}/coredumpctl"

"${capture_script}" --mode=recovery --force

latest_env="${HOME}/.local/state/desktop-incident-capture/latest_bundle.env"
[[ -f "${latest_env}" ]] || {
  printf 'latest bundle env was not created\n' >&2
  exit 1
}

# shellcheck disable=SC1090
source "${latest_env}"
[[ -n "${LATEST_BUNDLE:-}" && -d "${LATEST_BUNDLE}" ]] || {
  printf 'bundle dir is missing\n' >&2
  exit 1
}

summary_file="${LATEST_BUNDLE}/summary.md"
[[ -f "${summary_file}" ]] || {
  printf 'bundle summary is missing\n' >&2
  exit 1
}

rg -q 'Kind: `recovery-after-previous-boot`' "${summary_file}" || {
  printf 'summary does not contain recovery kind\n' >&2
  exit 1
}
rg -q 'NVRM: Xid' "${LATEST_BUNDLE}/previous-boot-incidents.log" || {
  printf 'previous boot incident log does not contain Xid evidence\n' >&2
  exit 1
}

report_output="$("${report_script}" --compact)"
printf '%s\n' "${report_output}" | rg -q 'latest bundle[[:space:]]+recovery-after-previous-boot' || {
  printf 'report did not expose latest bundle kind\n' >&2
  exit 1
}
printf '%s\n' "${report_output}" | rg -q 'Latest incident bundle: .*/system-incidents/' || {
  printf 'report did not expose latest bundle path\n' >&2
  exit 1
}
printf '%s\n' "${report_output}" | rg -q 'Start with .*/summary\.md before reading raw journal again\.' || {
  printf 'report did not point to bundle summary\n' >&2
  exit 1
}

printf 'desktop incident pipeline self-test: ok\n'
