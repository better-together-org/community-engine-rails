# Stakeholder Acceptance Criteria Implementation Guide

**File:** `spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb`

**Purpose:** Comprehensive RSpec test plan for v0.12.0 "balanced spacetime foundation" that maps all 32 stakeholder acceptance criteria into executable test suites across model, service, and request layers.

---

## Quick Start

### Running All Specs (Pending)
```bash
# Show all pending specs (unimplemented acceptance criteria)
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag acceptance_criteria --pending

# Show detailed summary
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag acceptance_criteria -fd

# Count pending specs
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag acceptance_criteria --dry-run | grep "example" | tail -1
```

### Running Specs by Stakeholder
```bash
# Community Members only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag stakeholder_members

# Community Organizers only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag stakeholder_organizers

# Accessibility advocates only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag stakeholder_accessibility

# All by tag: :stakeholder_historians, :stakeholder_developers, :stakeholder_governance, :stakeholder_newcomers, :stakeholder_movement
```

### Running Specs by Acceptance Criterion
```bash
# AC1: Event Discovery Works for Real Members (all implementations)
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag ac_members_1

# AC1 for Community Organizers
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag ac_organizers_1

# All AC3 criteria
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag ac_3
```

### Running Specific Test Layers
```bash
# Model layer specs only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag model

# Service layer specs only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag service

# Request/Controller layer specs only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag request

# Feature specs only
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag feature
```

---

## Spec Structure Overview

Each acceptance criterion is organized as:

```
Stakeholder: [Group Name]
  AC[N]: [Criterion Title]
    [Layer Type]: [Specific Component]
      context/describe: [Specific Behavior]
        pending 'Behavior description' do
          skip 'Implementation details'
        end
```

### Layers

1. **Model Layer** — ActiveRecord models, validations, associations, scopes
   - Location: `spec/models/` (or within acceptance_criteria file)
   - Examples: `Event#location_changed?`, `Space.within_radius`, `AccessibilityMetadata`

2. **Service Layer** — Business logic, calculations, transformations
   - Location: `spec/services/` (or within acceptance_criteria file)
   - Examples: `EventDiscoveryService`, `LocationChangeNotificationService`, `TimezoneService`

3. **Request/Controller Layer** — API endpoints, form handling, authorization
   - Location: `spec/requests/` (or within acceptance_criteria file)
   - Examples: `POST /buildings`, `GET /api/v1/events?filter[latitude]=...`, permission checks

4. **Feature Layer** — End-to-end user flows, browser automation
   - Location: `spec/features/` (or within acceptance_criteria file)
   - Examples: "Organizer creates building", "Member discovers event via proximity"

---

## Implementing a Pending Spec

### Example: AC1 (Members) - Proximity Search

**Current State:**
```ruby
pending 'Space.near(lat, lng) returns closest spaces first (ordered by distance)' do
  cornbrook = create(:space, latitude: 48.9517, longitude: -57.9474, identifier: 'cornbrook')
  foleys = create(:space, latitude: 48.6667, longitude: -57.5, identifier: 'foleys')
  gander = create(:space, latitude: 48.9539, longitude: -54.5839, identifier: 'gander')

  near_cornbrook = BetterTogether::Geography::Space.near(48.9517, -57.9474).limit(3)
  expect(near_cornbrook.first.identifier).to eq('cornbrook')
  expect(near_cornbrook.second.identifier).to eq('foleys')
end
```

**To implement:**

1. **Decide if skip or remove pending:**
   - If feature is required for v0.12.0: remove `pending`, keep test
   - If feature is deferred: keep `pending`, change message to link to issue
   ```ruby
   pending 'Space.near(lat, lng) returns closest spaces first - deferred to v0.12.1 (issue #1234)' do
   ```

2. **Implement the model method:**
   ```ruby
   # app/models/better_together/geography/space.rb
   scope :near, ->(lat, lng) do
     where(
       'ST_DWithin(location, ST_Point(?, ?), ?) = true',
       lng, lat, 100000  # 100km radius
     ).order('ST_Distance(location, ST_Point(?, ?)) ASC', lng, lat)
   end
   ```

3. **Run the test:**
   ```bash
   rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb:200
   ```

4. **Verify it passes:**
   - Test should now pass (move from pending to passing)
   - Remove `pending` block wrapper
   - Commit with message: "test: implement Space.near scope for proximity search (AC1)"

### Tips for Implementation

- **Start with model specs** — they're simplest and require least infrastructure
- **Move to service specs** — add business logic and calculations
- **Add request specs** — verify API contracts
- **Save feature specs for last** — they're slowest; add only critical user flows

- **Use factories extensively** — see `spec/factories/better_together/` for examples
  ```ruby
  create(:event)
  create(:space, latitude: 48.9517, longitude: -57.9474)
  create(:address, line1: '123 St', city_name: 'St. John\'s')
  ```

