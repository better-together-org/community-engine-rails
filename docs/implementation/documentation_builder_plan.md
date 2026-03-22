# DocumentationBuilder Implementation Plan

## ⚠️ RETROSPECTIVE DOCUMENTATION

**This is retrospective documentation for PR #1149 (feat/policies-and-docs).**

This implementation plan documents the approach taken for the DocumentationBuilder system, which was implemented and merged without formal planning documentation. This document serves to:
1. Record architectural decisions made during implementation
2. Provide context for future maintenance and enhancements
3. Establish baseline for similar documentation automation features

**Implementation Status:** ✅ Completed and merged in PR #1149 (November 2025)

---

## Overview

The DocumentationBuilder automates the creation of a navigable documentation site from markdown files in the `docs/` directory. It scans the directory structure, creates navigation hierarchies, and generates pages with markdown content blocks automatically.

### Problem Statement

**Who is affected:** Platform organizers, developers, and end users seeking platform documentation

**Pain point:** Manual creation and maintenance of documentation pages was time-consuming and error-prone:
- Each markdown file required manual page creation in the admin interface
- Navigation structure had to be manually built and maintained
- File reorganization meant updating multiple navigation items and pages
- New documentation required technical knowledge of the CMS
- Inconsistent page layouts and navigation patterns

### Success Criteria

✅ **Achieved:**
- Documentation pages automatically generated from `docs/` directory structure
- Hierarchical navigation reflects directory organization
- Protected pages and navigation prevent accidental deletion
- Sidebar navigation consistent across all documentation pages
- Changes to file structure reflected in navigation on rebuild
- Zero manual page creation required for documentation

## Stakeholder Analysis

### Primary Stakeholders

- **Platform Organizers**: Need to publish platform policies, guides, and information without technical expertise
  - **Served by:** Automated page creation from markdown files
  - **Benefit:** Can edit markdown files directly or through documentation tools

- **Developers**: Need comprehensive technical documentation accessible within the platform
  - **Served by:** Automatic structuring of developer docs from filesystem
  - **Benefit:** Documentation organized alongside code, versioned in git

### Secondary Stakeholders

- **End Users**: Need to access policies, agreements, and help documentation
  - **Impact:** Consistent, navigable documentation experience
  
- **Community Organizers**: May reference platform documentation for their communities
  - **Impact:** Clear documentation hierarchy and search

indexing

### Collaborative Decision Points

**Individual Platform Organizer Autonomy:**
- Organizing documentation file structure
- Adding new documentation files
- Editing content of non-protected documentation

**Consensus Not Required:**
- Rebuilding documentation navigation (idempotent operation)
- File organization within `docs/` directory

## Implementation Priority Matrix

### Phase 1: Core Builder Infrastructure (Completed November 2025)
**Priority: HIGH** - Foundation for automated documentation

1. **Directory Scanner** - Recursive traversal of `docs/` directory
2. **Navigation Structure Builder** - Convert filesystem to navigation hierarchy
3. **Page Generation** - Create pages with markdown blocks from files
4. **Sidebar Integration** - Associate documentation nav area with all doc pages

### Phase 2: Protection and Safety (Completed November 2025)
**Priority: CRITICAL** - Prevent accidental deletion

1. **Protected Flags** - Mark all generated content as protected
2. **Idempotent Rebuild** - Safe to run multiple times without data loss
3. **Slug Management** - Preserve slugs across rebuilds

## Detailed Implementation

---

## 1. DocumentationBuilder Core (November 2025)

### Overview

Singleton builder class that scans `docs/` directory, builds hierarchical data structure, and creates `NavigationArea`, `NavigationItem`, and `Page` records. Designed to run during platform setup or when documentation structure changes.

### Stakeholder Acceptance Criteria

**Platform Organizer Criteria:**
1. As a platform organizer, I want documentation pages created automatically from markdown files so that I can publish documentation without technical knowledge
2. As a platform organizer, I want protected documentation that cannot be accidentally deleted so that critical pages remain available
3. As a platform organizer, I want consistent sidebar navigation on all documentation pages so that users can browse easily

**Developer Criteria:**
1. As a developer, I want documentation structure to mirror filesystem so that organization is intuitive
2. As a developer, I want the builder to be idempotent so that I can safely rebuild documentation
3. As a developer, I want nested documentation (directories within directories) supported so that I can organize complex docs

### Models Required/Enhanced

