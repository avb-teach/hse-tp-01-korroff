#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 INPUT_DIR OUTPUT_DIR [--max_depth N | --max-depth N]"
  exit 1
}

# Check basic parameters
if [[ $# -lt 2 || $# -gt 4 ]]; then
  usage
fi

#Проверка

# Parse positional arguments
input_dir="$1"
output_dir="$2"
shift 2

# Parse optional --max-depth or --max_depth option (can be before or after positional args)
max_depth=

# Check for prefix option: --max_depth/--max-depth N before positional args
if [[ $# -ge 4 ]] && { [[ "$1" == "--max_depth" ]] || [[ "$1" == "--max-depth" ]]; }; then
  if ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo "Error: depth must be a non-negative integer"
    exit 1
  fi
  max_depth="$2"
  shift 2
fi

# Check for postfix option: --max_depth/--max-depth N after positional args
if [[ $# -eq 4 ]] && { [[ "${3}" == "--max_depth" ]] || [[ "${3}" == "--max-depth" ]]; }; then
  if ! [[ "${4}" =~ ^[0-9]+$ ]]; then
    echo "Error: depth must be a non-negative integer"
    exit 1
  fi
  max_depth="${4}"
  # Remove option args
  set -- "$1" "$2"
fi

# Now expect exactly two args: INPUT_DIR and OUTPUT_DIR
if [[ $# -ne 2 ]]; then
  usage
fi

# Assign positional args
input_dir="$1"
output_dir="$2"
# End of argument parsing

# Validate input directory
if [[ ! -d "$input_dir" ]]; then
  echo "Error: input directory '$input_dir' does not exist or is not a directory"
  exit 1
fi

# Create output directory if needed
mkdir -p "$output_dir"

copy_with_rename() {
  local src="$1"
  local filename base ext target n
  filename=$(basename "$src")
  # split base and extension
  if [[ "$filename" == *.* && "${filename%%.*}" != "$filename" ]]; then
    base="${filename%.*}"
    ext=".${filename##*.}"
  else
    base="$filename"
    ext=""
  fi

  target="$output_dir/$filename"
  if [[ -e "$target" ]]; then
    n=1
    while [[ -e "$output_dir/${base}-${n}${ext}" ]]; do
      ((n++))
    done
    cp "$src" "$output_dir/${base}-${n}${ext}"
  else
    cp "$src" "$output_dir/$filename"
  fi
}

# Find and copy files, using process-substitution for portability
if [[ -n "$max_depth" ]]; then
  while IFS= read -r -d '' file; do
    copy_with_rename "$file"
  done < <(find "$input_dir" -maxdepth "$max_depth" -type f -print0)
else
  while IFS= read -r -d '' file; do
    copy_with_rename "$file"
  done < <(find "$input_dir" -type f -print0)
fi

echo "All files have been copied to '$output_dir'" 