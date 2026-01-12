# Unified Contribution Tracking System - Implementation Plan

**Status**: 📋 Planning  
**Created**: January 6, 2026  
**Priority**: High  
**Estimated Effort**: 3-4 weeks  

---

## Executive Summary

This plan outlines the implementation of a comprehensive contribution tracking system that unifies all types of user contributions across the Better Together platform into a single, cohesive system using Single-Table Inheritance (STI). The system will track code contributions (GitHub), content creation, community engagement, event participation, moderation activities, and exchange system interactions.

### Goals

1. **Unified Tracking**: Single system for all contribution types
2. **Gamification**: Points-based achievement and ranking system
3. **Recognition**: Public leaderboards and achievement notifications
4. **Analytics**: Comprehensive reporting and dashboard integration
5. **Extensibility**: Easy to add new contribution types
6. **Performance**: Cached statistics for fast leaderboard queries

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Phase 1: Core Infrastructure](#phase-1-core-infrastructure)
3. [Phase 2: GitHub Integration](#phase-2-github-integration)
4. [Phase 3: Content Contributions](#phase-3-content-contributions)
5. [Phase 4: Community & Event Contributions](#phase-4-community--event-contributions)
6. [Phase 5: Statistics & Leaderboards](#phase-5-statistics--leaderboards)
7. [Phase 6: Dashboard & Reporting](#phase-6-dashboard--reporting)
8. [Testing Strategy](#testing-strategy)
9. [Migration Path](#migration-path)
10. [Documentation Requirements](#documentation-requirements)

---

## Architecture Overview

### Single-Table Inheritance Structure

```
BetterTogether::Contribution (base STI model)
├── Github::Contribution
│   └── Types: commit, pull_request, issue, code_review, release
├── Content::PageContribution
│   └── Types: created, edited, published, translated, reviewed
├── Content::PostContribution
│   └── Types: created, edited, published, commented
├── Content::CommentContribution
│   └── Types: created, helpful_feedback
├── Event::CreationContribution
│   └── Types: created_event, hosted_event, moderated_event
├── Event::ParticipationContribution
│   └── Types: attended, rsvp, checked_in
├── Community::ModerationContribution
│   └── Types: reviewed_report, resolved_report, moderated_content, welcomed_member
├── Exchange::OfferContribution
│   └── Types: created_offer, fulfilled_offer, received_positive_feedback
└── Exchange::RequestContribution
    └── Types: created_request, fulfilled_request
```

### Key Database Tables

1. **better_together_contributions** - STI table for all contribution types
2. **better_together_contributor_stats** - Cached aggregated statistics per person
3. **better_together_github_tracked_repositories** - Repositories to monitor (existing from GitHub integration)

### Core Concepts

- **Contribution Categories**: code, content, community, moderation, event, exchange
- **Contribution Types**: Specific actions within each category
- **Points System**: Each contribution type has a point value
- **Privacy Levels**: public/private contributions
- **Polymorphic Associations**: contributable links to any trackable model

---

## Phase 1: Core Infrastructure

**Duration**: 1 week  
**Dependencies**: None

### 1.1 Base Contribution Model

**File**: `app/models/better_together/contribution.rb`

**Features**:
- STI base class with `type` column
- Polymorphic `contributable` association
- `contributor` belongs_to Person
- `contribution_category` enum (code, content, community, etc.)
- `points` integer column
- `contributed_at` timestamp
- JSONB `metadata` for flexible data storage
- Privacy controls
- TrackedActivity integration

**Tasks**:
- [ ] Create migration for contributions table
- [ ] Implement base Contribution model
- [ ] Add validations (type, contributor, contributed_at)
- [ ] Implement scopes (recent, by_contributor, in_date_range, by_category)
- [ ] Add metadata store_attributes helper
- [ ] Implement `calculate_points` method (override in subclasses)
- [ ] Add display helpers (icon, display_title)
- [ ] Integrate with PublicActivity (TrackedActivity concern)
- [ ] Add Privacy concern
- [ ] Create contribution policy

**Acceptance Criteria**:
- ✅ Base model can be instantiated
- ✅ Associations work correctly
- ✅ Scopes filter data appropriately
- ✅ Privacy filtering works
- ✅ STI type column properly discriminates subclasses

### 1.2 Contributor Statistics Model

**File**: `app/models/better_together/contributor_stats.rb`

**Features**:
- One record per person
- Cached counts by category
- Cached points by category
- Total contributions and points
- Contribution streaks (current and longest)
- First and last contribution timestamps
- Rankings (overall and by category)
- Tier system (bronze, silver, gold, platinum, diamond)

**Tasks**:
- [ ] Create migration for contributor_stats table
- [ ] Implement ContributorStats model
- [ ] Add validation (unique contributor_id)
- [ ] Implement `refresh_for_person` class method using Arel for aggregations
- [ ] Implement streak calculation methods using Arel queries
- [ ] Add tier calculation method
- [ ] Add ranking update logic using Arel window functions
- [ ] Create background job for stats refresh
- [ ] Ensure all queries use Arel (no raw SQL)

**Acceptance Criteria**:
- ✅ Stats can be refreshed for any person
- ✅ Streak calculations work correctly
- ✅ Tier assignments are accurate
- ✅ Stats update when contributions are created/destroyed

### 1.3 Person Model Integration

**File**: `app/models/better_together/person.rb`

**Tasks**:
- [ ] Add `has_many :contributions` association
- [ ] Add `has_one :contributor_stats` association
- [ ] Add `contributor?` helper method
- [ ] Add convenience methods for contribution queries

**Acceptance Criteria**:
- ✅ Person can access their contributions
- ✅ Person can access their statistics
- ✅ Helper methods work as expected

### 1.4 Achievement Service

**File**: `app/services/better_together/achievement_service.rb`

**Features**:
- Define achievement milestones
- Check for milestone completion
- Trigger notifications on achievements

**Tasks**:
- [ ] Create AchievementService class
- [ ] Define milestone constants (first_commit, 10_commits, etc.)
- [ ] Implement `check_all_milestones` method
- [ ] Implement milestone-specific check methods
- [ ] Integrate with notification system

**Acceptance Criteria**:
- ✅ Service can check milestones for any contribution
- ✅ Notifications are sent when milestones are reached
- ✅ No duplicate notifications for same milestone

---

## Phase 2: GitHub Integration

**Duration**: 1 week  
**Dependencies**: Phase 1, Existing GitHub OAuth integration

### 2.1 Rename Existing GitHub Client

**Current**: `app/integrations/better_together/github.rb`  
**New**: `app/integrations/better_together/github/client.rb`

**Tasks**:
- [ ] Move github.rb to github/client.rb
- [ ] Update namespace to `BetterTogether::Github::Client`
- [ ] Update PersonPlatformIntegration#github_client reference
- [ ] Update all tests
- [ ] Update documentation

### 2.2 GitHub Contribution Model

**File**: `app/models/better_together/github/contribution.rb`

**Features**:
- Inherits from Contribution
- Types: commit, pull_request, issue, code_review, release
- Auto-categorizes as 'code'
- GitHub-specific metadata (github_id, url, additions, deletions, merged, etc.)
- Points calculation by type

**Tasks**:
- [ ] Create Github::Contribution model
- [ ] Define contribution_type enum
- [ ] Implement metadata store_attributes
- [ ] Implement points calculation logic
- [ ] Implement icon method
- [ ] Add validations
- [ ] Create factory for testing

**Acceptance Criteria**:
- ✅ Model inherits from Contribution correctly
- ✅ STI type is set automatically
- ✅ Points are calculated correctly for each type
- ✅ Metadata stores GitHub-specific data

### 2.3 GitHub Tracked Repository Enhancement

**File**: `app/models/better_together/github/tracked_repository.rb`

**Tasks**:
- [ ] Add association to contributions
- [ ] Update sync service to create contributions
- [ ] Add contribution tracking to sync jobs

**Acceptance Criteria**:
- ✅ Tracked repositories link to contributions
- ✅ Sync creates contribution records

### 2.4 GitHub Sync Service Updates

**File**: `app/services/better_together/github/sync_service.rb`

**Tasks**:
- [ ] Update sync_commits to create Github::Contribution records
- [ ] Update sync_pull_requests to create contributions
- [ ] Update sync_issues to create contributions
- [ ] Map GitHub users to platform persons
- [ ] Handle contribution updates (idempotent)
- [ ] Update tests

**Acceptance Criteria**:
- ✅ Sync creates contribution records
- ✅ Duplicate contributions are not created
- ✅ Person matching works correctly
- ✅ Stats are updated after sync

### 2.5 GitHub Achievement Notifier

**File**: `app/notifiers/better_together/github/achievement_notifier.rb`

**Tasks**:
- [ ] Create notifier for GitHub achievements
- [ ] Add email delivery option
- [ ] Add i18n translations
- [ ] Create notification templates

**Acceptance Criteria**:
- ✅ Notifications are sent on achievements
- ✅ Email delivery works
- ✅ Translations exist for all locales

---

## Phase 3: Content Contributions

**Duration**: 1 week  
**Dependencies**: Phase 1

### 3.1 Page Contribution Model

**File**: `app/models/better_together/content/page_contribution.rb`

**Features**:
- Types: created, edited, published, translated, reviewed
- Metadata: page_title, page_url, word_count, blocks_added, locale
- Points with word count bonus

**Tasks**:
- [ ] Create Content::PageContribution model
- [ ] Define contribution_type enum
- [ ] Implement metadata store
- [ ] Implement points calculation
- [ ] Add validations
- [ ] Create factory

**Acceptance Criteria**:
- ✅ Model works with STI
- ✅ Points include word count bonus
- ✅ Metadata stores page details

### 3.2 Page Model Integration

**File**: `app/models/better_together/page.rb`

**Tasks**:
- [ ] Add after_create callback to track creation
- [ ] Add after_update callback to track edits
- [ ] Add after_update callback to track publishing
- [ ] Add method to calculate word count
- [ ] Update tests

**Acceptance Criteria**:
- ✅ Page creation creates contribution
- ✅ Page edits create contributions (when content changes)
- ✅ Publishing creates separate contribution
- ✅ Tests verify contribution creation

### 3.3 Post Contribution Model

**File**: `app/models/better_together/content/post_contribution.rb`

**Features**:
- Types: created, edited, published, commented
- Similar to page contributions

**Tasks**:
- [ ] Create Content::PostContribution model
- [ ] Implement similar to PageContribution
- [ ] Create factory

### 3.4 Post Model Integration

**File**: `app/models/better_together/post.rb`

**Tasks**:
- [ ] Add contribution tracking callbacks
- [ ] Update tests

### 3.5 Comment Contribution Model

**File**: `app/models/better_together/content/comment_contribution.rb`

**Tasks**:
- [ ] Create model
- [ ] Integrate with Comment model

**Acceptance Criteria**:
- ✅ All content types track contributions
- ✅ Tests verify tracking

---

## Phase 4: Community & Event Contributions

**Duration**: 1 week  
**Dependencies**: Phase 1

### 4.1 Event Creation Contribution

**File**: `app/models/better_together/event/creation_contribution.rb`

**Features**:
- Types: created_event, hosted_event, moderated_event
- Metadata: event_title, event_url, attendees_count, event_date
- Points with attendee bonus

**Tasks**:
- [ ] Create Event::CreationContribution model
- [ ] Implement points with attendee scaling
- [ ] Create factory

### 4.2 Event Participation Contribution

**File**: `app/models/better_together/event/participation_contribution.rb`

**Features**:
- Types: attended, rsvp, checked_in
- Tracks event participation

**Tasks**:
- [ ] Create Event::ParticipationContribution model
- [ ] Create factory

### 4.3 Event Model Integration

**File**: `app/models/better_together/event.rb`

**Tasks**:
- [ ] Add callback to track event creation
- [ ] Update tests

### 4.4 Event Attendance Integration

**File**: `app/models/better_together/event_attendance.rb`

**Tasks**:
- [ ] Add callback to track attendance
- [ ] Update tests

### 4.5 Community Moderation Contribution

**File**: `app/models/better_together/community/moderation_contribution.rb`

**Features**:
- Types: reviewed_report, resolved_report, moderated_content, welcomed_member
- Metadata: action_taken, report_id, resolution

**Tasks**:
- [ ] Create Community::ModerationContribution model
- [ ] Integrate with Report model
- [ ] Create factory

**Acceptance Criteria**:
- ✅ Event and community contributions tracked
- ✅ Tests verify tracking

---

## Phase 5: Statistics & Leaderboards

**Duration**: 1 week  
**Dependencies**: Phases 1-4

### 5.1 Stats Refresh Job

**File**: `app/jobs/better_together/refresh_contributor_stats_job.rb`

**Tasks**:
- [ ] Create background job
- [ ] Implement efficient stats calculation using Arel queries
- [ ] Use Arel for all aggregations (SUM, COUNT, MAX, MIN)
- [ ] Add error handling
- [ ] Queue on :metrics queue

**Acceptance Criteria**:
- ✅ Job refreshes stats correctly
- ✅ Job handles errors gracefully

### 5.2 Rankings Refresh Job

**File**: `app/jobs/better_together/refresh_contributor_rankings_job.rb`

**Tasks**:
- [ ] Create job to calculate rankings using Arel
- [ ] Implement overall ranking with Arel window functions (ROW_NUMBER)
- [ ] Implement category rankings with Arel PARTITION BY
- [ ] Use Arel for all ranking queries (no raw SQL)
- [ ] Store in contributor_stats

**Acceptance Criteria**:
- ✅ Rankings calculated correctly
- ✅ Ties handled appropriately

### 5.3 Contributions Controller

**File**: `app/controllers/better_together/contributions_controller.rb`

**Features**:
- Index action with filtering
- Timeframe filtering (today, week, month, year, all)
- Category filtering
- Pagination

**Tasks**:
- [ ] Create controller
- [ ] Implement index action
- [ ] Implement filtering logic
- [ ] Add authorization
- [ ] Create views
- [ ] Add routes

**Acceptance Criteria**:
- ✅ Index displays contributions
- ✅ Filtering works correctly
- ✅ Pagination works
- ✅ Authorization enforced

### 5.4 Leaderboard Controller

**File**: `app/controllers/better_together/leaderboards_controller.rb`

**Features**:
- Overall leaderboard
- Category leaderboards
- Timeframe options

**Tasks**:
- [ ] Create controller
- [ ] Implement leaderboard queries using Arel
- [ ] Use Arel for filtering, sorting, and limiting results
- [ ] Ensure no raw SQL in query building
- [ ] Add caching
- [ ] Create views
- [ ] Add routes

**Acceptance Criteria**:
- ✅ Leaderboards display correctly
- ✅ Filtering works
- ✅ Performance is acceptable

### 5.5 Person Contributions View

**Features**:
- Person-specific contribution history
- Stats display
- Achievement badges

**Tasks**:
- [ ] Add route under person namespace
- [ ] Create controller action
- [ ] Create view
- [ ] Add navigation link

**Acceptance Criteria**:
- ✅ Person can view their contributions
- ✅ Stats displayed accurately

---

## Phase 6: Dashboard & Reporting

**Duration**: 1 week  
**Dependencies**: Phase 5

### 6.1 Hub Dashboard Integration

**File**: `app/controllers/better_together/hub_controller.rb`

**Tasks**:
- [ ] Add recent contributions to hub index
- [ ] Add top contributors widget
- [ ] Add contribution stats summary
- [ ] Update views

**Acceptance Criteria**:
- ✅ Hub shows contribution activity
- ✅ Performance is acceptable

### 6.2 Host Dashboard Integration

**File**: `app/controllers/better_together/host/dashboard_controller.rb`

**Tasks**:
- [ ] Add contribution metrics
- [ ] Add contribution chart/graph
- [ ] Add contribution type breakdown

**Acceptance Criteria**:
- ✅ Host dashboard shows contribution metrics

### 6.3 Contribution Report Model

**File**: `app/models/better_together/metrics/contribution_report.rb`

**Features**:
- CSV, JSON, PDF export
- Date range filtering
- Category filtering
- Contributor filtering

**Tasks**:
- [ ] Create model extending Metrics::Report pattern
- [ ] Implement report generation using Arel for all queries
- [ ] Use Arel for filtering, grouping, and aggregations
- [ ] Implement file exports
- [ ] Ensure no raw SQL in report queries
- [ ] Create controller
- [ ] Create views
- [ ] Add routes

**Acceptance Criteria**:
- ✅ Reports can be generated
- ✅ Exports work correctly
- ✅ Filtering works

### 6.4 Activity Feed Integration

**Tasks**:
- [ ] Ensure contributions appear in activity feed
- [ ] Add contribution-specific activity cards
- [ ] Test visibility rules

**Acceptance Criteria**:
- ✅ Contributions visible in activity feed
- ✅ Privacy rules respected

---

## Testing Strategy

### Unit Tests

**Coverage**: All models, services, jobs

**Key Test Areas**:
- STI inheritance works correctly
- Associations function properly
- Validations enforce rules
- Scopes filter correctly
- Points calculation accurate
- Metadata storage/retrieval
- Streak calculations correct

**Example Tests**:
```ruby
# spec/models/better_together/contribution_spec.rb
RSpec.describe BetterTogether::Contribution do
  describe 'STI' do
    it 'has correct type for subclasses'
    it 'allows querying by type'
    it 'loads correct subclass from database'
  end
  
  describe 'associations' do
    it { should belong_to(:contributor) }
    it { should belong_to(:contributable).optional }
  end
  
  describe 'scopes' do
    describe '.recent'
    describe '.by_contributor'
    describe '.in_date_range'
    describe '.by_category'
  end
end

# spec/models/better_together/github/contribution_spec.rb
RSpec.describe BetterTogether::Github::Contribution do
  describe 'points calculation' do
    it 'assigns 5 points for commits'
    it 'assigns 25 points for merged PRs'
    it 'assigns 10 points for unmerged PRs'
  end
  
  describe 'icon' do
    it 'returns correct icon for each type'
  end
end

# spec/models/better_together/contributor_stats_spec.rb
RSpec.describe BetterTogether::ContributorStats do
  describe '.refresh_for_person' do
    it 'calculates total contributions using Arel'
    it 'calculates points by category using Arel SUM'
    it 'calculates current streak using Arel queries'
    it 'calculates longest streak using Arel queries'
    it 'uses Arel for all database queries (no raw SQL)'
  end
  
  describe 'tier' do
    it 'returns bronze for 0-99 points'
    it 'returns silver for 100-499 points'
    it 'returns gold for 500-999 points'
    it 'returns platinum for 1000-4999 points'
    it 'returns diamond for 5000+ points'
  end
end
```

### Integration Tests

**Coverage**: Controllers, full workflows

**Key Test Areas**:
- Contribution creation workflows
- Stats refresh workflows
- Leaderboard queries
- Report generation
- Activity feed integration

**Example Tests**:
```ruby
# spec/requests/better_together/contributions_spec.rb
RSpec.describe '/better_together/contributions', :as_user do
  describe 'GET /index' do
    it 'displays contributions'
    it 'filters by timeframe'
    it 'filters by category'
    it 'paginates results'
  end
end

# spec/requests/better_together/leaderboards_spec.rb
RSpec.describe '/better_together/leaderboards', :as_user do
  describe 'GET /show' do
    it 'displays top contributors'
    it 'filters by timeframe'
    it 'filters by category'
  end
end
```

### System/Feature Tests

**Coverage**: End-to-end workflows

**Key Test Areas**:
- Page creation creates contribution
- GitHub sync creates contributions
- Leaderboard displays correctly
- Achievement notifications sent
- Reports generate successfully

**Example Tests**:
```ruby
# spec/features/contribution_tracking_spec.rb
RSpec.feature 'Contribution Tracking' do
  scenario 'creating a page creates a contribution' do
    # Create page
    # Verify contribution created
    # Verify stats updated
  end
  
  scenario 'viewing leaderboard' do
    # Create contributions
    # Visit leaderboard
    # Verify rankings
  end
end
```

### Performance Tests

**Key Areas**:
- Leaderboard query performance
- Stats refresh performance
- Large contribution sets

---

## Migration Path

### Database Migrations

**Order of Execution**:

1. **Create contributions table** (`YYYYMMDD120000_create_better_together_contributions.rb`)
   - Includes type column for STI
   - Includes all necessary indexes
   
2. **Create contributor_stats table** (`YYYYMMDD120001_create_better_together_contributor_stats.rb`)
   - One record per person
   - Includes ranking columns

3. **Add contribution tracking to existing models** (if needed)
   - May require callbacks or observers

### Data Migration

**If migrating existing data**:

1. Create migration to backfill contributions from existing records
2. Run stats refresh for all persons
3. Calculate initial rankings

**Script**: `db/scripts/backfill_contributions.rb`

```ruby
# Backfill page contributions
BetterTogether::Page.find_each do |page|
  BetterTogether::Content::PageContribution.create!(
    contributor: page.creator,
    contributable: page,
    contribution_type: 'created',
    contributed_at: page.created_at,
    metadata: { 'page_title' => page.title }
  )
end

# Refresh all stats
BetterTogether::Person.find_each do |person|
  BetterTogether::ContributorStats.refresh_for_person(person)
end
```

### Rollback Plan

If issues arise:
1. Disable contribution tracking (feature flag)
2. Stop background jobs
3. Roll back migrations
4. Restore from backup if necessary

---

## Documentation Requirements

### Developer Documentation

**File**: `docs/developers/systems/contribution_tracking_system.md`

**Contents**:
- System overview
- Architecture diagrams
- Model relationships
- How to add new contribution types
- Points system explanation
- Testing guidelines
- Troubleshooting

### Platform Organizer Documentation

**File**: `docs/platform_organizers/contribution_tracking_management.md`

**Contents**:
- How to view contributions
- How to generate reports
- Understanding leaderboards
- Managing achievements
- Privacy considerations

### User Documentation

**File**: `docs/end_users/contributions_and_achievements.md`

**Contents**:
- How contributions are tracked
- How to view your contributions
- Understanding the points system
- Achievement badges
- Privacy settings

### API Documentation

If exposing via API:
- Document contribution endpoints
- Document stats endpoints
- Document leaderboard endpoints

---

## Platform Settings

### Configuration Options

Add to Platform settings:

```ruby
store_attributes :settings do
  # Contribution tracking
  contribution_tracking_enabled Boolean, default: true
  contribution_leaderboard_public Boolean, default: true
  contribution_achievements_enabled Boolean, default: true
  
  # Point multipliers (for customization)
  contribution_point_multiplier Float, default: 1.0
  
  # Privacy
  contribution_default_privacy String, default: 'public'
end
```

### Community Settings

Add to Community settings:

```ruby
store_attributes :settings do
  community_contributions_visible Boolean, default: true
  community_leaderboard_enabled Boolean, default: true
end
```

---

## Risks & Mitigation

### Performance Risks

**Risk**: Leaderboard queries slow with many contributors  
**Mitigation**: 
- Use cached contributor_stats table
- Implement pagination
- Add database indexes
- Use background jobs for ranking updates
- Use Arel for efficient query generation
- Leverage Arel's query optimization capabilities

**Risk**: Stats refresh too slow  
**Mitigation**:
- Optimize query efficiency using Arel
- Use Arel aggregations (SUM, COUNT) instead of iterating
- Use incremental updates where possible
- Queue refresh jobs appropriately
- Profile Arel-generated SQL for optimization

### Data Integrity Risks

**Risk**: Stats get out of sync with contributions  
**Mitigation**:
- Callbacks ensure stats refresh on contribution changes
- Periodic full refresh job
- Monitoring and alerts

**Risk**: STI type confusion  
**Mitigation**:
- Strong validations
- Comprehensive tests
- Clear documentation

### Privacy Risks

**Risk**: Private contributions exposed  
**Mitigation**:
- Policy-based authorization
- Privacy scopes on all queries
- Tests verify privacy enforcement

---

## Success Metrics

### Technical Metrics

- ✅ All tests passing (>95% coverage)
- ✅ Leaderboard queries < 500ms
- ✅ Stats refresh < 5 seconds per person
- ✅ Zero N+1 queries in contribution views

### Product Metrics

- User engagement with leaderboards
- Number of contributions tracked
- Achievement notification open rates
- Report generation usage

---

## Timeline

### Week 1: Core Infrastructure
- Base models and migrations
- Stats system
- Achievement service

### Week 2: GitHub Integration
- Rename existing client
- GitHub contribution model
- Sync service updates

### Week 3: Content & Community
- Content contribution models
- Event contribution models
- Community moderation tracking

### Week 4: UI & Reporting
- Controllers and views
- Leaderboards
- Reports
- Dashboard integration

### Week 5: Testing & Polish
- Complete test coverage
- Performance optimization
- Documentation
- Bug fixes

---

## Dependencies

### Existing Systems

- ✅ GitHub OAuth integration (complete)
- ✅ PublicActivity (TrackedActivity concern)
- ✅ Metrics system pattern
- ✅ Person model
- ✅ Content models (Page, Post, Comment)
- ✅ Event models
- ✅ Authorization system (Pundit)

### Required Gems

No new gems required - uses existing stack:
- PublicActivity
- Pundit
- Sidekiq
- ActiveRecord
- ActionText

---

## Post-Launch Enhancements

### Future Considerations

1. **Badges & Trophies**: Visual achievement badges
2. **Contribution Streaks**: Streak-based challenges
3. **Team Contributions**: Track team/community totals
4. **Contribution Goals**: Personal or community goals
5. **API Access**: REST API for contribution data
6. **Webhooks**: Notify external systems of contributions
7. **Export Integrations**: LinkedIn, resume builders
8. **Contribution Insights**: AI-powered insights
9. **Gamification**: Challenges, quests, competitions
10. **Social Sharing**: Share achievements on social media

---

## Appendix

### Code Samples

See comprehensive code examples in the research phase above, including:
- Base Contribution model
- Subclass implementations
- Migration templates
- Controller patterns
- Service objects
- Background jobs
- View templates

### Arel Query Examples

**Stats Aggregation using Arel**:
```ruby
# ContributorStats.refresh_for_person implementation
class << self
  def refresh_for_person(person)
    contributions = BetterTogether::Contribution.arel_table
    
    # Total contributions count using Arel
    total = BetterTogether::Contribution
      .where(contributor: person)
      .select(contributions[:id].count.as('total'))
      .first
      &.total || 0
    
    # Points by category using Arel GROUP BY and SUM
    category_stats = BetterTogether::Contribution
      .where(contributor: person)
      .group(:contribution_category)
      .select(
        contributions[:contribution_category],
        contributions[:points].sum.as('total_points')
      )
    
    # Build stats hash
    stats = category_stats.each_with_object({}) do |stat, hash|
      hash["#{stat.contribution_category}_count"] = stat.total_points
    end
    
    # Update or create stats record
    person.contributor_stats.update_or_create!(stats)
  end
end
```

**Ranking using Arel Window Functions**:
```ruby
# RefreshContributorRankingsJob implementation
class RefreshContributorRankingsJob < ApplicationJob
  def perform
    stats = BetterTogether::ContributorStats.arel_table
    
    # Use Arel window function for ranking
    ranking_query = BetterTogether::ContributorStats
      .select(
        stats[Arel.star],
        Arel::Nodes::Window.new(
          Arel::Nodes::NamedFunction.new('ROW_NUMBER', [])
        ).order(stats[:total_points].desc).as('rank')
      )
    
    # Execute and update rankings
    ranking_query.find_each do |stat_with_rank|
      stat_with_rank.update_column(:overall_ranking, stat_with_rank.rank)
    end
  end
end
```

**Leaderboard Query using Arel**:
```ruby
# LeaderboardsController implementation
def show
  stats = BetterTogether::ContributorStats.arel_table
  
  @leaders = BetterTogether::ContributorStats
    .joins(:contributor)
    .where(stats[:total_points].gt(0))
    .order(stats[:total_points].desc)
    .limit(100)
  
  # Category-specific using Arel
  if params[:category].present?
    category_points = "#{params[:category]}_points"
    @leaders = @leaders.order(stats[category_points].desc)
  end
end
```

**Date Range Filtering using Arel**:
```ruby
# Contributions with date range using Arel
contributions = BetterTogether::Contribution.arel_table

scope :in_date_range, ->(start_date, end_date) {
  where(
    contributions[:contributed_at].gteq(start_date)
      .and(contributions[:contributed_at].lteq(end_date))
  )
}
```

### Arel Best Practices

**Query Construction**:
- Always use Arel for complex queries (aggregations, joins, subqueries)
- Never concatenate raw SQL strings
- Use Arel's type-safe query building
- Leverage Arel's automatic SQL sanitization

**Performance**:
- Use Arel to generate optimized SQL
- Profile generated SQL with EXPLAIN
- Add appropriate indexes for Arel-generated queries
- Use Arel's query chaining for lazy evaluation

**Maintainability**:
- Keep Arel queries readable with proper formatting
- Extract complex Arel queries to scopes or query objects
- Document Arel window functions and advanced features
- Test Arel queries thoroughly

**Security**:
- Arel automatically sanitizes inputs
- Never bypass Arel with raw SQL for user inputs
- Use Arel's parameterized queries
- Leverage Arel for safe dynamic query building

### Related Documentation

- [GitHub API Integration](../developers/github_api_integration.md)
- [Metrics System](../developers/systems/metrics_system.md)
- [PublicActivity Integration](../developers/architecture/models_and_concerns.md)
- [STI Patterns](../developers/architecture/polymorphic_and_sti.md)
- [Arel Documentation](https://www.rubydoc.info/gems/arel)

### References

- Single-Table Inheritance: Rails Guides
- PublicActivity gem: https://github.com/public-activity/public_activity
- Better Together contribution patterns: Internal codebase research

---

**Next Steps**: 
1. Review this plan with team
2. Create GitHub issues for each phase
3. Set up project board
4. Begin Phase 1 implementation