**Existing Models Used:**
- `BetterTogether::NavigationArea` - Container for documentation navigation
- `BetterTogether::NavigationItem` - Individual navigation entries (links and dropdowns)
- `BetterTogether::Page` - Documentation pages
- `BetterTogether::Content::Markdown` - Markdown content blocks

**No new models created** - Builder uses existing content infrastructure

### Builder Class

```ruby
# app/builders/better_together/documentation_builder.rb
module BetterTogether
  class DocumentationBuilder < Builder
    class << self
      def build
        # Main entry point - builds entire documentation structure
        # 1. Scan docs/ directory
        # 2. Find or create 'documentation' navigation area
        # 3. Create hierarchical navigation items
        # 4. Generate pages with markdown blocks
      end
      
      private
      
      def documentation_entries
        # Recursively scan docs/ directory
        # Returns nested hash structure representing filesystem
      end
      
      def build_documentation_entries(current_path)
        # Recursive function building entry data structure
        # Handles both directories (dropdowns) and files (links)
      end
      
      def create_documentation_navigation_item(area, entry, position, parent: nil)
        # Creates NavigationItem with appropriate type
        # Dropdowns for directories, links for files
        # Recursively creates children
      end
      
      def documentation_page_for(title, relative_path, sidebar_nav_area = nil)
        # Finds or creates Page with markdown block
        # Sets sidebar_nav association
        # Locks page during update to prevent race conditions
      end
      
      def documentation_slug(path)
        # Converts file path to URL slug
        # Example: developers/api.md → docs/developers/api
      end
    end
  end
end
```

### Key Features

**Directory Scanning:**
- Recursively traverses `docs/` directory
- Respects hidden files (ignores dotfiles)
- Sorts entries alphabetically for consistent ordering
- Detects default files (README.md, index.md) for directory overviews

**Navigation Structure:**
- Directories become dropdown navigation items
- Markdown files become link navigation items
- Preserves hierarchy (up to arbitrary depth)
- Sets position based on alphabetical order

**Page Generation:**
- Creates `BetterTogether::Page` records
- Embeds `BetterTogether::Content::Markdown` block via `page_blocks_attributes`
- Sets `sidebar_nav` to documentation navigation area
- Marks pages as protected and public
- Uses full-width layout for documentation

**Slug Management:**
- Prefixes all slugs with `docs/`
- Preserves directory structure in slug (e.g., `docs/developers/systems/caching`)
- Converts README.md to `overview`
- Forces slug preservation across rebuilds using FriendlyId bypass

**Protection:**
- All navigation items marked `protected: true`
- All pages marked `protected: true`
- Navigation area marked `protected: true` and `visible: true`

### Database Interaction

**No migrations required** - Uses existing schema

**Builder behavior:**
1. **Find or create** `NavigationArea` with slug 'documentation'
2. **Delete existing items** from navigation area on rebuild (cascade safe due to protection)
3. **Create new navigation hierarchy** based on current filesystem
4. **Update existing pages** or create new ones
5. **Destroy orphaned page_blocks** before updating page

**Locking strategy:**
```ruby
# Prevent race conditions during page updates
locked_page = ::BetterTogether::Page.lock.find(page.id)
locked_page.page_blocks.destroy_all
locked_page.reload
locked_page.assign_attributes(attrs)
locked_page.save!
```

### Authorization & Permissions

**No special policies required** - Uses existing policies:
- `NavigationAreaPolicy` - Platform managers can manage
- `NavigationItemPolicy` - Platform managers can manage
- `PagePolicy` - Public can view, platform managers can edit
- `Content::MarkdownPolicy` - Platform managers can manage blocks

**Protection enforcement:**
- Protected flag prevents deletion through UI
- Policies check protected status before allowing destroy

### Integration Points

**Called by:**
- Platform setup wizard (initial documentation)
- Rake tasks for documentation rebuild
- Admin interface (manual rebuild button - future enhancement)

**Dependencies:**
- `BetterTogether::Content::Markdown` - For file-based content
- `BetterTogether::NavigationArea/Item` - For site navigation
- `BetterTogether::Page` - For documentation pages
- FriendlyId - For slug management (bypassed for exact control)

### Testing Requirements (TDD Approach)

#### Builder Tests

