# Security Gate Assessment: Brakeman Push Hook Analysis

**Assessment Date:** 2026-06-05  
**Project:** Better Together Community Engine Rails  
**Status:** ⚠️ NEEDS IMPROVEMENT

---

## Executive Summary

The current push hook and CI configuration **does NOT adequately block high-risk or critical vulnerabilities** from being merged. While Brakeman is configured to run, it does not fail the security job when vulnerabilities are detected.

---

## Current Configuration

### ✅ What's Working

1. **Brakeman is integrated** in the main CI workflow (`.github/workflows/rubyonrails.yml`)
   - Runs in the `security` job
   - Uses `-q -w2` flags (quiet mode, Confidence level 2 and above = HIGH)
   
2. **Separate Brakeman workflow** (`.github/workflows/brakeman.yml`)
   - Generates SARIF reports for GitHub security tab
   - Runs on push to `main`, PRs targeting `main`, and scheduled weekly

3. **Security job is required** for PRs
   - Part of the CI gate via `needs: [prepare, pr_evidence]`

### ❌ Critical Issues

1. **Brakeman doesn't fail the job on vulnerabilities**
   - Current command: `bundle exec brakeman -q -w2`
   - This command **does NOT exit with non-zero status** when warnings are found
   - Job continues successfully even if HIGH-confidence vulnerabilities exist

2. **No exit-on-error threshold**
   - Missing flags like `-z` (exit with error code if warnings found)
   - No filtering for specific confidence levels that should block

3. **No local pre-commit hook**
   - Developers can commit locally without Brakeman validation
   - Reduces early feedback

4. **SARIF workflow uses `continue-on-error: true`**
   - `.github/workflows/brakeman.yml` explicitly allows failures
   - Doesn't block SARIF generation even if vulnerabilities found

---

## Current Brakeman Run Results (From Today)

From this session's security scan:
- **Total Warnings:** 14
- **High-Confidence Vulnerabilities:** 8 (all Format Validation)
- **Weak-Confidence Redirects:** 6

**Key Finding:** These warnings would NOT prevent a merge because Brakeman doesn't fail the job.

---

## Recommendations

### 1. **Update Main CI Workflow** (Priority: CRITICAL)

Modify `.github/workflows/rubyonrails.yml` security job:

```yaml
security:
  needs: [prepare, pr_evidence]
  if: needs.prepare.result == 'success' && (needs.pr_evidence.result == 'success' || needs.pr_evidence.result == 'skipped')
  runs-on: ubuntu-latest
  env:
    RAILS_VERSION: ${{ needs.prepare.outputs.rails_version }}
  steps:
    - uses: actions/checkout@v4
    - uses: ruby/setup-ruby@v1
      with:
        ruby-version: "3.4.4"
    - name: Resolve branch-native bundle
      shell: bash
      run: |
        bundle config set deployment false
        bundle update rails --conservative
        bundle install --jobs 4 --retry 3
    
    - name: Run Brakeman (Fail on HIGH-confidence)
      run: |
        bundle exec brakeman -q -z -w2 --no-summary
      # -z: exit with error code if warnings found
      # -w2: only show Confidence >= 2 (HIGH and MEDIUM)
      # --no-summary: suppress summary output
    
    - run: bundle binstubs bundler-audit --force
    - run: bundle exec bundler-audit --update
```

### 2. **Create Local Pre-Commit Hook** (Priority: HIGH)

Create `.git/hooks/pre-commit` for local validation:

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Prevents commits with high-risk security vulnerabilities

set -e

echo "Running local Brakeman security scan..."

# Run Brakeman only on staged Ruby files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.rb$|\.erb$' || true)

if [[ -z "$STAGED_FILES" ]]; then
  echo "✓ No Ruby files staged"
  exit 0
fi

