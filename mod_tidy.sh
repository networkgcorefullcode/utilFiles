#!/bin/bash

export PATH=$PATH:$HOME/go/bin

# iterate over all first-level directories and run go mod tidy
for dir in */; do
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        go mod tidy
        cd ..
    fi
done