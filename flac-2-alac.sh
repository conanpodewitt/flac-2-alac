#!/usr/bin/env zsh

# Exit early on errors and treat unset vars as failure to avoid silent bugs.
set -euo pipefail
setopt nullglob

# Cleanup function to remove output directory on failure
cleanup_on_failure() {
  if [[ -d "$dst_dir" ]]; then
    rm -rf "$dst_dir"
    echo "Error: Conversion failed. Output directory removed."
  fi
}

trap cleanup_on_failure ERR

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <flac-source-dir> <destination-dir> [--reorg] [--album 'Album Name'] [--year 'Year'] [--genre 'Genre']"
  echo ""
  echo "Modes:"
  echo "  (no flag)   Convert FLAC to ALAC with embedded covers, organized into Artist/Album structure"
  echo "  --reorg     Organize FLAC files and extract embedded covers as separate .jpg files"
  echo ""
  echo "Optional metadata overrides:"
  echo "  --album     Override the album name (extracted from FLAC metadata by default)"
  echo "  --year      Override the year/date (extracted from FLAC metadata by default)"
  echo "  --genre     Override the genre (extracted from FLAC metadata by default)"
  exit 1
fi

src_dir=$1
dst_dir=$2
shift 2

# Parse optional flags
mode_flag=""
custom_album=""
custom_year=""
custom_genre=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --reorg)
      mode_flag="--reorg"
      shift
      ;;
    --album)
      if [[ $# -lt 2 ]]; then
        echo "Error: --album requires a value"
        exit 1
      fi
      custom_album=$2
      shift 2
      ;;
    --year)
      if [[ $# -lt 2 ]]; then
        echo "Error: --year requires a value"
        exit 1
      fi
      custom_year=$2
      shift 2
      ;;
    --genre)
      if [[ $# -lt 2 ]]; then
        echo "Error: --genre requires a value"
        exit 1
      fi
      custom_genre=$2
      shift 2
      ;;
    *)
      echo "Unknown flag: $1"
      exit 1
      ;;
  esac
done

if [[ ! -d $src_dir ]]; then
  echo "Source directory does not exist: $src_dir"
  exit 2
fi

mkdir -p "$dst_dir"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required but not installed."
  exit 3
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is required but not installed."
  exit 3
fi

# Helper function to extract metadata from a FLAC file.
get_metadata() {
  local flac_file=$1
  local tag=$2
  ffprobe -v error -select_streams a:0 -show_entries format_tags="$tag" -of default=noprint_wrappers=1:nokey=1 "$flac_file" 2>/dev/null || echo ""
}

# Helper function to sanitize filenames: replace problematic characters with underscores.
sanitize_filename() {
  local filename=$1
  # Replace problematic characters: / \ : " ' * ? | < > with underscore
  echo "$filename" | sed 's/[/\\:\"'"'"'*?|<>]/_/g'
}

# Helper function to truncate long filenames to fit filesystem limits.
# Max is 255 bytes total, but we need room for track prefix and extension.
truncate_filename() {
  local filename=$1
  local max_length=200  # Leave room for track number prefix and extension
  if [[ ${#filename} -gt $max_length ]]; then
    echo "${filename:0:$max_length}"
  else
    echo "$filename"
  fi
}

# Helper function to extract cover image from a FLAC file.
extract_cover() {
  local flac_file=$1
  local output_dir=$2
  local cover_file="$output_dir/cover.jpg"
  
  # Skip if cover already exists
  [[ -f "$cover_file" ]] && return
  
  # Try to extract embedded cover image from FLAC
  ffmpeg -y -i "$flac_file" -an -vcodec copy "$cover_file" 2>/dev/null || true
  
  # Verify the extracted file is valid
  if [[ -f "$cover_file" ]]; then
    # Check if it's actually an image by trying to read it with ffprobe
    if ! ffprobe -v error "$cover_file" >/dev/null 2>&1; then
      rm "$cover_file"
    fi
  fi
}

# Pick the first cover file that matches common extensions. I don't think GIFs will play, but rather just act as a static image once embedded.
image_file=""
for candidate in "$src_dir"/*.jpg "$src_dir"/*.jpeg "$src_dir"/*.png "$src_dir"/*.gif; do
  [[ -f "$candidate" ]] && image_file=$candidate && break
done

convert_flac() {
  local flac_file=$1
  local mode=$2
  local custom_album=$3
  local custom_year=$4
  local custom_genre=$5
  
  # Extract metadata from FLAC file.
  local artist=$(get_metadata "$flac_file" artist)
  local album=$(get_metadata "$flac_file" album)
  local title=$(get_metadata "$flac_file" title)
  local track=$(get_metadata "$flac_file" track)
  local year=$(get_metadata "$flac_file" date)
  local genre=$(get_metadata "$flac_file" genre)
  
  # Fallback to defaults if metadata is missing.
  artist=${artist:-"Unknown Artist"}
  album=${custom_album:-${album:-"Unknown Album"}}  # Use custom album if provided
  title=${title:-$(basename "$flac_file" .flac)}
  track=${track:-"00"}
  year=${custom_year:-${year:-""}}  # Use custom year if provided
  genre=${custom_genre:-${genre:-""}}  # Use custom genre if provided
  
  # Sanitize and truncate metadata to avoid filesystem issues
  artist=$(sanitize_filename "$artist")
  artist=$(truncate_filename "$artist")
  album=$(sanitize_filename "$album")
  album=$(truncate_filename "$album")
  title=$(sanitize_filename "$title")
  title=$(truncate_filename "$title")
  
  # Extract track number (in case it's "1/8" format, take the first part).
  track=$(echo "$track" | cut -d'/' -f1)
  
  # Zero-pad track number to 2 digits.
  track=$(printf "%02d" "$track" 2>/dev/null || echo "00")
  
  # Create the directory structure: Artist/Album
  local output_dir="$dst_dir/$artist/$album"
  mkdir -p "$output_dir"
  
  # If in reorg mode, organize FLAC, strip artwork, update metadata, and extract cover
  if [[ $mode == "reorg" ]]; then
    local output_file="$output_dir/$track $title.flac"
    # Build ffmpeg metadata flags
    local metadata_flags=()
    [[ -n $custom_album ]] && metadata_flags+=(-metadata "album=$custom_album")
    [[ -n $custom_year ]] && metadata_flags+=(-metadata "date=$custom_year")
    [[ -n $custom_genre ]] && metadata_flags+=(-metadata "genre=$custom_genre")
    
    # Use ffmpeg to copy audio, strip video streams, and update metadata if provided
    ffmpeg -y -i "$flac_file" -c:a copy -vn "${metadata_flags[@]}" "$output_file"
    
    # Try to extract embedded cover, or copy loose cover if it exists
    extract_cover "$flac_file" "$output_dir"
    if [[ -n $image_file ]] && [[ ! -f "$output_dir/cover.jpg" ]]; then
      cp "$image_file" "$output_dir/cover.jpg" || true
    fi
    return
  fi
  
  # Default convert mode: FLAC to ALAC with embedded covers
  local output_file="$output_dir/$track $title.m4a"
  
  # Build metadata flags for ALAC conversion
  local metadata_flags=()
  [[ -n $custom_album ]] && metadata_flags+=(-metadata "album=$custom_album")
  [[ -n $custom_year ]] && metadata_flags+=(-metadata "date=$custom_year")
  [[ -n $custom_genre ]] && metadata_flags+=(-metadata "genre=$custom_genre")

  if [[ -n $image_file ]]; then
    ffmpeg -y -i "$flac_file" -i "$image_file" \
      -map 0:a -map 1 \
      -c:a alac -c:v copy \
      -disposition:v attached_pic \
      -metadata:s:v title="Album cover" \
      -metadata:s:v comment="Cover (front)" \
      "${metadata_flags[@]}" \
      "$output_file"
  else
    ffmpeg -y -i "$flac_file" \
      -map 0:a -map '0:v?' \
      -c:a alac -c:v copy \
      -disposition:v attached_pic \
      "${metadata_flags[@]}" \
      "$output_file"
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

# Determine conversion mode based on flag
conversion_mode="convert"
if [[ $mode_flag == "--reorg" ]]; then
  conversion_mode="reorg"
fi

for flac_file in "${flac_files[@]}"; do
  convert_flac "$flac_file" "$conversion_mode" "$custom_album" "$custom_year" "$custom_genre"
done