# Run quick Brakeman scan with strict settings
if ! bundle exec brakeman -q -z -w2 --no-summary 2>/dev/null; then
  echo ""
  echo "❌ Brakeman detected HIGH-confidence security issues"
  echo ""
  echo "Run locally to review:"
  echo "  bundle exec brakeman -w2"
  echo ""
  echo "Fix issues or use:"
  echo "  git commit --no-verify  # NOT RECOMMENDED"
  echo ""
  exit 1
fi

echo "✓ Brakeman security check passed"
exit 0
```

### 3. **Update SARIF Workflow** (Priority: MEDIUM)

Modify `.github/workflows/brakeman.yml`:

```yaml
- name: Scan (SARIF)
  run: |
    brakeman -f sarif -o output.sarif.json .
  
- name: Check for Critical Issues
  run: |
    # Extract high-confidence warnings from SARIF
    HIGH_CONF=$(jq '[.runs[0].results[] | select(.ruleIndex >= 0)] | length' output.sarif.json)
    if [[ $HIGH_CONF -gt 0 ]]; then
      echo "::warning::Brakeman found $HIGH_CONF HIGH-confidence security issues"
      # Don't fail, but allow status checks to see the warning
    fi
```

### 4. **Add Brakeman Configuration File** (Priority: MEDIUM)

Create `config/brakeman.yml` to standardize scanning:

```yaml
---
:rails_version: 8.0
:skip_checks:
  - BasicAuth
:exclude_paths:
  - spec/
  - config/brakeman.yml
:exclude_models:
  - BetterTogether::Invitation  # Pre-existing issues under review
:confidence: 2  # Only HIGH confidence and above
:output_formats:
  - text
  - sarif
```

---

## Implementation Roadmap

| Step | Change | File(s) | Priority | Effort |
|------|--------|---------|----------|--------|
| 1 | Add `-z` flag to Brakeman | `.github/workflows/rubyonrails.yml` | CRITICAL | 1 line |
| 2 | Create pre-commit hook | `.git/hooks/pre-commit` | HIGH | New file |
| 3 | Update SARIF workflow | `.github/workflows/brakeman.yml` | MEDIUM | 5 lines |
| 4 | Add config file | `config/brakeman.yml` | MEDIUM | New file |
| 5 | Document in AGENTS.md | `AGENTS.md` | LOW | Section |

---

## Risk Assessment

### Current State: 🔴 HIGH RISK
- HIGH-confidence vulnerabilities can merge to `main`
- No local validation prevents accidental commits
- 14 existing warnings not being actively blocked

### After Implementing Recommendations: 🟢 LOW RISK
- Push hooks fail on HIGH-confidence issues
- Local pre-commit prevents accidental commits  
- Clear developer guidance on security standards
- SARIF reports provide visibility

---

## Quick Fix (Today)

If you want to immediately improve security blocking, run:

```bash
# Option 1: One-line update to workflow
sed -i 's/bundle exec brakeman -q -w2/bundle exec brakeman -q -z -w2 --no-summary/' .github/workflows/rubyonrails.yml

# Option 2: Create pre-commit hook
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
set -e
echo "Running Brakeman security scan..."
bundle exec brakeman -q -z -w2 --no-summary || (echo "❌ Brakeman failed"; exit 1)
EOF
chmod +x .git/hooks/pre-commit
```

---

## Testing the Updated Configuration

```bash
# Test that Brakeman now fails on HIGH-confidence issues
bundle exec brakeman -q -z -w2

# Expected output with current issues:
# Exit code: 1 (non-zero means job will fail)
# This will block PRs and commits
```

---

## Notes

- **Pre-existing warnings**: The 14 current warnings are pre-existing and should be triaged/fixed in a separate PR
- **Weak confidence issues**: Current Weak-confidence redirect warnings are not included in `-w2` filter and are acceptable
- **Performance**: Adding `-z` flag has negligible performance impact
- **Backwards compatibility**: This change only affects CI/CD, no code changes required

---

## References

- Brakeman CLI Options: https://brakemanscanner.org/
- GitHub Actions Security: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
- Pre-commit Hooks: https://git-scm.com/book/en/v2/Git-Internals-Git-Hooks
