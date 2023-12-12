#!/bin/bash

# Define the source directory
SOURCE_DIR="./training_data/training_data3"

# Define the destination directories
DEST_DIRS=("split0" "split1" "split2" "split3")

# Create destination directories if they don't exist
for dir in "${DEST_DIRS[@]}"; do
  mkdir -p "$SOURCE_DIR/$dir"
done

# Initialize the directory index
dir_index=0

# Loop over the files and move them to the destination directories
for file in "$SOURCE_DIR"/*; do
  if [[ -f $file ]]; then
    mv "$file" "$SOURCE_DIR/${DEST_DIRS[$dir_index]}"

    # Update directory index for next file
    dir_index=$(( (dir_index + 1) % 4 ))
  fi
done
