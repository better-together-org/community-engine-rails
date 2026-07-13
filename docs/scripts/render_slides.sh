#!/usr/bin/env bash
set -euo pipefail

# Render slides with reveal-md if available. Falls back to instructions.

SLIDES_MD=${1:-docs/workshop/slides/intro_slides.md}
OUT_DIR=${2:-docs/workshop/slides/dist}
PDF_OUT=${3:-docs/workshop/slides/dist/intro_slides.pdf}

mkdir -p "$OUT_DIR"

if command -v reveal-md >/dev/null 2>&1; then
  echo "Using system reveal-md to render static HTML..."
  reveal-md "$SLIDES_MD" --static "$OUT_DIR"
elif command -v npx >/dev/null 2>&1; then
  echo "Using npx reveal-md to render static HTML..."
  npx -y reveal-md "$SLIDES_MD" --static "$OUT_DIR"
else
  echo "Neither reveal-md nor npx is available. Skipping HTML render." >&2
fi

# Attempt PDF export (requires Puppeteer/Chromium in reveal-md). This may fail in restricted envs.
if command -v reveal-md >/dev/null 2>&1; then
  echo "Attempting PDF export via reveal-md (may require Chromium)..."
  if ! reveal-md "$SLIDES_MD" --print "$PDF_OUT"; then
    echo "WARN: reveal-md PDF export failed. Use a browser to print:"
    echo "  Open ${OUT_DIR}/intro_slides.html?print-pdf and Save as PDF"
  fi
elif command -v npx >/dev/null 2>&1; then
  echo "Attempting PDF export via npx reveal-md (may require Chromium)..."
  if ! npx -y reveal-md "$SLIDES_MD" --print "$PDF_OUT"; then
    echo "WARN: reveal-md PDF export failed. Use a browser to print:"
    echo "  Open ${OUT_DIR}/intro_slides.html?print-pdf and Save as PDF"
  fi
fi

echo "Slides rendering complete (if tools available). Output: $OUT_DIR"

