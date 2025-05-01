#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 INPUT_DIR OUTPUT_DIR [--max_depth N]"
  exit 1
}

# Check basic parameters
if [[ $# -lt 2 || $# -gt 4 ]]; then
  usage
fi

input_dir=$1
output_dir=$2
shift 2

# Parse optional --max_depth
max_depth=
if [[ $# -eq 2 && $1 == --max_depth ]]; then
  if ! [[ $2 =~ ^[0-9]+$ ]]; then
    echo "Error: depth must be a non-negative integer"
    exit 1
  fi
  max_depth=$2
elif [[ $# -ne 0 ]]; then
  usage
fi

# Validate input directory
if [[ ! -d $input_dir ]]; then
  echo "Error: input directory '$input_dir' does not exist or is not a directory"
  exit 1
fi

# Create output directory if needed
mkdir -p "$output_dir"

copy_with_depth() {
  local src="$1"
  local rel_path="${src#$input_dir/}"
  local target_dir="$output_dir"
  
  # If max_depth is specified, calculate relative path components
  if [[ -n $max_depth ]]; then
    IFS='/' read -ra parts <<< "$rel_path"
    local depth=$(( ${#parts[@]} - 1 ))
    
    # If file is deeper than max_depth, skip it
    if [[ $depth -gt $max_depth ]]; then
      return
    fi
    
    # Reconstruct target path with limited depth
    target_dir="$output_dir"
    for (( i=0; i<depth; i++ )); do
      target_dir="$target_dir/${parts[$i]}"
    done
    mkdir -p "$target_dir"
  fi
  
  local filename=$(basename "$src")
  cp "$src" "$target_dir/$filename"
}

# Find and copy files
if [[ -n $max_depth ]]; then
  find "$input_dir" -type f -print0 | while IFS= read -r -d '' file; do
    copy_with_depth "$file"
  done
else
  # Flat copy if no max_depth specified
  find "$input_dir" -type f -print0 | while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    # Handle duplicate filenames
    n=1
    base="${filename%.*}"
    ext="${filename##*.}"
    if [[ "$ext" == "$filename" ]]; then
      ext=""
    else
      ext=".$ext"
    fi
    
    target="$output_dir/$filename"
    while [[ -e "$target" ]]; do
      target="$output_dir/${base}-${n}${ext}"
      ((n++))
    done
    cp "$file" "$target"
  done
fi

echo "Operation completed successfully"