```ruby
# spec/builders/better_together/documentation_builder_spec.rb
RSpec.describe BetterTogether::DocumentationBuilder do
  # Uses temporary directory with test markdown files
  # Tests complete build process including nested structures
  
  it 'creates a documentation navigation area with nested items'
  it 'assigns the documentation navigation area as sidebar_nav for all documentation pages'
  it 'creates a protected navigation area'
  it 'creates a visible navigation area'
  it 'creates protected navigation items'
  it 'creates protected pages'
  it 'preserves exact slugs across rebuilds'
  it 'handles directories with default files (README.md)'
  it 'handles deeply nested directory structures'
  it 'updates existing pages without creating duplicates'
end
```

**Test Coverage:** ✅ 235 lines of comprehensive builder tests

---

## Implementation Timeline

### ✅ Completed: November 2025 (PR #1149)

**Week 1: Core Implementation**
- ✅ Created DocumentationBuilder class with directory scanning
- ✅ Implemented navigation structure generation
- ✅ Added page creation with markdown blocks
- ✅ Integrated sidebar navigation association

**Week 1: Testing & Refinement**
- ✅ Comprehensive builder specs with temporary directory fixtures
- ✅ Protection flags for all generated content
- ✅ Idempotent rebuild with slug preservation
- ✅ FriendlyId bypass for exact slug control

## Collaborative Decision Framework

### Individual Platform Organizer Autonomy

**Organizers can independently:**
- Organize documentation files in `docs/` directory
- Add new markdown files
- Edit markdown file content
- Trigger documentation rebuild (when UI added)

### Technical Decisions (Development Team)

**Developers decided:**
- Use existing content infrastructure (no new models)
- Protect all generated content by default
- Prefix all slugs with `docs/`
- Use FriendlyId bypass for exact slug control
- Scan only `docs/` directory (not configurable)

### Future Enhancements Requiring Discussion

**Potential features:**
- Multiple documentation areas (e.g., different docs per community)
- Customizable documentation root path
- Documentation versioning
- Real-time documentation sync (watch mode)

## Risk Assessment

### Implemented Mitigations

✅ **Race Conditions:** Row locking during page updates
✅ **Data Loss:** Protected flags prevent accidental deletion
✅ **Slug Conflicts:** FriendlyId bypassed for exact control
✅ **Idempotency:** Safe to rebuild multiple times

### Outstanding Considerations

⚠️ **Large Documentation Sets:** No pagination in navigation (acceptable for current scale)
⚠️ **Internationalization:** Documentation in English only (markdown localization exists separately)
⚠️ **File Watch Mode:** Must manually rebuild after file changes

## Security Considerations

**File Path Safety:**
- Uses Rails.root.join for path resolution
- Rejects paths starting with `.` (hidden files)
- No user input in file paths (builder controls all paths)

**Content Security:**
- Markdown rendering through trusted MarkdownRendererService
- No user-supplied markdown in builder (files controlled by developers)

**Authorization:**
- Existing policies control access
- Protected flag prevents accidental deletion
- Platform manager permission required for rebuild

## Performance Considerations

**Build Time:**
- Linear with number of files: O(n) where n = markdown files
- Average: <1 second for typical documentation (~50 files)
- Acceptable for setup wizard and manual rebuilds

**Runtime:**
- No performance impact (builder runs during setup/rebuild only)
- Documentation pages served through normal page rendering

**Optimization Opportunities:**
- Background job for large documentation sets
- Incremental updates (detect changed files only)

## Success Metrics

✅ **Implemented and Validated:**
- Zero manual page creation required for documentation
- Consistent navigation structure across all documentation
- Protected content prevents accidental deletion
- Comprehensive test coverage (235 lines)
- Idempotent rebuild operation

## Related Documentation

- [Markdown Content Management Implementation Plan](markdown_content_management_plan.md)
- [Content Management System Documentation](../developers/systems/content_management_system.md)
- [Navigation System Documentation](../developers/systems/navigation_system.md)

## Future Considerations

**Potential Enhancements:**
1. Admin UI for triggering documentation rebuild
2. File watch mode for automatic rebuilds during development
3. Documentation versioning (track changes over time)
4. Multiple documentation areas (community-specific docs)
5. Documentation search with Elasticsearch integration
6. Table of contents generation from markdown headers
7. Breadcrumb navigation for deep documentation paths

**Migration Path:**
- Builder supports any of these enhancements without breaking changes
- Protected content ensures safe evolution
- Idempotent design allows incremental improvements
