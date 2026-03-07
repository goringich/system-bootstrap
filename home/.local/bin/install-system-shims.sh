#!/usr/bin/env bash
set -euo pipefail

install_shim() {
  local name="$1"; shift
  local body="$*"
  echo "Installing /usr/local/bin/${name}"
  printf '%s
' "${body}" | sudo tee "/usr/local/bin/${name}" >/dev/null
  sudo chmod +x "/usr/local/bin/${name}"
}

common_has_opts='set -euo pipefail
has_opts=false
for a in "$@"; do
  case "$a" in
    -*) has_opts=true; break;;
  esac
done'

install_shim df "#!/usr/bin/env bash
${common_has_opts}
DF_BIN=\${DF_BIN:-/usr/bin/df}
if command -v duf >/dev/null 2>&1 && [ \"$has_opts\" = false ]; then
  exec duf \"$@\"
else
  exec \"$DF_BIN\" \"$@\"
fi"

install_shim du "#!/usr/bin/env bash
${common_has_opts}
DU_BIN=\${DU_BIN:-/usr/bin/du}
if command -v dust >/dev/null 2>&1 && [ \"$has_opts\" = false ]; then
  exec dust \"$@\"
else
  exec \"$DU_BIN\" \"$@\"
fi"

install_shim ls "#!/usr/bin/env bash
${common_has_opts}
LS_BIN=\${LS_BIN:-/usr/bin/ls}
if command -v eza >/dev/null 2>&1 && [ \"$has_opts\" = false ]; then
  exec eza \"$@\"
else
  exec \"$LS_BIN\" \"$@\"
fi"

install_shim cat "#!/usr/bin/env bash
${common_has_opts}
CAT_BIN=\${CAT_BIN:-/usr/bin/cat}
if command -v bat >/dev/null 2>&1 && [ \"$has_opts\" = false ]; then
  exec bat --paging=never --style=plain \"$@\"
else
  exec \"$CAT_BIN\" \"$@\"
fi"

install_shim grep "#!/usr/bin/env bash
${common_has_opts}
GREP_BIN=\${GREP_BIN:-/usr/bin/grep}
if command -v rg >/dev/null 2>&1 && [ \"$has_opts\" = false ]; then
  exec rg --color=never \"$@\"
else
  exec \"$GREP_BIN\" \"$@\"
fi"

cat <<'TIP'
Done. These shims will also apply under sudo (since /usr/local/bin precedes /usr/bin).
TIP
