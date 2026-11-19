#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if command -v cygpath >/dev/null 2>&1; then
  REPO_ROOT_GODOT="$(cygpath -w "$REPO_ROOT")"
else
  REPO_ROOT_GODOT="$REPO_ROOT"
fi

resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    if [[ -x "$GODOT_BIN" || -f "$GODOT_BIN" ]]; then
      printf '%s\n' "$GODOT_BIN"
      return 0
    fi
    echo "GODOT_BIN definido, mas nao encontrado: $GODOT_BIN" >&2
    return 1
  fi

  for candidate in godot godot4; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  for fallback in \
    "/c/Users/gabri/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
    "/mnt/c/Users/gabri/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"; do
    if [[ -f "$fallback" ]]; then
      printf '%s\n' "$fallback"
      return 0
    fi
  done

  echo "Binario do Godot 4.7 nao encontrado. Defina GODOT_BIN ou adicione 'godot' ao PATH." >&2
  return 1
}

run_step() {
  local label="$1"
  shift
  echo ""
  echo "=== $label ==="

  local tmp_log
  tmp_log="$(mktemp)"
  set +e
  "$GODOT_EXE" "$@" >"$tmp_log" 2>&1
  local rc=$?
  set -e

  cat "$tmp_log"
  if [[ $rc -ne 0 ]]; then
    rm -f "$tmp_log"
    echo "$label falhou com codigo de saida $rc." >&2
    exit "$rc"
  fi
  if grep -Eq "SCRIPT ERROR:|Parse Error:|ObjectDB instance was leaked" "$tmp_log"; then
    rm -f "$tmp_log"
    echo "$label apresentou erro de script ou vazamento de memoria (ObjectDB)." >&2
    exit 1
  fi
  rm -f "$tmp_log"
}

GODOT_EXE="$(resolve_godot)"
echo "Godot: $GODOT_EXE"
echo "Projeto: $REPO_ROOT"

if [[ ! -f "$REPO_ROOT/.godot/global_script_class_cache.cfg" ]]; then
  run_step "0. Importacao inicial de classes/UIDs" --headless --import --path "$REPO_ROOT_GODOT"
fi

run_step "1/3 Suite GUT (tests/)" \
  --headless --path "$REPO_ROOT_GODOT" -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

run_step "2/3 Validacao de layout UI (test_ui_layout.gd)" \
  --headless --path "$REPO_ROOT_GODOT" -s res://scenes/ui/test_ui_layout.gd

run_step "3/3 Smoke test Main.tscn (600 frames)" \
  --headless --path "$REPO_ROOT_GODOT" --quit-after 600

echo ""
echo "ALL CHECKS PASSED"
