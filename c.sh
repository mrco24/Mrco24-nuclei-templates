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

    if [[ "$repo" == *"gist.github.com"* ]]; then
      echo "⚠ Skipping Gist - $repo"
      continue
    fi

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

    echo "🧹 Cleaning $folder ..."
    cd "$folder" || continue

    mkdir -p __yaml_temp__
    find . -type f \( -iname "*.yaml" -o -iname "*.yml" \) -exec cp --parents {} __yaml_temp__ \;
    find . ! -path "./__yaml_temp__*" -delete
    cp -r __yaml_temp__/* .
    rm -rf __yaml_temp__

    cd ..
  done < "../$REPO_FILE"
}

# ---------------------------------------
# Function: Remove Duplicate YAML Files
# ---------------------------------------
deduplicate_yaml() {
  echo "🧼 Starting duplicate YAML removal..."

  for repo_dir in */; do
    cd "$repo_dir" || continue

    echo "🔍 Checking folder: $repo_dir"

    declare -A checksums=()
    duplicates_found=false

    while IFS= read -r file; do
      checksum=$(md5sum "$file" | awk '{print $1}')
      if [[ -n "${checksums[$checksum]}" ]]; then
        echo "❌ Duplicate removed: $file (same as ${checksums[$checksum]})"
        rm "$file"
        duplicates_found=true
      else
        checksums[$checksum]="$file"
      fi
    done < <(find . -type f \( -iname "*.yaml" -o -iname "*.yml" \))

    if [[ "$duplicates_found" = false ]]; then
      echo "✅ No duplicates found in $repo_dir"
    fi

    unset checksums
    cd ..
  done

  echo "✅ Duplicate removal complete."
}

# ---------------------------------------
# Execute Actions
# ---------------------------------------
$CLONE && clone_repos
$DEDUPLICATE && deduplicate_yaml
