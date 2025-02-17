#!/bin/bash

# Function to remove files and directories
remove_files() {
    local path=$1
    if [ -d "$path" ]; then
        echo "Removing directory: $path"
        sudo rm -rf "$path"
    elif [ -f "$path" ]; then
        echo "Removing file: $path"
        sudo rm -f "$path"
    fi
}

# Get the installation prefix
PREFIX=$(llvm-config --prefix)
BINDIR=$(llvm-config --bindir)
INCLUDEDIR=$(llvm-config --includedir)
LIBDIR=$(llvm-config --libdir)
SHAREDIR=$(llvm-config --sharedir)
CMAKE_DIR=$(llvm-config --cmakedir)

# Remove files and directories
remove_files "$BINDIR"
remove_files "$INCLUDEDIR"
remove_files "$LIBDIR"
remove_files "$SHAREDIR"
remove_files "$CMAKE_DIR"

# Remove the prefix directory if it's empty
if [ -d "$PREFIX" ]; then
    if [ -z "$(ls -A $PREFIX)" ]; then
        echo "Removing empty directory: $PREFIX"
        sudo rmdir "$PREFIX"
    else
        echo "Directory $PREFIX is not empty, not removing."
    fi
fi

echo "LLVM files have been removed."
