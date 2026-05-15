#!/usr/bin/env bash
set -euo pipefail

owner_user="${SUDO_USER:-goringich}"
owner_home="$(getent passwd "${owner_user}" | cut -d: -f6)"
log_dir="${owner_home}/__home_organized/logs"
max_logs=20
mkdir -p "${log_dir}"
ts="$(date '+%F_%H-%M-%S')"
report="${log_dir}/post-update-safety-${ts}.log"
latest="${log_dir}/post-update-safety-latest.log"

exec > >(tee "${report}") 2>&1

echo "=== Post Update Safety Check ==="
date --iso-8601=seconds
echo
echo "=== Recent Pacman Transactions ==="
tail -n 80 /var/log/pacman.log || true
echo
echo "=== Kernels / NVIDIA ==="
pacman -Q | rg '^(linux|linux-cachyos|linux-cachyos-lts|nvidia|lib32-nvidia|opencl-nvidia|egl-wayland|egl-gbm)' || true
echo
bash "${owner_home}/__home_organized/scripts/system-safety-backup.sh" || true
echo
bash "${owner_home}/__home_organized/scripts/system-self-check.sh" || true
ln -sfn "${report}" "${latest}"
chown -R "${owner_user}:${owner_user}" "${log_dir}"
find "${log_dir}" -maxdepth 1 -type f -name 'post-update-safety-*.log' | sort -r | awk "NR>${max_logs}" | xargs -r rm -f
