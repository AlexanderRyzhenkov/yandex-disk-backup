#!/usr/bin/env bash
set -euo pipefail
umask 077

info() { printf '[INFO] %s\n' "$*"; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: bash backup.sh [--init | --help]

Download a local copy of Yandex Disk without uploading local changes.
  --init   Authorize and create a new local client configuration.
  --help   Show this help.

Environment settings:
  YADISK_CONF_DIR      Credentials directory (default: .yadisk_conf).
  YADISK_LOCAL_DIR     Download directory (default: yandex-disk).
  YADISK_EXCLUDE_DIRS  Comma-separated remote directories to exclude.

Relative paths are resolved against the script directory.
EOF
}

[[ $# -le 1 ]] || die 'Expected at most one argument. Use --help.'
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --init|'') ;;
  *) die "Unknown argument: $1. Use --help." ;;
esac

command -v yandex-disk >/dev/null 2>&1 || die 'Install the Yandex Disk Linux console client first.'
command -v realpath >/dev/null 2>&1 || die 'Install GNU coreutils (realpath) first.'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONF_DIR="${YADISK_CONF_DIR:-.yadisk_conf}"
LOCAL_DIR="${YADISK_LOCAL_DIR:-yandex-disk}"
[[ "$CONF_DIR" = /* ]] || CONF_DIR="$SCRIPT_DIR/$CONF_DIR"
[[ "$LOCAL_DIR" = /* ]] || LOCAL_DIR="$SCRIPT_DIR/$LOCAL_DIR"
CONF_DIR="$(realpath -m -- "$CONF_DIR")"
LOCAL_DIR="$(realpath -m -- "$LOCAL_DIR")"
EXCLUDE_DIRS="${YADISK_EXCLUDE_DIRS:-}"

[[ "$CONF_DIR" != / && "$LOCAL_DIR" != / ]] || die 'Do not use the filesystem root as a working directory.'
[[ "$CONF_DIR" != "$LOCAL_DIR" && "$CONF_DIR" != "$LOCAL_DIR/"* && "$LOCAL_DIR" != "$CONF_DIR/"* ]] ||
  die 'Credentials and download directories must not overlap.'

AUTH_FILE="$CONF_DIR/passwd"
CONFIG_FILE="$CONF_DIR/config.cfg"

if [[ "${1:-}" == --init ]]; then
  [[ ! -e "$AUTH_FILE" && ! -L "$AUTH_FILE" && ! -e "$CONFIG_FILE" && ! -L "$CONFIG_FILE" ]] ||
    die 'Configuration or credentials already exist. Use them or select a new YADISK_CONF_DIR.'
  mkdir -p -- "$CONF_DIR"
  info 'Follow the Yandex Disk authorization instructions.'
  yandex-disk token "$AUTH_FILE"
  [[ -s "$AUTH_FILE" ]] || die 'The client did not create a nonempty credentials file.'
  printf 'exclude-dirs=""\n' > "$CONFIG_FILE"
  info 'Initialization complete. Run this script without arguments using the same settings.'
  exit 0
fi

[[ -s "$AUTH_FILE" && -r "$AUTH_FILE" ]] || die 'Credentials are missing or unreadable. Run with --init first.'
[[ -f "$CONFIG_FILE" && -r "$CONFIG_FILE" ]] || die 'Client configuration is missing or unreadable.'
mkdir -p -- "$LOCAL_DIR"

OPTIONS=("--dir=$LOCAL_DIR" "--config=$CONFIG_FILE" "--auth=$AUTH_FILE")
if [[ -n "$EXCLUDE_DIRS" ]]; then
  OPTIONS+=("--exclude-dirs=$EXCLUDE_DIRS")
fi

info "Downloading Yandex Disk to $LOCAL_DIR"
yandex-disk "${OPTIONS[@]}" sync --read-only
info 'Synchronization completed successfully.'
