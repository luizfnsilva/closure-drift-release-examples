#!/usr/bin/env bash
# Builds one scenario repository in $1 and prints the tag to check.
set -euo pipefail
dir=$1; kind=$2
rm -rf "$dir"; mkdir -p "$dir/src"; cd "$dir"
git init -q; git config user.email ci@example.invalid; git config user.name ci
ver() { printf '[project]\nname = "demo"\nversion = "%s"\n' "$1" > pyproject.toml; }
ver 1.0.0; echo 'print(1)' > src/app.py; git add -A; git commit -qm "1.0.0"; git tag v1.0.0
case "$kind" in
  release)        # what python-semantic-release / release-please do: bump and tag on one commit
    echo 'print(2)' > src/app.py; ver 1.1.0; git commit -qam "release 1.1.0"; git tag v1.1.0 ;;
  tag-before-bump) # a hand-made tag on the commit before the bump landed
    echo 'print(2)' > src/app.py; git commit -qam "feature"; git tag v1.1.0
    ver 1.1.0; git commit -qam "bump to 1.1.0" ;;
  insufficient)    # nothing in the repository declares a version
    git rm -q pyproject.toml; echo 'print(2)' > src/app.py; git add -A; git commit -qm "no manifest"; git tag v1.1.0 ;;
esac
echo v1.1.0