- **Use traits for variations** — e.g., `create(:event, :with_location, :accessible)`
  ```ruby
  # In factory:
  trait :accessible do
    after(:create) { |event| event.update!(accessibility_metadata: { wheelchair_accessible: true }) }
  end
  ```

- **Test error cases too** — don't just test the happy path
  ```ruby
  it 'raises error if location not found' do
    expect {
      SomeService.change_location(event, invalid_id)
    }.to raise_error(ActiveRecord::RecordNotFound)
  end
  ```

---

## Spec Count & Coverage

### Total Pending Specs
- **Stakeholder 1 (Members):** ~40 specs (AC1-5, ~8 per AC)
- **Stakeholder 2 (Organizers):** ~40 specs (AC1-5, ~8 per AC, abbreviated after AC2 in current file)
- **Stakeholder 3 (Accessibility):** ~35 specs (4 AC, ~8-9 per AC)
- **Stakeholder 4 (Historians):** ~30 specs (4 AC, ~7-8 per AC)
- **Stakeholder 5 (Developers):** ~40 specs (4 AC, focused on contracts & testing)
- **Stakeholder 6 (Governance):** ~35 specs (4 AC, focused on audit trails & decision logging)
- **Stakeholder 7 (Newcomers):** ~35 specs (4 AC, focused on i18n & cultural accessibility)
- **Stakeholder 8 (Movement):** ~30 specs (4 AC, federation & resource sharing)

**Total: ~250+ pending specs covering v0.12.0 acceptance criteria**

---

## Acceptance Criteria Mapping

### Stakeholder 1: Community Members (End Users)

| AC# | Title | Specs | Layer Focus |
|-----|-------|-------|-------------|
| 1 | Event Discovery Works for Real Members | 8 | Model, Service, Request, Feature |
| 2 | Event Information Is Accurate & Trustworthy | 7 | Model, Service, Audit |
| 3 | Accessibility Info Prevents Disappointment | 8 | Model, Service, Request |
| 4 | Time Zone Clarity Prevents Confusion | 6 | Model, Service, Request, ICS |
| 5 | Private Attendance Doesn't Feel Surveilled | 6 | Model, Service, Request, Privacy |

### Stakeholder 2: Community Organizers

| AC# | Title | Specs | Layer Focus |
|-----|-------|-------|-------------|
| 1 | Building/Room Management Is Self-Service | 8 | Model, Service, Form, Feature |
| 2 | Location Changes Notify & Are Transparent | 7 | Model, Service, History |
| 3 | Capacity Planning & Co-Organizer | 6 | Model, Service (omitted in current file) |
| 4 | Place Inventory & Resource Understanding | 6 | Model, Service, Report |
| 5 | Cross-Community Coordination | 5 | Model, Service, Federation |

### Stakeholders 3-8

All follow similar structure with 4-5 AC# each, ~30-40 specs total per group.

---

## Integration with CI/CD

### Pre-commit Hook
```bash
# .git/hooks/pre-commit
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag acceptance_criteria --dry-run
# This just validates the spec file syntax without running anything
```

### CI Pipeline
```yaml
# .github/workflows/ci.yml (example)
- name: Run Stakeholder Acceptance Criteria Specs
  run: rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag acceptance_criteria --format json --output coverage/ac_spec_report.json
```

### Dashboard (Optional)
Create a dashboard showing:
- Total pending specs: [X]
- Implemented specs: [Y]
- Implementation progress: [Y/X]%
- By stakeholder group (pie chart)
- By layer type (bar chart)

---

## Progress Tracking

### Monthly Implementation Goals

**Example v0.12.0 Sprint:**

| Month | Sprint | Target | Focus | Stakeholders |
|-------|--------|--------|-------|--------------|
| Jun | 1 | 20 specs | Proximity search, event accuracy | Members |
| Jun | 2 | 20 specs | Organizer self-service (buildings/rooms) | Organizers |
| Jul | 1 | 20 specs | Accessibility metadata & verification | Accessibility |
| Jul | 2 | 20 specs | Historians support & place history | Historians |
| Aug | 1 | 20 specs | Developer contracts & spatial queries | Developers |
| Aug | 2 | 20 specs | Governance audit trails & reporting | Governance |
| Sep | 1 | 20 specs | Newcomer i18n & cultural accessibility | Newcomers |
| Sep | 2 | 20 specs | Movement federation & resource sharing | Movement |
| Oct | 1-2 | Remaining | Cross-stakeholder metrics, integration tests, e2e |

**Track progress:**
```bash
# Weekly check
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag acceptance_criteria --dry-run | grep "250 examples"

# Mark specs as "in progress" by changing pending to xit (skip)
# Mark specs as "done" by removing pending/xit and keeping test active
```

---

## Definition of Done for Each Spec

A spec is **DONE** when:

1. ✅ `pending` block is removed (or changed to `xit` if deferred)
2. ✅ Test implementation is complete (no `skip` or `pending` in test body)
3. ✅ Test passes locally: `rspec spec/...` shows green
4. ✅ Corresponding feature/model code is merged to main
5. ✅ Code review approved by another developer
6. ✅ PR is linked in the spec file or commit message
7. ✅ Acceptance criterion is validated with actual stakeholder(s) if possible

