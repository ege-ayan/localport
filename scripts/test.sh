#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if [[ ! -f lib/data/collections.g.dart ]]; then
  echo "Generating Isar code..."
  dart run build_runner build
  dart format lib/data/collections.g.dart
fi

echo "Checking formatting..."
dart format --set-exit-if-changed lib test

echo "Analyzing..."
flutter analyze --fatal-infos

echo "Running tests..."
output="$(flutter test --reporter compact 2>&1)" || {
  echo "$output"
  exit 1
}
echo "$output"

passed="$(printf '%s\n' "$output" | sed -nE 's/.*All tests passed!/\0/p' | tail -n 1 || true)"
echo ""
echo "────────────────────────────────────────"
if [[ -n "${passed}" ]]; then
  echo "Total: flutter test — all passed"
else
  echo "Total: flutter test finished"
fi
