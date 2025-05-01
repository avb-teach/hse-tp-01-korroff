#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Trap Ctrl-C
trap 'echo "\nInterrupted by user." >&2; exit 1' INT

# Print usage and exit
usage() {
  cat <<EOF >&2
Usage: $0 [--max_depth N|--max-depth N] INPUT_DIR OUTPUT_DIR

Copy all files from INPUT_DIR (and its subdirectories) into OUTPUT_DIR
as a flat list (no directory hierarchy).

Options:
  --max_depth N, --max-depth N   Limit recursion to N levels (0 = only root). Default is unlimited.
  -h, --help                     Show this help message and exit.
EOF
  exit 1
}

# Default max depth is unlimited (empty)
max_depth=
declare -a positional=()

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --max_depth|--max-depth)
      if [[ $# -lt 2 ]]; then
        echo "Error: missing value for $1" >&2
        usage
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: max_depth must be a non-negative integer" >&2
        exit 1
      fi
      max_depth=$2
      shift 2
      ;;
    --*)
      echo "Error: unknown option '$1'" >&2
      usage
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

# Require exactly two positional args
if [[ ${#positional[@]} -ne 2 ]]; then
  usage
fi
input_dir=${positional[0]}
output_dir=${positional[1]}

# Resolve to absolute paths if realpath available
if command -v realpath &>/dev/null; then
  input_dir=$(realpath -- "$input_dir")
  output_dir=$(realpath -m -- "$output_dir")
fi

# Validate input directory
if [[ ! -d "$input_dir" ]]; then
  echo "Error: input directory '$input_dir' does not exist or is not a directory" >&2
  exit 1
fi

# Prevent copying into itself or into subdirectory
if [[ "$input_dir" == "$output_dir" ]]; then
  echo "Error: input and output directories must be different" >&2
  exit 1
fi
if [[ "$output_dir" == "$input_dir"/* ]]; then
  echo "Error: output directory '$output_dir' is inside input directory '$input_dir'" >&2
  exit 1
fi

# Create output directory if needed
mkdir -p -- "$output_dir"

# Prepare associative array for name collisions
declare -A seen=()

# Function to copy file with rename on collision
copy_with_rename() {
  local src="$1"
  local filename base ext key count newname

  filename=$(basename -- "$src")
  # Split base and extension
  if [[ "$filename" == *.* && "${filename%%.*}" != "$filename" ]]; then
    base="${filename%.*}"
    ext=".${filename##*.}"
  else
    base="$filename"
    ext=""
  fi

  key="$filename"
  count=${seen["$key"]:-0}
  ((seen["$key"]=count+1))

  if (( count > 0 )); then
    newname="${base}-${count}${ext}"
  else
    newname="$filename"
  fi

  cp -p -- "$src" "$output_dir/$newname"
}

# Build find command arguments
find_args=("$input_dir")
if [[ -n "$max_depth" ]]; then
  # Apply max_depth directly to find's -maxdepth
  find_args+=( -maxdepth "$max_depth" )
fi
find_args+=( -type f -print0 )

# Traverse and copy files (informational output goes to stderr)
echo "Starting copy from '$input_dir' to '$output_dir'..." >&2
count=0
while IFS= read -r -d '' file; do
  copy_with_rename "$file"
  ((count++))
done < <(find "${find_args[@]}")

echo "Done: copied $count files." >&2 