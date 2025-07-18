#!/bin/bash

# Iterate over all first-level directories and run git pull if it's a git repository
for dir in */; do
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        git pull origin main
        cd ..
    fi
done