---

## Extending the Specs

### Adding New Stakeholders
If a new stakeholder emerges:
1. Copy the structure of an existing stakeholder describe block
2. Define their acceptance criteria
3. Create specs following the same pattern
4. Use `pending` for all; implement incrementally

### Adding New Acceptance Criteria
If requirements change mid-sprint:
1. Add new `describe` block with new AC#
2. Fill in specs
3. Update the Acceptance Criteria document
4. Re-prioritize sprint if necessary

### Removing/Consolidating Criteria
If criteria become obsolete:
1. Move pending specs to commented block at bottom of file
2. Document why removed
3. Update stakeholder docs
4. Announce change to relevant stakeholders

---

## Quality Gates

### Before Releasing v0.12.0

**All acceptance criteria specs should be:**
- ✅ Implemented (no pending blocks, no skip)
- ✅ Passing (green across all 8 stakeholder groups)
- ✅ Validated with stakeholders (at least one representative from each group has verified it works)
- ✅ Documented (tests reference acceptance criteria doc; readable by non-engineers)

**Exceptions:**
- Specs may remain `xit` (explicitly skipped) if criterion is deferred to v0.12.1+
- Deferred criterion must have a GitHub issue number and rationale documented in test

---

## Stakeholder Validation Process

After all specs for a criterion pass:

```
Develop → Test passes locally → PR review → Merged to main → Manual validation with stakeholder
```

**Manual validation checklist for each AC#:**
- [ ] Recruit 1–2 representatives from stakeholder group
- [ ] They test the feature as described in criterion
- [ ] Collect feedback: "Did this work as promised?"
- [ ] Document results (quote from stakeholder if possible)
- [ ] If feedback = "no", file a bug and loop back to development
- [ ] If feedback = "yes", sign off on AC# as complete
- [ ] Update acceptance criteria doc with date/stakeholder sign-off

---

## Example: Full Spec Lifecycle

### 1. Spec Initially Pending (Sprint Start)
```ruby
describe 'AC1: Event Discovery Works for Real Members' do
  pending 'Space.within_radius(lat, lng, km) returns events within distance' do
    cornbrook = create(:space, latitude: 48.9517, longitude: -57.9474)
    nearby = BetterTogether::Geography::Space.within_radius(48.9517, -57.9474, 50)
    expect(nearby).to include(cornbrook)
  end
end
```

**Status:** Red (pending, not run)

### 2. Spec Being Implemented (Development)
```ruby
it 'Space.within_radius(lat, lng, km) returns events within distance' do
  cornbrook = create(:space, latitude: 48.9517, longitude: -57.9474)
  nearby = BetterTogether::Geography::Space.within_radius(48.9517, -57.9474, 50)
  expect(nearby).to include(cornbrook)
end

# In app/models/better_together/geography/space.rb:
scope :within_radius, ->(lat, lng, km) do
  where('ST_DWithin(location::geography, ST_Point(?, ?)::geography, ?) = true', lng, lat, km * 1000)
end
```

**Status:** Green (passes locally)

### 3. Spec Merged to Main (PR #1234)
Test is now part of CI/CD pipeline.

**Status:** Green in CI; documented in PR

### 4. Spec Validated with Stakeholder
Member tests proximity search, confirms "It works as expected."

**Status:** Sign-off complete; AC1 partially satisfied

### 5. All AC1 Specs Pass & Validated
All 8 AC1 specs for Members group pass locally, in CI, and with stakeholder feedback.

**Status:** AC1 Complete; move to AC2

---

## References

- **Acceptance Criteria Doc:** `docs/assessments/events_geography_acceptance_criteria.md`
- **Current Implementation Status:** `docs/assessments/geography_location_system_assessment.md` (baseline gaps)
- **Stakeholder Analysis:** `docs/assessments/events_geography_stakeholder_analysis.md`
- **CE Testing Standards:** `docs/development/testing_standards.md`
- **Spec Factories:** `spec/factories/better_together/`

---

## Support & Questions

- **"How do I implement a pending spec?"** → See "Implementing a Pending Spec" section above
- **"What if a spec is too complex to implement?"** → Break it into smaller sub-specs; add a comment linking to the issue
- **"Can I defer a spec?"** → Yes; use `xit` (not `pending`); document why and link to issue
- **"How do I know if a spec is actually testing what matters?"** → Reference the acceptance criteria doc; have a stakeholder review the spec

---

## Success Metrics

**By end of v0.12.0:**
- [ ] 250+ specs implemented (0 pending, 0 xit)
- [ ] All specs passing locally and in CI
- [ ] All specs validated with at least one stakeholder representative
- [ ] All 8 stakeholder groups sign off: "This system serves our needs"
- [ ] Zero "implementation mismatch" bugs reported post-launch
