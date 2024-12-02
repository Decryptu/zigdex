#!/bin/bash

# Script to remove '.zig-cache' and 'zig-out' directories from the current directory

# Function to remove a directory if it exists
remove_dir_if_exists() {
    local dir=$1
    if [ -d "$dir" ]; then
        echo "Removing directory: $dir"
        rm -rf "$dir"
    else
        echo "Directory does not exist: $dir"
    fi
}

# Call the function for each directory
remove_dir_if_exists ".zig-cache"
remove_dir_if_exists "zig-out"

echo "Clean-up complete."