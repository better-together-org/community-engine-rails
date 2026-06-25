#!/bin/bash
# Install git hooks for Better Together Community Engine
# 
# This script sets up pre-commit hooks that validate code before commits.
# Currently installs: pre-commit hook for Brakeman security scanning
# 
# Usage:
#   chmod +x scripts/install_hooks.sh && ./scripts/install_hooks.sh

set -e

HOOKS_DIR=".git/hooks"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Better Together Community Engine Git Hooks${NC}"
echo ""

# Create hooks directory if it doesn't exist
if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "Creating .git/hooks directory..."
  mkdir -p "$HOOKS_DIR"
fi

# Create pre-commit hook
PRE_COMMIT_DEST="$HOOKS_DIR/pre-commit"

cat > "$PRE_COMMIT_DEST" << 'HOOK_EOF'
#!/bin/bash
# Better Together Community Engine - Local Security Pre-commit Hook
# 
# This hook runs Brakeman security checks on staged Ruby files before allowing commits.
# It prevents accidental commits of code with HIGH-confidence security vulnerabilities.
# 
# To bypass (NOT RECOMMENDED):
#   git commit --no-verify

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in a Ruby project with Brakeman available
if ! command -v bundle &> /dev/null; then
  echo -e "${YELLOW}⚠️  Bundle not found, skipping Brakeman check${NC}"
  exit 0
fi

# Check if there are any Ruby files being committed
STAGED_RUBY_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(rb|erb)$' || true)

if [[ -z "$STAGED_RUBY_FILES" ]]; then
  # No Ruby files staged, skip the check
  exit 0
fi

echo "🔍 Checking staged Ruby files with Brakeman..."
echo ""

# Run Brakeman with strict settings to fail on HIGH-confidence issues
if ! bundle exec brakeman -q -z -w2 --no-summary 2>/dev/null; then
  echo ""
  echo -e "${RED}❌ COMMIT BLOCKED: Brakeman detected HIGH-confidence security issues${NC}"
  echo ""
  echo "To review the issues:"
  echo "  bundle exec brakeman -w2"
  echo ""
  echo "To fix:"
  echo "  1. Review and fix the security issues in your code"
  echo "  2. Stage the fixes: git add ."
  echo "  3. Retry commit: git commit"
  echo ""
  echo "To bypass this check (NOT RECOMMENDED):"
  echo "  git commit --no-verify"
  echo ""
  exit 1
fi

echo -e "${GREEN}✓ Brakeman security check passed${NC}"
echo ""
exit 0
HOOK_EOF

chmod +x "$PRE_COMMIT_DEST"

echo -e "${GREEN}✓ Installed pre-commit hook${NC}"
echo "  Location: $PRE_COMMIT_DEST"
echo "  Purpose: Blocks commits with HIGH-confidence security vulnerabilities"
echo ""

# Verify hook is in place and executable
if [[ -x "$PRE_COMMIT_DEST" ]]; then
  echo -e "${GREEN}✓ Hook is executable${NC}"
else
  echo -e "${YELLOW}⚠️  Hook exists but is not executable, fixing...${NC}"
  chmod +x "$PRE_COMMIT_DEST"
fi

echo ""
echo -e "${BLUE}Git hooks installation complete!${NC}"
echo ""
echo "Testing Brakeman (dry run)..."
bundle exec brakeman -q -w2 --no-summary > /dev/null 2>&1 && \
  echo -e "${GREEN}✓ Brakeman is working correctly${NC}" || \
  echo -e "${YELLOW}⚠️  Brakeman check would block commits (fix security issues first)${NC}"
echo ""
echo "Next time you commit, the hook will automatically validate your code."
echo "To bypass: git commit --no-verify (not recommended)"
echo ""
