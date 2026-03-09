#!/usr/bin/env bash
# export-elf — copy the newest .elf from a build dir to a Windows folder
# Usage:
#   export-elf [--from DIR] [DEST]
#   - If DEST is omitted, it uses your preset Windows folder.
#   - DEST can be Windows path (e.g., C:\Users\Apollo\...) or WSL path (/mnt/c/...).
#   - --from DIR sets where to search for .elf (default: current directory).

set -euo pipefail

search_dir="$PWD"
dest_arg=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      [[ $# -ge 2 ]] || { echo "ERROR: --from needs a directory"; exit 1; }
      search_dir="$2"; shift 2;;
    -*)
      echo "Unknown option: $1"; exit 1;;
    *)
      dest_arg="$1"; shift;;
  esac
done

# --- Find the newest .elf ---
latest_elf="$(find "$search_dir" -type f -name '*.elf' -print0 | xargs -0r ls -t 2>/dev/null | head -n1 || true)"
if [[ -z "${latest_elf}" ]]; then
  echo "ERROR: No .elf found under: $search_dir"
  exit 1
fi

# --- Convert Windows path to WSL path ---
to_wsl_path() {
  local p="$1"
  if [[ "$p" =~ ^[A-Za-z]:\\ ]]; then
    wslpath -u "$p"
  else
    echo "$p"
  fi
}

# --- Decide destination folder ---
if [[ -z "$dest_arg" ]]; then
  # 預設路徑：C:\Users\Apollo\Desktop\NYCU\semester5\mpd\elf_export
  dest_dir="$(to_wsl_path 'C:\Users\Apollo\Desktop\NYCU\semester5\mpd\elf_export')"
else
  dest_dir="$(to_wsl_path "$dest_arg")"
fi

mkdir -p "$dest_dir"

# --- Copy ---
cp -f "$latest_elf" "$dest_dir/"

dst_file="$dest_dir/$(basename "$latest_elf")"
dst_win="$(wslpath -w "$dst_file")"

echo "Source : $latest_elf"
echo "Copied → $dst_file"
echo "Windows: $dst_win"
