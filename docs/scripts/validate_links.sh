#!/bin/bash

# Documentation Link Validation Script
# Checks for broken links in documentation files

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"

echo "🔍 Better Together - Documentation Link Validation"
echo "============================================="
echo ""

cd "$PROJECT_ROOT"

# Function to check if a file exists relative to a base directory
check_link() {
    local base_dir="$1"
    local link_path="$2"
    local source_file="$3"
    
    # Convert relative path to absolute
    if [[ "$link_path" == /* ]]; then
        # Absolute path from project root
        full_path="$PROJECT_ROOT${link_path}"
    elif [[ "$link_path" == ../* ]]; then
        # Relative path going up
        full_path="$(cd "$base_dir" && cd "$(dirname "$link_path")" && pwd)/$(basename "$link_path")"
    else
        # Relative path in same or subdirectory
        full_path="$base_dir/$link_path"
    fi
    
    if [ -f "$full_path" ]; then
        echo "  ✅ $link_path"
        return 0
    else
        echo "  ❌ $link_path (referenced in $source_file)"
        return 1
    fi
}

# Extract markdown links from a file and check them
validate_file_links() {
    local file="$1"
    local base_dir="$(dirname "$file")"
    
    echo "📄 Checking: $file"
    
    # Extract markdown links [text](path) but not URLs (http/https)
    local broken_count=0
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local link_path=$(echo "$line" | sed -n 's/.*\[.*\](\([^)]*\)).*/\1/p')
            if [[ -n "$link_path" && "$link_path" != http* && "$link_path" != https* && "$link_path" != mailto* ]]; then
                if ! check_link "$base_dir" "$link_path" "$file"; then
                    ((broken_count++))
                fi
            fi
        fi
    done < <(grep -o '\[.*\]([^)]*\.md[^)]*)' "$file" 2>/dev/null || true)
    
    if [ "$broken_count" -eq 0 ]; then
        echo "  ✅ All links valid"
    else
        echo "  ❌ Found $broken_count broken links"
    fi
    echo ""
    
    return "$broken_count"
}

# Main validation
echo "🏠 Validating Main README..."
total_broken=0
if ! validate_file_links "README.md"; then
    ((total_broken += $?))
fi

echo "📚 Validating Documentation Files..."
find "$DOCS_DIR" -name "*.md" -type f | while read -r file; do
    if ! validate_file_links "$file"; then
        ((total_broken += $?))
    fi
done

echo "📋 Validation Summary"
echo "===================="
if [ "$total_broken" -eq 0 ]; then
    echo "✅ All documentation links are valid!"
else
    echo "❌ Found $total_broken broken links total"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Fix broken links shown above"
    echo "  2. Re-run validation script"
    echo "  3. Update table of contents if needed"
fi

exit "$total_broken"
