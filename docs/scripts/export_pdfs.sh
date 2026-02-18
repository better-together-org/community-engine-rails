#!/usr/bin/env bash
set -euo pipefail

# Export specified Markdown files to PDF using pandoc if available.
# Usage: docs/scripts/export_pdfs.sh [files...]

if [ $# -eq 0 ]; then
  echo "Usage: $(basename "$0") file1.md [file2.md ...]" >&2
  echo "Example: $(basename "$0") docs/workshop/intro_agenda_printable.md" >&2
  exit 2
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is not installed. Please install pandoc to export PDFs." >&2
  echo "Alternatively, open the Markdown in your editor/viewer and print to PDF." >&2
  exit 1
fi

for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "File not found: $f" >&2
    exit 3
  fi
  out="${f%.md}.pdf"
  echo "Exporting $f -> $out"
  pandoc "$f" -o "$out" --from=markdown --pdf-engine=xelatex || pandoc "$f" -o "$out"
done

echo "PDF export complete."

