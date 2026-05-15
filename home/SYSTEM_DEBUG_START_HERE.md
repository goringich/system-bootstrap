# System Debug Start Here

If a new Codex session or a human starts debugging this machine, begin here.

## First Command

```bash
system-diagnose
```

This writes a full report to:

- `~/__home_organized/logs/system-self-check-latest.log`

## Primary Notes

- `Desktop/Obsidian/System/System Recovery Runbook.md`
- `Desktop/Obsidian/System/Desktop Incident Pipeline 2026-03-28.md`
- `Desktop/Obsidian/System/System Hardening 2026-03-10.md`
- `Desktop/Obsidian/System/Safety Layers 2026-03-10.md`
- `Desktop/Obsidian/System/System Health/index.md`
- `Desktop/Obsidian/System/GPU Health/index.md`
- `Desktop/Obsidian/codex-conversations/index.md`

## Fastest Path To Root Cause

1. Run:

```bash
system-diagnose
~/__home_organized/scripts/system-issues-report.sh --compact
```

2. If `latest bundle` is present in the report:

- open its `summary.md` first
- treat that bundle as the narrow evidence boundary for the incident
- only then drill into raw `journalctl`

3. If `latest bundle` is missing but the boot looks suspicious:

```bash
~/__home_organized/scripts/capture-desktop-incident.sh --mode=auto --force
~/__home_organized/scripts/system-issues-report.sh --compact
```

4. After that:

- update or create the dedicated incident note in `Desktop/Obsidian/System/`
- link the bundle path inside the note
- separate direct evidence from inference

## Documentation Rules For New Debug Sessions

- Do not stop at a symptom summary.
- Always create or update a dedicated incident note in `Desktop/Obsidian/System/` for the current event.
- Prefer a separate note even if a previous incident exists, then cross-link them.
- For every serious GUI or GPU incident, document:
  - failing boot ID
  - recovery boot ID
  - exact timestamps for first failure, relogin attempts, reboot, and first clean session
  - what crashed first
  - what only failed downstream
  - what was explicitly absent or blocked
  - why recovery happened after reboot or relogin
- Always compare:
  - failing boot
  - immediate relogin in the same boot, if it happened
  - first clean boot after reboot
- Explicitly distinguish:
  - direct evidence from logs
  - inference
  - mitigation applied
  - verification still pending
- If you propose a fix, state the narrow trigger surface first and avoid shotgun changes.
- Prefer the latest incident bundle over broad whole-journal rereads when evidence is already captured.
- Record the exact bundle path used for the conclusion.

## Safety And Verification Commands

```bash
~/__home_organized/scripts/capture-desktop-incident.sh --mode=auto --force
~/__home_organized/scripts/system-issues-report.sh --compact
~/__home_organized/scripts/tests/desktop-incident-pipeline-selftest.sh
```

## Current Stable Baseline

- Default stable boot path: `linux-cachyos-lts`
- Persistent journald enabled
- Monthly Btrfs scrub enabled
- `gpu-watchdog.timer` enabled
- `system-watchdog.timer` enabled
- `codex-obsidian-sync.timer` enabled
- daily `system-safety-backup.timer` enabled
- pacman post-update safety audit hook enabled
- safety retention is intentionally bounded to avoid clutter and background load

## Safety Commands

```bash
system-diagnose
~/__home_organized/scripts/system-safety-restore.sh list
~/__home_organized/scripts/system-safety-restore.sh verify latest
~/__home_organized/scripts/system-safety-restore.sh extract latest
~/__home_organized/scripts/system-issues-report.sh --compact
```

## What Not To Misdiagnose

- Idle `PCIe Gen1` on NVIDIA is not automatically a fault here.
- On this machine the GPU link can downshift in idle and raise under load.
- Prefer checking `nvidia-smi` and a short real load before concluding PCIe is broken.
- `sysfs max_link_speed` is device capability, not necessarily the practical negotiated runtime ceiling.
- For current NVIDIA runtime interpretation, prefer:
  - `nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max`
  - then compare that with real load and current `pstate`
