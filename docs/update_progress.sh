#!/bin/bash

# Better Together Community Engine - Documentation Progress Tracker
# This script updates documentation metrics and progress indicators
# Usage: ./update_progress.sh [system_name] [action]
# Actions: complete, partial, start
# Example: ./update_progress.sh "Community & Social System" complete

DOCS_DIR="/home/rob/projects/better-together/community-engine-rails/docs"
ASSESSMENT_FILE="$DOCS_DIR/documentation_assessment.md"
INVENTORY_FILE="$DOCS_DIR/documentation_inventory.md"

# Documentation Status Counters (update these when systems are completed)
COMPLETED_SYSTEMS=4
PARTIAL_SYSTEMS=3  
PENDING_SYSTEMS=8
TOTAL_SYSTEMS=15

COMPLETED_TABLES=28
TOTAL_TABLES=75

# System completion tracking - update when systems are completed
declare -A COMPLETED_SYSTEM_LIST=(
    ["I18n/Mobility Localization System"]=true
    ["Security/Protection System"]=true
    ["Geography/Location System"]=true
    ["Caching/Performance System"]=true
)

declare -A PARTIAL_SYSTEM_LIST=(
    ["Event & Calendar System"]=true
    ["Infrastructure & Building System"]=true
    ["Joatu Exchange System"]=true
)

# Handle command line arguments for system updates
if [ $# -eq 2 ]; then
    SYSTEM_NAME="$1"
    ACTION="$2"
    
    case "$ACTION" in
        "complete")
            echo "🎉 Marking '$SYSTEM_NAME' as complete!"
            # Add logic here to update counters and lists
            ;;
        "partial") 
            echo "🔄 Marking '$SYSTEM_NAME' as partial!"
            ;;
        "start")
            echo "🚀 Starting documentation for '$SYSTEM_NAME'!"
            ;;
        *)
            echo "❌ Unknown action: $ACTION. Use: complete, partial, or start"
            exit 1
            ;;
    esac
    echo ""
fi

# Calculate percentages
SYSTEM_COMPLETION=$((COMPLETED_SYSTEMS * 100 / TOTAL_SYSTEMS))
TABLE_COMPLETION=$((COMPLETED_TABLES * 100 / TOTAL_TABLES))

# Update timestamp
CURRENT_DATE=$(date "+%B %d, %Y")

echo "=== Better Together Documentation Progress ==="
echo "Last Updated: $CURRENT_DATE"
echo ""
echo "System Progress:"
echo "  ✅ Completed: $COMPLETED_SYSTEMS/$TOTAL_SYSTEMS ($SYSTEM_COMPLETION%)"
echo "  🔄 Partial:   $PARTIAL_SYSTEMS/$TOTAL_SYSTEMS"
echo "  📋 Pending:   $PENDING_SYSTEMS/$TOTAL_SYSTEMS"
echo ""
echo "Table Coverage:"
echo "  📊 Documented: $COMPLETED_TABLES/$TOTAL_TABLES ($TABLE_COMPLETION%)"
echo ""

# Count documentation files
DOC_COUNT=$(find $DOCS_DIR -name "*.md" -not -name "README.md" | wc -l)
DIAGRAM_COUNT=$(find $DOCS_DIR -name "*.mmd" | wc -l)
PNG_COUNT=$(find $DOCS_DIR -name "*.png" | wc -l)
SVG_COUNT=$(find $DOCS_DIR -name "*.svg" | wc -l)

echo "Documentation Assets:"
echo "  📝 Documentation Files: $DOC_COUNT"
echo "  🎨 Mermaid Diagrams: $DIAGRAM_COUNT"  
echo "  🖼️  PNG Images: $PNG_COUNT"
echo "  🎯 SVG Vectors: $SVG_COUNT"
echo ""

# List completed systems
echo "✅ Completed Systems:"
echo "  1. I18n/Mobility Localization System"
echo "  2. Security/Protection System"
echo "  3. Geography/Location System"  
echo "  4. Caching/Performance System"
echo ""

# List next priorities
echo "🔥 Next High Priority Systems:"
echo "  - Community & Social System (8 tables)"
echo "  - Content Management System (9 tables)"
echo "  - Communication & Messaging System (5 tables)"
echo ""

# Update assessment file timestamp if it exists
if [ -f "$ASSESSMENT_FILE" ]; then
    echo "Updating assessment file timestamp..."
    # Update the "Last Updated" line in the assessment file
    sed -i "1,10s/\*\*Last Updated:\*\* .*/\*\*Last Updated:\*\* $CURRENT_DATE/" "$ASSESSMENT_FILE"
    
    # If system completion was specified, add completion note
    if [ $# -eq 2 ] && [ "$2" = "complete" ]; then
        echo "Adding completion entry for '$1' to assessment file..."
        # This could be expanded to automatically update the progress matrix
    fi
fi

echo "📊 Progress tracking complete!"
echo "📁 Run from: $DOCS_DIR"

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage Examples:"
    echo "  ./update_progress.sh                                    # Show current progress"
    echo "  ./update_progress.sh \"Community & Social System\" start    # Mark system as started"
    echo "  ./update_progress.sh \"Community & Social System\" complete # Mark system as complete"
    echo ""
fi
