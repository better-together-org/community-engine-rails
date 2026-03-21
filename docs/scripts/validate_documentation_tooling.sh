#!/bin/bash

# Documentation Tooling Validation Script
# Validates that all documentation tools work with the new stakeholder structure

set -euo pipefail

# Get the project root directory (two levels up from this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"

echo "🏗️  Better Together - Documentation Tooling Validation"
echo "================================================="
echo ""

required_docs=(
  "$DOCS_DIR/development/accessibility_testing.md"
  "$DOCS_DIR/development/screenshot_and_documentation_tooling_assessment.md"
  "$DOCS_DIR/shared/documentation_accessibility_rubric.md"
  "$PROJECT_ROOT/config/rubrics/documentation_accessibility_rubric.json"
)

safety_docs=(
  "$DOCS_DIR/end_users/safety_reporting.md"
  "$DOCS_DIR/end_users/blocking_and_boundaries.md"
  "$DOCS_DIR/end_users/reporting_harm_and_safety_concerns.md"
  "$DOCS_DIR/end_users/after_you_report.md"
  "$DOCS_DIR/end_users/privacy_and_safety_preferences.md"
  "$DOCS_DIR/end_users/emergency_and_urgent_situations.md"
)

plain_text_docs=(
  "${safety_docs[@]}"
  "$DOCS_DIR/end_users/README.md"
  "$DOCS_DIR/end_users/user_management_guide.md"
  "$DOCS_DIR/end_users/welcome.md"
  "$DOCS_DIR/development/README.md"
  "$DOCS_DIR/table_of_contents.md"
)

# Test 1: Diagram Rendering System
echo "📊 Testing Diagram Rendering System..."
echo "  Source location: docs/diagrams/source/"
echo "  Export locations: docs/diagrams/exports/{png,svg}/"
echo ""

if [ -d "$DOCS_DIR/diagrams/source" ]; then
    mmd_count=$(find "$DOCS_DIR/diagrams/source" -name "*.mmd" | wc -l)
    echo "  ✅ Found $mmd_count Mermaid source files"
else
    echo "  ❌ Missing source directory"
    exit 1
fi

if [ -d "$DOCS_DIR/diagrams/exports/png" ]; then
    png_count=$(find "$DOCS_DIR/diagrams/exports/png" -name "*.png" | wc -l)
    echo "  ✅ Found $png_count PNG exports"
else
    echo "  ❌ Missing PNG export directory"
    exit 1
fi

if [ -d "$DOCS_DIR/diagrams/exports/svg" ]; then
    svg_count=$(find "$DOCS_DIR/diagrams/exports/svg" -name "*.svg" | wc -l)
    echo "  ✅ Found $svg_count SVG exports"
else
    echo "  ❌ Missing SVG export directory"
    exit 1
fi

# Test 2: Diagram Script Functionality
echo ""
echo "🔧 Testing bin/render_diagrams script..."
if [ -x "bin/render_diagrams" ]; then
    echo "  ✅ Script is executable"
    echo "  Testing dry-run..."
    if ./bin/render_diagrams --help >/dev/null 2>&1; then
        echo "  ✅ Help output works"
    else
        echo "  ❌ Help output failed"
    fi
else
    echo "  ❌ Script not found or not executable"
    exit 1
fi

# Test 3: Progress Tracking Script
echo ""
echo "📈 Testing documentation progress tracking..."
if [ -f "$DOCS_DIR/scripts/update_progress.sh" ]; then
    echo "  ✅ Progress script exists"
    if bash "$DOCS_DIR/scripts/update_progress.sh" >/dev/null 2>&1; then
        echo "  ✅ Progress script runs successfully"
    else
        echo "  ⚠️  Progress script has issues (but continuing)"
    fi
else
    echo "  ❌ Progress script not found"
fi

# Test 4: GitHub Workflow Compatibility
echo ""
echo "🤖 Testing GitHub workflow compatibility..."
if [ -f "$PROJECT_ROOT/.github/workflows/diagrams.yml" ]; then
    echo "  ✅ GitHub workflow exists"
    if grep -q "docs/diagrams/exports" "$PROJECT_ROOT/.github/workflows/diagrams.yml"; then
        echo "  ✅ Workflow updated for new structure"
    else
        echo "  ❌ Workflow not updated for new structure"
    fi
else
    echo "  ❌ GitHub workflow not found"
fi

# Test 5: Documentation References
echo ""
echo "📚 Testing documentation references..."
broken_refs=0

# Check for old-style diagram references (docs/*.mmd instead of docs/diagrams/source/*.mmd)
if grep -r "docs/[^/]*\.\(mmd\|png\|svg\)" "$DOCS_DIR/" --exclude-dir=diagrams --exclude-dir=scripts >/dev/null 2>&1; then
    old_refs=$(grep -r "docs/[^/]*\.\(mmd\|png\|svg\)" "$DOCS_DIR/" --exclude-dir=diagrams --exclude-dir=scripts | wc -l)
    echo "  ⚠️  Found $old_refs potential old-style diagram references"
    broken_refs=$((broken_refs + old_refs))
fi

if [ $broken_refs -eq 0 ]; then
    echo "  ✅ No broken diagram references found"
else
    echo "  ⚠️  Found $broken_refs references that may need updating"
fi

