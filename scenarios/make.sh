#!/usr/bin/env bash
# make.sh DIR KIND — builds one scenario repository in DIR.
# Prints three lines: the tag to check, extra arguments, and a one-line description of the operation.
set -euo pipefail
dir=$1; kind=$2
rm -rf "$dir"; mkdir -p "$dir/src/demo"; cd "$dir"
git init -q; git config user.email ci@example.invalid; git config user.name ci
ver() { printf '[project]\nname = "demo"\nversion = "%s"\n' "$1" > pyproject.toml; }
ver 1.0.0; printf '__version__ = "1.0.0"\n' > src/demo/__init__.py; echo 'print(1)' > src/demo/app.py
git add -A; git commit -qm "1.0.0"; git tag v1.0.0
extra=""
case "$kind" in
  normal)           # release tool: bump and tag on one commit
    echo 'print(2)' > src/demo/app.py; ver 1.1.0; printf '__version__ = "1.1.0"\n' > src/demo/__init__.py
    git commit -qam "release 1.1.0"; git tag v1.1.0
    op="bump to 1.1.0 and tag v1.1.0 on the same commit" ;;
  tag-before-bump)  # same flow, but someone tags by hand before the bump commit
    echo 'print(2)' > src/demo/app.py; git commit -qam "feature"; git tag v1.1.0
    ver 1.1.0; printf '__version__ = "1.1.0"\n' > src/demo/__init__.py; git commit -qam "bump to 1.1.0"
    op="tag v1.1.0 by hand on the commit before the bump; the bump lands after" ;;
  tag-moved)        # the tag is deleted and recreated on a later commit that declares the same version
    echo 'print(2)' > src/demo/app.py; ver 1.1.0; printf '__version__ = "1.1.0"\n' > src/demo/__init__.py
    git commit -qam "release 1.1.0"; git tag v1.1.0
    echo 'print(3)' > src/demo/app.py; git commit -qam "hotfix"; git tag -f v1.1.0 >/dev/null
    op="v1.1.0 recreated on a later commit with other code; the old tag is gone from history" ;;
  other-file)       # the release tool bumps pyproject.toml but not __init__.py
    echo 'print(2)' > src/demo/app.py; ver 1.1.0; git commit -qam "release 1.1.0"; git tag v1.1.0
    extra="--version-file src/demo/__init__.py --version-regex __version__\\W+([0-9.]+)"
    op="bump pyproject.toml to 1.1.0 and tag; src/demo/__init__.py still says 1.0.0" ;;
  insufficient)     # nothing declares a version
    git rm -q pyproject.toml src/demo/__init__.py; echo 'print(2)' > src/demo/app.py; git add -A
    git commit -qm "no manifest"; git tag v1.1.0
    op="tag v1.1.0 on a commit where no file declares a version" ;;
esac
echo v1.1.0; echo "$extra"; echo "$op"
