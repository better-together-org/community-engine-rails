#!/bin/bash

# Migration script to move diagrams to new stakeholder-focused structure
# Moves .mmd files to docs/diagrams/source/
# Moves .png/.svg files to docs/diagrams/exports/{png,svg}/

set -euo pipefail

# Get the project root directory (two levels up from this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"

echo "🔄 Migrating diagrams to new stakeholder structure..."

# Create the new diagram directories
echo "📁 Creating diagram directories..."
mkdir -p "$DOCS_DIR/diagrams/source"
mkdir -p "$DOCS_DIR/diagrams/exports/png" 
mkdir -p "$DOCS_DIR/diagrams/exports/svg"

# Move Mermaid source files
echo "📊 Moving Mermaid source files..."
if ls "$DOCS_DIR"/*.mmd >/dev/null 2>&1; then
    mv "$DOCS_DIR"/*.mmd "$DOCS_DIR/diagrams/source/" 2>/dev/null || true
    echo "✅ Moved .mmd files to docs/diagrams/source/"
else
    echo "ℹ️  No .mmd files found to move"
fi

# Move PNG export files  
echo "🖼️  Moving PNG exports..."
if ls "$DOCS_DIR"/*.png >/dev/null 2>&1; then
    mv "$DOCS_DIR"/*.png "$DOCS_DIR/diagrams/exports/png/" 2>/dev/null || true
    echo "✅ Moved .png files to docs/diagrams/exports/png/"
else
    echo "ℹ️  No .png files found to move"
fi

# Move SVG export files
echo "🎯 Moving SVG exports..."
if ls "$DOCS_DIR"/*.svg >/dev/null 2>&1; then
    mv "$DOCS_DIR"/*.svg "$DOCS_DIR/diagrams/exports/svg/" 2>/dev/null || true
    echo "✅ Moved .svg files to docs/diagrams/exports/svg/"
else
    echo "ℹ️  No .svg files found to move"
fi

# Create README for diagrams directory
cat > "$DOCS_DIR/diagrams/README.md" << 'EOF'
# Visual Documentation & Diagrams

This directory contains visual documentation for the Better Together Community Engine.

## Structure

- **`source/`** - Mermaid diagram source files (.mmd)
- **`exports/png/`** - PNG exports for documentation embedding  
- **`exports/svg/`** - SVG exports for scalable viewing

## Rendering Diagrams

To render all diagrams from source to exports:

```bash
bin/render_diagrams
```

This will:
- Process all `.mmd` files in `source/`
- Generate PNG exports in `exports/png/`
- Generate SVG exports in `exports/svg/`
- Automatically detect complex diagrams and render at higher resolution

## Adding New Diagrams

1. Create `.mmd` file in `source/` directory
2. Run `bin/render_diagrams` to generate exports
3. Reference exported images in documentation

## Diagram Types

### System Architecture
- Entity relationship diagrams
- Class diagrams
- Component interactions

### Process Flows
- User workflows
- Data flows
- State transitions
- Business processes

### System Integration
- API interactions
- Service boundaries
- Deployment architecture
EOF

echo ""
echo "📊 Migration Summary:"
echo "  Source files: $(find "$DOCS_DIR/diagrams/source" -name "*.mmd" 2>/dev/null | wc -l) Mermaid diagrams"
echo "  PNG exports:  $(find "$DOCS_DIR/diagrams/exports/png" -name "*.png" 2>/dev/null | wc -l) files"
echo "  SVG exports:  $(find "$DOCS_DIR/diagrams/exports/svg" -name "*.svg" 2>/dev/null | wc -l) files"
echo ""
echo "✅ Diagram migration complete!"
echo "💡 Next steps:"
echo "   1. Test rendering: bin/render_diagrams"
echo "   2. Run stakeholder migration: docs/scripts/create_stakeholder_structure.sh"
echo "   3. Update any remaining documentation references"
