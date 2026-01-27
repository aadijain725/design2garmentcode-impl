#!/usr/bin/env bash
# Complete GitHub setup: create repo (if gh available) and push.
# Run from project root or any subdir. Requires network.

set -e
cd "$(git rev-parse --show-toplevel)"

if command -v gh &>/dev/null; then
  gh repo create design2garmentcode-impl --private 2>/dev/null || true
fi

git push -u origin main
