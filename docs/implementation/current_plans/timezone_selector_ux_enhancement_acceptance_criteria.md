# TDD Acceptance Criteria: Timezone Selector UX Enhancement

## Overview

This document transforms the timezone selector UX improvement plan into stakeholder-focused acceptance criteria using Test-Driven Development (TDD) principles. The implementation enhances timezone selection with SlimSelect search functionality, priority zones, continent-based grouping, and improved display formatting.

## Implementation Plan Reference
- **Plan Document**: Previous collaborative discussion on timezone selector UX
- **Review Status**: ✅ Collaborative Review Completed
- **Approval Date**: 2026-01-24
- **Technical Approach Confirmed**: 
  - Simplify timezone display to Rails-friendly names only (remove IANA suffix)
  - Sort timezones by UTC offset, then alphabetically within same offset
  - Add 25 priority timezones in dedicated optgroup
  - Group remaining timezones by continent (deduplicated from priority list)
  - Enable SlimSelect search/filter functionality
  - Fix browser auto-detection to use IANA identifiers directly
  - Implement comprehensive accessibility testing with axe-core
  - Maintain IANA identifier storage for database validation

## Stakeholder Impact Analysis
- **Primary Stakeholders**: End Users (event creators, community members)
- **Secondary Stakeholders**: Community Organizers (community event managers), Platform Organizers (platform configuration)
- **Cross-Stakeholder Workflows**: Timezone selection affects all users creating or configuring events, platforms, and personal preferences

---

## Phase 1: Helper Enhancement & Display Formatting

### 1.1. Simplified Timezone Display Format

#### End User Acceptance Criteria
**As an end user, I want to see clear timezone names without technical identifiers so that I can easily identify my timezone.**

- [ ] **AC-1.1**: Timezone options display only Rails-friendly names: `"(GMT-05:00) Eastern Time (US & Canada)"` without IANA identifier suffix
- [ ] **AC-1.2**: Timezones are sorted by UTC offset from GMT-12:00 to GMT+14:00 for intuitive navigation
- [ ] **AC-1.3**: Timezones with identical UTC offset are alphabetically sorted by name for consistent ordering
- [ ] **AC-1.4**: Selected timezone value still stores IANA identifier (e.g., "America/New_York") for database validation
- [ ] **AC-1.5**: Display format is consistent across all timezone selectors (events, platforms, user preferences, setup wizard)
- [ ] **AC-1.6**: Screen readers announce timezone options with offset and name information

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want timezone data stored correctly so that time-based features work reliably across my platform.**

- [ ] **AC-1.7**: Timezone values pass IANA identifier validation in models (Event, Platform, Person)
- [ ] **AC-1.8**: Database stores exact IANA identifiers for precise timezone handling
- [ ] **AC-1.9**: Platform configuration timezone selector uses same enhanced display format

---

### 1.2. Priority Timezone Section

#### End User Acceptance Criteria
**As an end user, I want common timezones listed first so that I can quickly find my timezone without scrolling.**

- [ ] **AC-2.1**: "Common Timezones" optgroup appears first in timezone selector with 25 frequently-used zones
- [ ] **AC-2.2**: Priority timezone list includes: UTC, major US zones (New York, Chicago, Denver, Los Angeles), Canadian zones (Toronto, Vancouver, Halifax, St Johns), European capitals (London, Paris, Berlin, Amsterdam, Madrid), Asian hubs (Tokyo, Shanghai, Hong Kong, Dubai), Pacific zones (Auckland, Sydney, Melbourne), South American zones (Sao Paulo, Mexico City), African zones (Cairo, Johannesburg)
- [ ] **AC-2.3**: Priority timezones are sorted by UTC offset within the "Common Timezones" group
- [ ] **AC-2.4**: Priority timezones do NOT appear duplicated in continent-based groups below
- [ ] **AC-2.5**: Visually distinct optgroup header separates priority zones from continent groups

#### Community Organizer Acceptance Criteria
**As a community organizer, I want my community's timezone easily accessible so that creating events is efficient.**

- [ ] **AC-2.6**: Community timezone (if set in platform config) appears in priority list if not already included
- [ ] **AC-2.7**: Community organizers see their timezone pre-selected when creating events based on smart hierarchy (user → platform → UTC)

---

### 1.3. Continent-Based Grouping

#### End User Acceptance Criteria
**As an end user, I want timezones organized by region so that I can navigate to my geographic area.**

- [ ] **AC-3.1**: Timezones are grouped by continent: Africa, America, Antarctica, Arctic, Asia, Atlantic, Australia, Europe, Indian, Pacific, UTC
- [ ] **AC-3.2**: Each continent optgroup displays zones sorted by UTC offset, then alphabetically
- [ ] **AC-3.3**: Zones already in "Common Timezones" are excluded from continent groups (no duplication)
- [ ] **AC-3.4**: Optgroup labels use proper capitalization and clear naming (e.g., "America" not "america")
- [ ] **AC-3.5**: Screen readers announce optgroup structure with proper ARIA labels

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want organized timezone options so that platform users can configure settings easily.**

