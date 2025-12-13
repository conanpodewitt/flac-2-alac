#!/usr/bin/env zsh

# Exit early on errors and treat unset vars as failure to avoid silent bugs.
set -euo pipefail
setopt nullglob

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <flac-source-dir> <alac-destination-dir>"
  exit 1
fi

src_dir=$1
dst_dir=$2

if [[ ! -d $src_dir ]]; then
  echo "Source directory does not exist: $src_dir"
  exit 2
fi

mkdir -p "$dst_dir"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required but not installed."
  exit 3
fi

# Pick the first cover file that matches common extensions. I don't think GIFs will play, but rather just act as a static image once embedded.
image_file=""
for candidate in "$src_dir"/*.jpg "$src_dir"/*.jpeg "$src_dir"/*.png "$src_dir"/*.gif; do
  [[ -f "$candidate" ]] && image_file=$candidate && break
done

convert_flac() {
  local flac_file=$1
  local base_name
  base_name=$(basename "$flac_file" .flac)
  local output_file="$dst_dir/$base_name.m4a"

  if [[ -n $image_file ]]; then
    ffmpeg -y -i "$flac_file" -i "$image_file" \
      -map 0:a -map 1 \
      -c:a alac -c:v copy \
      -disposition:v attached_pic \
      -metadata:s:v title="Album cover" \
      -metadata:s:v comment="Cover (front)" \
      "$output_file"
  else
    ffmpeg -y -i "$flac_file" -c:a alac "$output_file"
  fi
}

flac_files=()
for flac in "$src_dir"/*.flac; do
  [[ -f "$flac" ]] && flac_files+=("$flac")
done

flac_files=("${(@o)flac_files}")

if [[ ${#flac_files} -eq 0 ]]; then
  echo "No FLAC files found in $src_dir"
  exit 4
fi

for flac_file in "${flac_files[@]}"; do
  convert_flac "$flac_file"
done