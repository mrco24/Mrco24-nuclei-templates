#!/bin/bash

set -e

REPO_FILE=""
DEDUPLICATE=false
CLONE=false

# Parse flags
while getopts "f:d" opt; do
  case $opt in
    f)
      REPO_FILE="$OPTARG"
      CLONE=true
      ;;
    d)
      DEDUPLICATE=true
      ;;
    *)
      echo "Usage: $0 [-f repo_list.txt] [-d]"
      exit 1
      ;;
  esac
done

# Ensure at least one action is specified
if [[ -z "$REPO_FILE" && "$DEDUPLICATE" = false ]]; then
  echo "❌ No action specified. Use -f to clone or -d to deduplicate."
  exit 1
fi

mkdir -p all_repos
cd all_repos || { echo "❌ Failed to enter directory all_repos"; exit 1; }

# ---------------------------------------
# Function: Clone Repos
# ---------------------------------------
clone_repos() {
  while IFS= read -r repo
  do
    repo=$(echo "$repo" | sed 's/^[-• ]*//' | xargs)
    repo=${repo%/}
    [[ -z "$repo" ]] && continue

    # Skip Gists
    if [[ "$repo" == *"gist.github.com"* ]]; then
      echo "⚠ Skipping Gist - $repo"
      continue
    fi

    # Skip nuclei-templates repos
    if [[ "$repo" == *"nuclei-templates"* ]]; then
      echo "⚠ Skipping nuclei-templates repo - $repo"
      continue
    fi

    # Add .git if missing
    if [[ "$repo" != *.git ]]; then
      repo="${repo}.git"
    fi

    # Unique folder name using hash
    hash=$(echo -n "$repo" | md5sum | cut -d' ' -f1)
    folder=$(basename "$repo" .git)-$hash

    if [[ -d "$folder" ]]; then
      echo "⚠ Already exists: $folder. Skipping clone."
      continue
    fi

    echo "📥 Cloning - $repo ..."
    git clone "$repo" "$folder" || { echo "❌ Failed to clone - $repo"; continue; }

    # No cleaning or YAML-only extraction

  done < "../$REPO_FILE"
}

# ---------------------------------------
# Function: Remove Duplicate YAML Files by Filename Only
# ---------------------------------------
deduplicate_yaml_by_filename() {
  echo "🧼 Starting global duplicate YAML removal based on filename..."

  declare -A filenames_seen=()
  duplicates_found=false

  while IFS= read -r file; do
    filename=$(basename "$file")

    if [[ -n "${filenames_seen[$filename]}" ]]; then
      echo "❌ Removed duplicate filename: $file (same name as ${filenames_seen[$filename]})"
      rm "$file"
      duplicates_found=true
    else
      filenames_seen[$filename]="$file"
    fi
  done < <(find . -type f \( -iname "*.yaml" -o -iname "*.yml" \))

  if [[ "$duplicates_found" = false ]]; then
    echo "✅ No duplicate filenames found."
  fi

  echo "✅ Filename-based duplicate removal complete."
}

# ---------------------------------------
# Execute Actions
# ---------------------------------------
$CLONE && clone_repos
$DEDUPLICATE && deduplicate_yaml_by_filename