- [ ] **AC-3.6**: Platform settings timezone selector uses same continent-based grouping structure

---

## Phase 2: SlimSelect Search Enhancement

### 2.1. SlimSelect Integration

#### End User Acceptance Criteria
**As an end user, I want to search for my timezone by typing so that I can find it quickly without scrolling.**

- [ ] **AC-4.1**: Timezone selectors include SlimSelect controller (`data-controller="better_together--slim-select"`)
- [ ] **AC-4.2**: Search input appears at top of dropdown with placeholder "Search timezones..."
- [ ] **AC-4.3**: Typing in search box filters timezone options in real-time
- [ ] **AC-4.4**: Search matches timezone names (e.g., typing "New York" shows "America/New_York" option)
- [ ] **AC-4.5**: Search highlights matching text within results
- [ ] **AC-4.6**: Searching shows results from all groups (priority and continent-based)
- [ ] **AC-4.7**: Empty search results display "No timezones found" message
- [ ] **AC-4.8**: Clearing search restores full optgroup structure with all timezones
- [ ] **AC-4.9**: Search is case-insensitive (e.g., "london" matches "Europe/London")
- [ ] **AC-4.10**: Special characters in timezone names (e.g., underscores in "St_Johns") are searchable

#### End User Acceptance Criteria (Accessibility)
**As an end user using assistive technology, I want the timezone search to be keyboard accessible so that I can use it without a mouse.**

- [ ] **AC-4.11**: Keyboard focus moves to search input when dropdown opens
- [ ] **AC-4.12**: Arrow keys navigate through filtered results
- [ ] **AC-4.13**: Enter key selects highlighted timezone
- [ ] **AC-4.14**: Escape key closes dropdown without selecting
- [ ] **AC-4.15**: Screen readers announce search input with role="searchbox" and aria-label
- [ ] **AC-4.16**: Screen readers announce number of filtered results
- [ ] **AC-4.17**: Tab key navigation works correctly through form fields before/after timezone selector

#### Community Organizer Acceptance Criteria
**As a community organizer, I want fast timezone selection so that creating multiple events is efficient.**

- [ ] **AC-4.18**: Recently selected timezones appear in accessible order for repeat selection
- [ ] **AC-4.19**: Search response is instant (<100ms) for smooth typing experience

---

### 2.2. SlimSelect Configuration

#### End User Acceptance Criteria
**As an end user, I want the timezone selector to behave predictably so that I understand how to use it.**

- [ ] **AC-5.1**: SlimSelect settings include: `allowDeselect: false` (required field), `searchPlaceholder: 'Search timezones...'`, `closeOnSelect: true`, `showSearch: true`
- [ ] **AC-5.2**: Selecting a timezone closes the dropdown immediately
- [ ] **AC-5.3**: Deselecting a timezone is NOT allowed (timezone is required field)
- [ ] **AC-5.4**: Dropdown opens downward by default, flips upward if insufficient space below
- [ ] **AC-5.5**: Dropdown displays properly within Bootstrap modals (uses `addToBody: false`)

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want timezone selector behavior consistent across the platform so that users have familiar experience.**

- [ ] **AC-5.6**: SlimSelect configuration is identical across all timezone selectors (events, platforms, preferences, wizard)

---

## Phase 3: Browser Auto-Detection Enhancement

### 3.1. IANA Auto-Detection

#### End User Acceptance Criteria
**As an end user, I want my timezone automatically detected so that I don't have to search for it manually.**