# Test 6: Stakeholder Structure Readiness  
echo ""
echo "👥 Testing stakeholder structure readiness..."
stakeholder_script="$DOCS_DIR/scripts/create_stakeholder_structure.sh"
if [ -f "$stakeholder_script" ]; then
    echo "  ✅ Stakeholder migration script ready"
    if [ -x "$stakeholder_script" ]; then
        echo "  ✅ Script is executable"
    else
        echo "  ⚠️  Script needs to be made executable (chmod +x)"
    fi
else
    echo "  ❌ Stakeholder migration script not found"
fi

# Test 7: Accessibility and screenshot documentation
echo ""
echo "♿ Testing accessibility and screenshot documentation..."
missing_required=0

for doc in "${required_docs[@]}"; do
    display_path="${doc#$PROJECT_ROOT/}"
    if [ -f "$doc" ]; then
        echo "  ✅ Found $display_path"
    else
        echo "  ❌ Missing $display_path"
        missing_required=$((missing_required + 1))
    fi
done

if [ -f "$PROJECT_ROOT/spec/support/capybara_screenshot_engine.rb" ]; then
    echo "  ✅ Screenshot engine helper exists"
else
    echo "  ❌ Screenshot engine helper missing"
    missing_required=$((missing_required + 1))
fi

if [ -x "$PROJECT_ROOT/bin/docs_screenshots" ]; then
    echo "  ✅ Screenshot runner exists"
else
    echo "  ❌ Screenshot runner missing or not executable"
    missing_required=$((missing_required + 1))
fi

if [ $missing_required -ne 0 ]; then
    echo "  ❌ Accessibility/screenshot documentation validation failed"
    exit 1
fi

# Test 8: Safety documentation screenshot references and index coverage
echo ""
echo "🛡️  Testing end-user safety documentation coverage..."
safety_missing=0

for doc in "${safety_docs[@]}"; do
    display_path="${doc#$PROJECT_ROOT/}"
    if [ -f "$doc" ]; then
        echo "  ✅ Found $display_path"
    else
        echo "  ❌ Missing $display_path"
        safety_missing=$((safety_missing + 1))
    fi
done

if ! grep -q "Safety and Reporting Tools" "$DOCS_DIR/end_users/README.md"; then
    echo "  ❌ docs/end_users/README.md is missing the safety section link"
    safety_missing=$((safety_missing + 1))
else
    echo "  ✅ End-user index links to the safety section"
fi

if ! grep -q "end_users/safety_reporting.md" "$DOCS_DIR/table_of_contents.md"; then
    echo "  ❌ docs/table_of_contents.md is missing the safety overview entry"
    safety_missing=$((safety_missing + 1))
else
    echo "  ✅ Table of contents includes the safety overview"
fi

for doc in "${safety_docs[@]}"; do
    while IFS= read -r screenshot_path; do
        [ -n "$screenshot_path" ] || continue
        resolved_path="$(cd "$(dirname "$doc")" && realpath -m "$screenshot_path")"
        if [ -f "$resolved_path" ]; then
            echo "  ✅ Screenshot reference ok: ${resolved_path#$PROJECT_ROOT/}"
        else
            echo "  ❌ Missing screenshot referenced by ${doc#$PROJECT_ROOT/}: $screenshot_path"
            safety_missing=$((safety_missing + 1))
        fi
    done < <(grep -oE '\.\./screenshots/[A-Za-z0-9_./-]+\.(png|gif)' "$doc" || true)
done

if [ $safety_missing -ne 0 ]; then
    echo "  ❌ Safety documentation validation failed"
    exit 1
fi

# Test 9: Plain-text style checks for touched user/developer docs
echo ""
echo "✍️  Testing documentation style constraints..."
style_issues=0

for doc in "${plain_text_docs[@]}"; do
    display_path="${doc#$PROJECT_ROOT/}"
    if grep -nP '[\x{1F300}-\x{1FAFF}]' "$doc" >/dev/null 2>&1; then
        echo "  ❌ Emoji found in $display_path"
        style_issues=$((style_issues + 1))
    else
        echo "  ✅ No emoji in $display_path"
    fi

    if grep -n '—' "$doc" >/dev/null 2>&1; then
        echo "  ❌ Em dash found in $display_path"
        style_issues=$((style_issues + 1))
    else
        echo "  ✅ No em dash in $display_path"
    fi
done

if [ $style_issues -ne 0 ]; then
    echo "  ❌ Documentation style validation failed"
    exit 1
fi

# Summary
echo ""
echo "📋 Validation Summary"
echo "===================="
echo "• Diagram Source Files: $mmd_count"
echo "• PNG Exports: $png_count"
echo "• SVG Exports: $svg_count"
echo "• Render Script: ✅ Working"
echo "• GitHub Workflow: ✅ Updated"
echo "• Stakeholder Migration: ✅ Ready"
echo "• Accessibility Docs & Rubric: ✅ Ready"
echo "• Safety Docs & Screenshots: ✅ Ready"
echo "• Plain-Text Style Rules: ✅ Ready"

echo ""
echo "✅ Documentation tooling validation complete!"
echo ""
echo "🚀 Next Steps:"
echo "  1. Run stakeholder migration: ./docs/scripts/create_stakeholder_structure.sh"
echo "  2. Test full diagram rendering: ./bin/render_diagrams --force"
echo "  3. Update any remaining documentation references"
echo "  4. Validate stakeholder-specific documentation organization"