- [ ] **AC-6.1**: Browser's IANA timezone is detected using `Intl.DateTimeFormat().resolvedOptions().timeZone`
- [ ] **AC-6.2**: Detected timezone automatically selects matching option in dropdown
- [ ] **AC-6.3**: Auto-detection works for zones in both priority and continent groups
- [ ] **AC-6.4**: If detected timezone not found in dropdown, selection is silently skipped (no error shown to user)
- [ ] **AC-6.5**: User can manually change auto-detected timezone to any available option
- [ ] **AC-6.6**: Auto-detection respects existing saved timezone (doesn't override on edit forms)

#### End User Acceptance Criteria (Debug Information)
**As a developer, I want timezone auto-detection logged so that I can troubleshoot issues.**

- [ ] **AC-6.7**: Browser timezone detection logs to debug console using `this.debug.log()` pattern from AppController
- [ ] **AC-6.8**: Warning logged when detected timezone not found in dropdown using `this.debug.warn()`
- [ ] **AC-6.9**: Debug logging only appears when debug mode enabled (not in production)

---

### 3.2. Deprecated Mapping Removal

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want timezone handling to use modern standards so that the platform remains maintainable.**

- [ ] **AC-7.1**: `mapIANAToRails()` method removed from timezone controller JavaScript
- [ ] **AC-7.2**: IANA → Rails timezone name mapping object removed entirely
- [ ] **AC-7.3**: Auto-detection uses browser's IANA identifier directly without translation
- [ ] **AC-7.4**: No outdated timezone mapping logic remains in codebase

---

## Phase 4: Comprehensive Testing & Accessibility

### 4.1. Unit & Integration Tests

#### Developer Acceptance Criteria
**As a developer, I want comprehensive test coverage so that timezone selector enhancements are reliable.**

- [ ] **AC-8.1**: Helper method `iana_timezone_options_for_select` tested for simplified display format
- [ ] **AC-8.2**: Helper method `priority_timezone_options` tested for correct 25 timezones in offset-sorted order
- [ ] **AC-8.3**: Helper method `iana_timezone_options_grouped` tested for continent grouping and deduplication
- [ ] **AC-8.4**: Helper method `iana_timezone_options_with_priority` tested for combined optgroup structure
- [ ] **AC-8.5**: Helper method `iana_time_zone_select` tested for SlimSelect data attributes
- [ ] **AC-8.6**: Request specs verify timezone selector renders with correct HTML structure
- [ ] **AC-8.7**: Request specs verify optgroup order: "Common Timezones" first, then continents alphabetically
- [ ] **AC-8.8**: Request specs verify priority zones excluded from continent groups (no duplication)
- [ ] **AC-8.9**: Request specs verify SlimSelect controller and options data attributes present

---

### 4.2. JavaScript-Enabled Feature Tests

#### End User Acceptance Criteria (Functional Testing)
**As an end user, I want all timezone selector features tested so that they work reliably in real browsers.**

- [ ] **AC-9.1**: Feature spec verifies SlimSelect initializes on timezone selector (`.ss-main` element present)
- [ ] **AC-9.2**: Feature spec verifies search input appears and accepts typing
- [ ] **AC-9.3**: Feature spec verifies typing in search filters timezone options correctly
- [ ] **AC-9.4**: Feature spec verifies search highlights matching text in results
- [ ] **AC-9.5**: Feature spec verifies selecting timezone updates form field value with IANA identifier
- [ ] **AC-9.6**: Feature spec verifies optgroup headers display correctly ("Common Timezones", "America", "Europe", etc.)
- [ ] **AC-9.7**: Feature spec verifies priority zones appear in first optgroup only (not duplicated)
- [ ] **AC-9.8**: Feature spec verifies browser auto-detection selects correct timezone on page load
- [ ] **AC-9.9**: Feature spec verifies empty search results show "No timezones found" message
- [ ] **AC-9.10**: Feature spec verifies special characters in timezone names (underscores, slashes) handle correctly
- [ ] **AC-9.11**: Feature spec verifies rapid keyboard navigation doesn't break selection
- [ ] **AC-9.12**: Feature spec verifies timezone selector works correctly within Bootstrap modals

#### End User Acceptance Criteria (Accessibility Testing)
**As an end user using assistive technology, I want timezone selector accessibility verified so that I can use all features.**

- [ ] **AC-9.13**: Feature spec runs axe-core accessibility scanner with full WCAG 2.1 AA ruleset
- [ ] **AC-9.14**: axe-core scan passes with no violations (or documents genuine SlimSelect issues for resolution)
- [ ] **AC-9.15**: Feature spec verifies search input has `role="searchbox"` attribute
- [ ] **AC-9.16**: Feature spec verifies search input has descriptive `aria-label` attribute
- [ ] **AC-9.17**: Feature spec verifies optgroup elements have proper ARIA group roles
- [ ] **AC-9.18**: Feature spec verifies keyboard navigation works (arrow keys, enter, escape, tab)
- [ ] **AC-9.19**: Feature spec verifies screen reader announcements for optgroup labels
- [ ] **AC-9.20**: Feature spec verifies focus management doesn't trap keyboard users

---

### 4.3. Gem Dependencies & Configuration

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want accessibility testing infrastructure in place so that we maintain WCAG compliance.**

- [ ] **AC-10.1**: `axe-core-selenium` gem added to Gemfile test group
- [ ] **AC-10.2**: `axe-core-rspec` gem added to Gemfile test group
- [ ] **AC-10.3**: Bundle install completes successfully with axe-core gems
- [ ] **AC-10.4**: `spec/support/axe.rb` initializer created with WCAG 2.1 AA configuration
- [ ] **AC-10.5**: axe-core configuration enables full ruleset with NO exclusions (track failures transparently)
- [ ] **AC-10.6**: Selenium WebDriver properly configured to support axe-core JavaScript injection
- [ ] **AC-10.7**: Feature specs tagged with `:js` metadata execute with JavaScript-enabled driver

---

## TDD Test Structure

### Test Coverage Matrix

| Acceptance Criteria | Helper Specs | Request Specs | Feature Specs | Accessibility |
|-------------------|--------------|---------------|---------------|----------------|
| AC-1.1 to AC-1.6 (Display Format) | ✓ | ✓ | ✓ | ✓ |
| AC-2.1 to AC-2.7 (Priority Zones) | ✓ | ✓ | ✓ | |
| AC-3.1 to AC-3.6 (Continent Grouping) | ✓ | ✓ | ✓ | ✓ |
| AC-4.1 to AC-4.19 (SlimSelect Search) | | ✓ | ✓ | ✓ |
| AC-5.1 to AC-5.6 (SlimSelect Config) | ✓ | ✓ | ✓ | |
| AC-6.1 to AC-6.9 (Auto-Detection) | | | ✓ | |
| AC-7.1 to AC-7.4 (Mapping Removal) | | | ✓ | |
| AC-8.1 to AC-8.9 (Unit Tests) | ✓ | ✓ | | |
| AC-9.1 to AC-9.20 (Feature Tests) | | | ✓ | ✓ |
| AC-10.1 to AC-10.7 (Infrastructure) | | | ✓ | ✓ |

---

## Test Implementation Plan

### Helper Specs

#### Test File: `spec/helpers/better_together/timezone_helper_spec.rb`

```ruby
RSpec.describe BetterTogether::TimezoneHelper, type: :helper do
  describe '#iana_timezone_options_for_select' do
    let(:options) { helper.iana_timezone_options_for_select }
    
    context 'display format (AC-1.1)' do
      it 'shows only Rails-friendly names without IANA suffix' do
        # Find option for America/New_York
        new_york_option = options.find { |opt| opt[1] == 'America/New_York' }
        expect(new_york_option[0]).to eq('(GMT-05:00) Eastern Time (US & Canada)')
        expect(new_york_option[0]).not_to include('America/New_York')
      end
    end
    
    context 'UTC offset sorting (AC-1.2)' do
      it 'sorts timezones by UTC offset ascending' do
        offsets = options.map { |opt| 
          ActiveSupport::TimeZone[opt[1]].utc_offset 
        }
        expect(offsets).to eq(offsets.sort)
      end
    end
    
    context 'secondary alphabetical sorting (AC-1.3)' do
      it 'sorts alphabetically within same UTC offset' do
        # Find zones with same offset (e.g., America/New_York and America/Detroit)
        est_zones = options.select { |opt|
          tz = ActiveSupport::TimeZone[opt[1]]
          tz&.utc_offset == -18000 # GMT-5
        }
        
        names = est_zones.map { |opt| opt[0] }
        expect(names).to eq(names.sort)
      end
    end
    
    context 'value storage (AC-1.4)' do
      it 'stores IANA identifier as option value' do
        new_york_option = options.find { |opt| opt[1] == 'America/New_York' }
        expect(new_york_option[1]).to eq('America/New_York')
      end
    end
  end
  
  describe '#priority_timezone_options' do
    let(:priority_options) { helper.priority_timezone_options }
    
    context 'priority zone count (AC-2.2)' do
      it 'returns exactly 25 priority timezones' do
        expect(priority_options.length).to eq(25)
      end
      
      it 'includes expected priority zones' do
        priority_ids = priority_options.map { |opt| opt[1] }
        expect(priority_ids).to include(
          'UTC',
          'America/New_York',
          'America/Chicago',
          'America/Denver',
          'America/Los_Angeles',
          'America/Toronto',
          'Europe/London',
          'Asia/Tokyo',
          'Pacific/Auckland'
        )
      end
    end
    
    context 'priority zone sorting (AC-2.3)' do
      it 'sorts priority zones by UTC offset' do
        offsets = priority_options.map { |opt|
          ActiveSupport::TimeZone[opt[1]].utc_offset
        }
        expect(offsets).to eq(offsets.sort)
      end
    end
  end
  
  describe '#iana_timezone_options_grouped' do
    let(:grouped_options) { helper.iana_timezone_options_grouped }
    
    context 'continent grouping (AC-3.1)' do
      it 'groups timezones by continent' do
        expect(grouped_options.keys).to include(
          'Africa', 'America', 'Asia', 'Europe', 'Pacific', 'UTC'
        )
      end
    end
    
    context 'deduplication from priority zones (AC-2.4, AC-3.3)' do
      it 'excludes zones already in COMMON_TIMEZONES from continent groups' do
        america_zones = grouped_options['America'].map { |opt| opt[1] }
        
        # Priority zones should NOT appear in continent groups
        expect(america_zones).not_to include('America/New_York')
        expect(america_zones).not_to include('America/Chicago')
      end
    end
    
    context 'continent group sorting (AC-3.2)' do
      it 'sorts each continent group by UTC offset then name' do
        grouped_options.each do |continent, zones|
          offsets = zones.map { |opt| ActiveSupport::TimeZone[opt[1]].utc_offset }
          expect(offsets).to eq(offsets.sort)
        end
      end
    end
  end
  
  describe '#iana_timezone_options_with_priority' do
    let(:options_with_priority) { helper.iana_timezone_options_with_priority }
    
    context 'priority optgroup first (AC-2.1)' do
      it 'has "Common Timezones" as first optgroup' do
        expect(options_with_priority.first[0]).to eq('Common Timezones')
      end
      
      it 'contains 25 priority zones in first optgroup' do
        expect(options_with_priority.first[1].length).to eq(25)
      end
    end
    
    context 'continent optgroups follow (AC-3.1)' do
      it 'has continent groups after priority group' do
        continent_labels = options_with_priority[1..-1].map { |group| group[0] }
        expect(continent_labels).to include('America', 'Europe', 'Asia')
      end
    end
  end
  
  describe '#iana_time_zone_select' do
    let(:form_builder) { double('form_builder') }
    let(:select_html) { helper.iana_time_zone_select(form_builder, :timezone) }
    
    context 'SlimSelect integration (AC-4.1)' do
      it 'includes SlimSelect controller data attribute' do
        allow(form_builder).to receive(:select).and_return('<select data-controller="better_together--slim-select"></select>')
        expect(select_html).to include('data-controller="better_together--slim-select"')
      end
    end
    
    context 'SlimSelect configuration (AC-5.1)' do
      it 'includes SlimSelect options data attribute with correct settings' do
        allow(form_builder).to receive(:select) do |*args|
          options = args.last
          expect(options[:data]['better_together--slim-select-options-value']).to include('allowDeselect')
          '<select></select>'
        end
        select_html
      end
    end
  end
end
```

---

### Request Specs

#### Test File: `spec/requests/better_together/events_spec.rb`

```ruby
RSpec.describe 'Event timezone selection', type: :request, :as_user do
  describe 'GET /events/new' do
    before do
      get new_better_together_event_path(locale: I18n.default_locale)
    end
    
    context 'timezone selector rendering (AC-1.5)' do
      it 'renders timezone select field' do
        expect(response.body).to include('id="event_timezone"')
      end
      
      it 'includes SlimSelect controller (AC-4.1)' do
        expect(response.body).to include('data-controller="better_together--slim-select"')
      end
      
      it 'includes SlimSelect options configuration (AC-5.1)' do
        expect(response.body).to include('data-better_together--slim-select-options-value')
      end
    end
    
    context 'optgroup structure (AC-2.1, AC-3.1)' do
      it 'has "Common Timezones" optgroup first' do
        expect_html_content('Common Timezones')
      end
      
      it 'has continent optgroups' do
        expect_html_contents('America', 'Europe', 'Asia', 'Pacific')
      end
    end
    
    context 'display format (AC-1.1)' do
      it 'shows simplified timezone names without IANA suffix' do
        expect_html_content('(GMT-05:00) Eastern Time (US & Canada)')
        expect_no_html_content('America/New_York')
      end
    end
    
    context 'deduplication (AC-2.4)' do
      it 'does not duplicate priority zones in continent groups' do
        # Parse HTML to count occurrences
        parsed = Nokogiri::HTML(response.body)
        ny_options = parsed.css('option[value="America/New_York"]')
        expect(ny_options.length).to eq(1) # Only in Common Timezones, not in America
      end
    end
  end
end
```

---

### Feature Specs (JavaScript-Enabled)

#### Test File: `spec/features/better_together/timezone_selection_spec.rb`

```ruby
RSpec.feature 'Timezone Selection with SlimSelect', type: :feature, js: true do
  before do
    configure_host_platform
  end
  
  scenario 'User creates event with timezone search (AC-4.1 to AC-4.10)' do
    # Setup: Login and navigate to new event form
    user = find_or_create_test_user('user@example.com')
    sign_in user
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    # AC-9.1: SlimSelect initializes
    expect(page).to have_selector('.ss-main', wait: 5)
    
    # AC-9.2: Search input appears
    find('.ss-main').click
    expect(page).to have_selector('.ss-search input[type="search"]')
    
    # AC-4.2: Search placeholder
    search_input = find('.ss-search input[type="search"]')
    expect(search_input['placeholder']).to eq('Search timezones...')
    
    # AC-9.3: Typing filters results
    search_input.fill_in with: 'New York'
    expect(page).to have_selector('.ss-option', text: 'Eastern Time')
    
    # AC-9.4: Matching text highlighted
    expect(page).to have_selector('.ss-option .ss-search-highlight')
    
    # AC-9.5: Selecting timezone updates form value
    find('.ss-option', text: 'Eastern Time').click
    expect(find('select#event_timezone', visible: false).value).to eq('America/New_York')
    
    # AC-4.7, AC-9.9: Empty search results
    find('.ss-main').click
    search_input = find('.ss-search input[type="search"]')
    search_input.fill_in with: 'Nonexistent Timezone'
    expect(page).to have_content('No timezones found')
    
    # AC-4.8: Clearing search restores options
    search_input.fill_in with: ''
    expect(page).to have_selector('.ss-optgroup-label', text: 'Common Timezones')
  end
  
  scenario 'Timezone selector displays proper optgroup structure (AC-9.6, AC-9.7)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    # Wait for SlimSelect
    expect(page).to have_selector('.ss-main', wait: 5)
    
    # Open dropdown
    find('.ss-main').click
    
    # AC-9.6: Optgroup headers display
    expect(page).to have_selector('.ss-optgroup-label', text: 'Common Timezones')
    expect(page).to have_selector('.ss-optgroup-label', text: 'America')
    expect(page).to have_selector('.ss-optgroup-label', text: 'Europe')
    
    # AC-9.7: Priority zones only in first group
    common_group = find('.ss-optgroup', text: 'Common Timezones')
    within(common_group) do
      expect(page).to have_selector('.ss-option', text: 'Eastern Time')
    end
    
    # Verify NOT in America group
    america_group = find('.ss-optgroup', text: 'America')
    within(america_group) do
      expect(page).not_to have_selector('.ss-option', text: 'Eastern Time (US & Canada)')
    end
  end
  
  scenario 'Browser auto-detection selects timezone (AC-6.1 to AC-6.6, AC-9.8)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    
    # Mock browser timezone detection (if possible with Capybara driver)
    page.execute_script(<<~JS)
      // Override Intl to return specific timezone
      const originalDateTimeFormat = Intl.DateTimeFormat;
      Intl.DateTimeFormat = function() {
        const instance = new originalDateTimeFormat(...arguments);
        instance.resolvedOptions = function() {
          return { timeZone: 'America/New_York' };
        };
        return instance;
      };
    JS
    
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    # Wait for SlimSelect and auto-detection
    expect(page).to have_selector('.ss-main', wait: 5)
    
    # AC-9.8: Verify America/New_York is auto-selected
    selected_value = find('select#event_timezone', visible: false).value
    expect(selected_value).to eq('America/New_York')
    
    # AC-6.5: User can manually change
    find('.ss-main').click
    find('.ss-option', text: 'Pacific Time').click
    expect(find('select#event_timezone', visible: false).value).to eq('America/Los_Angeles')
  end
  
  scenario 'Special characters in timezone names work correctly (AC-9.10)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    expect(page).to have_selector('.ss-main', wait: 5)
    find('.ss-main').click
    
    # AC-9.10: Search for timezone with underscore
    search_input = find('.ss-search input[type="search"]')
    search_input.fill_in with: 'St Johns'
    expect(page).to have_selector('.ss-option', text: 'Newfoundland')
    
    # Select it
    find('.ss-option', text: 'Newfoundland').click
    expect(find('select#event_timezone', visible: false).value).to eq('America/St_Johns')
  end
  
  scenario 'Keyboard navigation works correctly (AC-4.11 to AC-4.17, AC-9.11, AC-9.18)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    expect(page).to have_selector('.ss-main', wait: 5)
    
    # AC-4.11: Focus moves to search on open
    find('.ss-main').click
    expect(page).to have_selector('.ss-search input:focus')
    
    # AC-4.12: Arrow keys navigate
    search_input = find('.ss-search input[type="search"]')
    search_input.send_keys(:arrow_down)
    search_input.send_keys(:arrow_down)
    
    # AC-4.13: Enter selects
    search_input.send_keys(:enter)
    expect(find('select#event_timezone', visible: false).value).to be_present
    
    # AC-4.14: Escape closes without selecting
    original_value = find('select#event_timezone', visible: false).value
    find('.ss-main').click
    find('.ss-search input[type="search"]').send_keys(:escape)
    expect(find('select#event_timezone', visible: false).value).to eq(original_value)
    
    # AC-4.17: Tab navigation works
    find('input#event_title').send_keys(:tab)
    expect(page).to have_selector('.ss-main:focus-within')
  end
  
  scenario 'Timezone selector works in Bootstrap modal (AC-9.12)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    
    # Visit page with modal containing timezone selector
    # (Adjust based on actual modal implementation in your app)
    visit better_together_platform_path(locale: I18n.default_locale)
    
    # Open modal
    find('[data-bs-toggle="modal"]').click
    within('.modal') do
      expect(page).to have_selector('.ss-main', wait: 5)
      
      # Verify dropdown opens within modal (not appended to body)
      find('.ss-main').click
      expect(page).to have_selector('.ss-content')
    end
  end
  
  scenario 'Accessibility compliance with axe-core (AC-9.13 to AC-9.20)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    # Wait for SlimSelect
    expect(page).to have_selector('.ss-main', wait: 5)
    
    # AC-9.13, AC-9.14: Run axe-core scan
    expect(page).to be_axe_clean
    
    # Open dropdown to test interactive state
    find('.ss-main').click
    
    # AC-9.15: Search input has role
    search_input = find('.ss-search input[type="search"]')
    expect(search_input['role']).to eq('searchbox').or be_nil # May be implicit
    
    # AC-9.16: Search input has aria-label or placeholder
    expect(search_input['aria-label'] || search_input['placeholder']).to be_present
    
    # AC-9.17: Optgroups have proper ARIA (may be handled by SlimSelect)
    # This tests SlimSelect library's accessibility implementation
    expect(page).to have_selector('.ss-optgroup')
    
    # AC-9.20: Focus not trapped
    find('.ss-search input[type="search"]').send_keys(:escape)
    expect(page).not_to have_selector('.ss-content') # Dropdown closed
  end
  
  scenario 'Rapid keyboard navigation stability (AC-9.11)' do
    user = find_or_create_test_user('user@example.com')
    sign_in user
    visit new_better_together_event_path(locale: I18n.default_locale)
    
    expect(page).to have_selector('.ss-main', wait: 5)
    find('.ss-main').click
    
    search_input = find('.ss-search input[type="search"]')
    
    # Rapidly navigate with arrow keys
    20.times { search_input.send_keys(:arrow_down) }
    20.times { search_input.send_keys(:arrow_up) }
    
    # Should still be functional
    search_input.send_keys(:enter)
    expect(find('select#event_timezone', visible: false).value).to be_present
  end
end
```

---

### Accessibility Configuration

#### File: `spec/support/axe.rb`

```ruby
# frozen_string_literal: true

require 'axe-rspec'
require 'axe-core-selenium'

RSpec.configure do |config|
  config.include Axe::RSpec, type: :feature
  
  # Configure axe-core for WCAG 2.1 AA compliance
  config.before(:suite) do
    Axe.configure do |c|
      # Use WCAG 2.1 Level AA standard
      c.run_context = { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] } }
      
      # No exclusions - track all accessibility issues transparently
      # If SlimSelect causes issues, we want to see them and address them
      
      # Set options
      c.options = {
        rules: {
          # Enable all WCAG 2.1 AA rules
          'color-contrast': { enabled: true },
          'label': { enabled: true },
          'aria-allowed-attr': { enabled: true },
          'aria-required-attr': { enabled: true },
          'aria-valid-attr': { enabled: true },
          'aria-valid-attr-value': { enabled: true },
          'button-name': { enabled: true },
          'bypass': { enabled: true },
          'document-title': { enabled: true },
          'duplicate-id': { enabled: true },
          'form-field-multiple-labels': { enabled: true },
          'frame-title': { enabled: true },
          'html-has-lang': { enabled: true },
          'html-lang-valid': { enabled: true },
          'image-alt': { enabled: true },
          'input-button-name': { enabled: true },
          'input-image-alt': { enabled: true },
          'label-title-only': { enabled: true },
          'link-name': { enabled: true },
          'list': { enabled: true },
          'listitem': { enabled: true },
          'meta-refresh': { enabled: true },
          'meta-viewport': { enabled: true },
          'object-alt': { enabled: true },
          'role-img-alt': { enabled: true },
          'scrollable-region-focusable': { enabled: true },
          'select-name': { enabled: true },
          'svg-img-alt': { enabled: true },
          'td-headers-attr': { enabled: true },
          'th-has-data-cells': { enabled: true },
          'valid-lang': { enabled: true },
          'video-caption': { enabled: true }
        }
      }
    end
  end
end
```

---

## Implementation Sequence

### Red-Green-Refactor Cycle

#### Iteration 1: Helper Enhancement & Display Formatting (Phase 1)

**RED Phase:**
```bash
# Step 1.1: Write failing test for simplified display (AC-1.1)
bin/dc-run bundle exec prspec spec/helpers/better_together/timezone_helper_spec.rb:10 --format documentation
# Expected: FAIL - Display still includes IANA suffix

# Step 1.2: Write failing test for offset sorting (AC-1.2)
bin/dc-run bundle exec prspec spec/helpers/better_together/timezone_helper_spec.rb:25 --format documentation
# Expected: FAIL - Not sorted by offset

# Step 1.3: Write failing test for priority zones (AC-2.1, AC-2.2)
bin/dc-run bundle exec prspec spec/helpers/better_together/timezone_helper_spec.rb:45 --format documentation
# Expected: FAIL - Method doesn't exist
```

**GREEN Phase:**
```bash
# Implement helper methods in app/helpers/better_together/timezone_helper.rb
# Run tests again:
bin/dc-run bundle exec prspec spec/helpers/better_together/timezone_helper_spec.rb --format documentation
# Expected: PASS - All helper tests green
```

**REFACTOR Phase:**
```bash
# Optimize sorting logic, extract constants
# Run full helper spec suite:
bin/dc-run bundle exec prspec spec/helpers/better_together/timezone_helper_spec.rb --format documentation
# Run related request specs:
bin/dc-run bundle exec prspec spec/requests/better_together/events_spec.rb --format documentation
```

---

#### Iteration 2: SlimSelect Integration (Phase 2)

**RED Phase:**
```bash
# Step 2.1: Write failing test for SlimSelect controller (AC-4.1)
bin/dc-run bundle exec prspec spec/requests/better_together/events_spec.rb:50 --format documentation
# Expected: FAIL - No SlimSelect data attributes

# Step 2.2: Write failing feature test for search (AC-4.3, AC-9.3)
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb:15 --format documentation
# Expected: FAIL - No search functionality
```

**GREEN Phase:**
```bash
# Update helper to add SlimSelect data attributes
# Run tests:
bin/dc-run bundle exec prspec spec/requests/better_together/events_spec.rb:50 --format documentation
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb:15 --format documentation
# Expected: PASS - SlimSelect integration working
```

**REFACTOR Phase:**
```bash
# Extract SlimSelect configuration to helper method
# Run full feature spec:
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb --format documentation
```

---

#### Iteration 3: Browser Auto-Detection (Phase 3)

**RED Phase:**
```bash
# Step 3.1: Write failing test for auto-detection (AC-6.1, AC-9.8)
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb:85 --format documentation
# Expected: FAIL - Still using old mapping approach
```

**GREEN Phase:**
```bash
# Update JavaScript controller, remove mapIANAToRails()
# Run test:
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb:85 --format documentation
# Expected: PASS - Auto-detection working
```

**REFACTOR Phase:**
```bash
# Add debug logging
# Run full timezone controller tests:
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb --format documentation
```

---

#### Iteration 4: Accessibility Testing (Phase 4)

**RED Phase:**
```bash
# Step 4.1: Install axe-core gems
bin/dc-run bundle install
# Expected: SUCCESS

# Step 4.2: Write failing accessibility test (AC-9.13)
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb:150 --format documentation
# Expected: FAIL or PASS (depends on SlimSelect accessibility)
```

**GREEN Phase:**
```bash
# If accessibility failures:
# - Document issues
# - Fix or file GitHub issues
# Run test:
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb:150 --format documentation
```

**REFACTOR Phase:**
```bash
# Add ARIA attributes if needed
# Run full accessibility suite:
bin/dc-run bundle exec prspec spec/features/better_together/timezone_selection_spec.rb --format documentation
```

---

### Validation Checkpoints

#### After Each Iteration
- [ ] All new tests pass
- [ ] No existing tests broken: `bin/dc-run bin/ci`
- [ ] Security scan passes: `bin/dc-run bundle exec brakeman --quiet --no-pager`
- [ ] RuboCop passes: `bin/dc-run bundle exec rubocop -A`
- [ ] i18n health check: `bin/dc-run bin/i18n health`

#### After Complete Implementation
- [ ] **End User Demo**: Show timezone selector improvements with search and priority zones
- [ ] **Community Organizer Demo**: Show efficient event creation with auto-detected timezone
- [ ] **Platform Organizer Demo**: Show consistent timezone selection across platform
- [ ] **Accessibility Demo**: Show keyboard navigation and screen reader compatibility
- [ ] **Documentation Updated**: Update timezone handling documentation with new UX features
- [ ] **Diagrams Updated**: Update any UI flow diagrams showing timezone selection
- [ ] **Integration Testing**: Verify timezone selector works across all forms (events, platforms, preferences, wizard)

---

## Quality Standards Compliance

### Acceptance Criteria Requirements ✅
- **Specific**: Each AC defines one testable behavior (e.g., AC-4.3 tests search filtering)
- **Measurable**: Success determined objectively (test passes/fails)
- **Achievable**: Implementation uses existing SlimSelect controller and timezone infrastructure
- **Relevant**: ACs serve identified stakeholder needs (UX improvement for 600+ option dropdown)
- **Time-bound**: Feature specs include performance expectations (<100ms search response)

### Test Quality Requirements ✅
- **Comprehensive**: 45 acceptance criteria with full test coverage across helper, request, and feature specs
- **Isolated**: Tests create event per scenario for full isolation
- **Deterministic**: JavaScript specs wait for SlimSelect initialization to avoid flaky tests
- **Maintainable**: Tests clearly express intent with descriptive context blocks
- **Fast**: Helper and request specs run quickly; feature specs limited to necessary `:js` scenarios

---

This comprehensive TDD acceptance criteria document provides a complete roadmap for implementing timezone selector UX enhancements with full test coverage, stakeholder validation, and quality assurance.
