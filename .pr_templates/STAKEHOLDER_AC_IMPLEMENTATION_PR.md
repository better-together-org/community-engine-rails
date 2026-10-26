# [DRAFT] v0.12.0: Stakeholder Acceptance Criteria & TDD Implementation Plan

## Summary

This PR introduces a **values-grounded, stakeholder-centered testing framework** for v0.12.0 "balanced spacetime foundation" — the Community Engine release that will bring geography, events, and location features into alignment with Better Together's cooperative mission.

Instead of building features and hoping they serve people, we're doing this backwards: we're writing tests that express what 8 different stakeholder groups need, then implementing code to pass those tests.

**You're being asked to help implement these tests.**

---

## What's Included in This PR

This PR adds **three new documentation/spec files**:

### 1. **Assessment Report** (`docs/assessments/geography_location_system_assessment.md`)
**What it is:** An honest audit of the current events/geography system: what works, what's missing, what's broken.

**Why you need to read it:** It shows you the baseline — the gaps we're trying to fill. Understanding what's currently wrong helps you understand why the new tests matter.

**How long to read:** 30 minutes. Skim the Executive Summary and Gap Analysis table; you don't need to memorize every detail.

**Key takeaway:** Current system has critical gaps (PostGIS geometry not used, Event location API missing, no proximity search, etc.). v0.12.0 fixes these.

### 2. **Stakeholder Analysis** (`docs/assessments/events_geography_stakeholder_analysis.md`)
**What it is:** Who uses this system and what do they actually need? Not from a feature perspective, but from a human values perspective.

**Why you need to read it:** The tests we write aren't abstract. They come from real people's needs: members with disabilities, newcomers, organizers, historians. Understanding *why* we're building this makes the implementation meaningful.

**How long to read:** 45 minutes. Read Sections 1-2 (Foundation & Stakeholder Map). Then pick one stakeholder group that interests you (e.g., Community Members, Organizers, Accessibility Advocates) and read their section fully.

**Key takeaway:** Each stakeholder group has complementary, non-competing needs grounded in BTS values.

### 3. **Acceptance Criteria** (`docs/assessments/events_geography_acceptance_criteria.md`)
**What it is:** For each stakeholder, what counts as success? High-level criteria that answer: "How do we know this feature actually serves people?"

**Why you need to read it:** This is what the tests are measuring. Each test validates one piece of an acceptance criterion.

**How long to read:** 1 hour. Read the foundation section, then read acceptance criteria for the stakeholder group you're implementing for.

**Key takeaway:** Success isn't "feature shipped." Success is "stakeholders say it works as promised."

### 4. **RSpec Spec Plan** (`spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb`)
**What it is:** 250+ pending RSpec specs that map each acceptance criterion to concrete test cases.

**Why you need to read it:** This is your implementation roadmap. Each `pending` spec is a task.

**How long to read:** Pick one stakeholder + one criterion. Read those specs. Don't try to read all 250 at once.

**Key takeaway:** Specs are written. Not implemented yet. Your job is to implement code to make them pass.

### 5. **Implementation Guide** (`docs/implementation/STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md`)
**What it is:** Step-by-step instructions for how to go from a pending spec to a passing spec.

**Why you need to read it:** This is your playbook. It shows you exactly what to do.

**How long to read:** 30 minutes. Read "Quick Start," "Implementing a Pending Spec" (the example), and "Definition of Done."

**Key takeaway:** Spec → Implement feature → Test passes → Validate with stakeholder → Done.

---

## For You: A Student Learning Implementation

I know that's a lot of documents. Here's a **much shorter reading list** to get started:

### Day 1: Understand the Context (2 hours)
1. **Read this PR description** (you're reading it now) ✓
2. **Read Stakeholder Analysis § Stakeholder 1: Community Members** (30 min)
   - Path: `docs/assessments/events_geography_stakeholder_analysis.md` → § Community Members
   - Why: Get a sense of real user needs
3. **Read Acceptance Criteria § Stakeholder 1: AC1** (30 min)
   - Path: `docs/assessments/events_geography_acceptance_criteria.md` → § Stakeholder 1, AC1
   - Why: Understand what success looks like
4. **Read Implementation Guide § Quick Start + Example** (30 min)
   - Path: `docs/implementation/STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md`
   - Why: See the workflow you'll follow

**After Day 1, you should be able to answer:**
- "What is a stakeholder acceptance criterion?"
- "Why is Community Member Alice's concern about accessibility important?"
- "How do I go from a pending spec to a passing spec?"

### Day 2: Pick Your First Spec (3 hours)
1. **Pick an AC1 spec to implement** (30 min)
   - Open: `spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb`
   - Find: Stakeholder 1, AC1
   - Pick: The simplest pending spec (usually the first model-layer one)
   - Example: `pending 'Space has geometry column for PostGIS proximity queries'`

2. **Read the spec code** (30 min)
   - What data is it creating?
   - What is it expecting?
   - What would make it pass?

3. **Implement the feature** (Varies — could be 30 min to 2 hours)
   - Use the pattern from "Implementing a Pending Spec" guide
   - Follow existing CE code patterns (read similar models/services)
   - Run the spec: `rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb:LINE_NUMBER`

4. **Get feedback** (Ongoing)
   - Push a draft PR
   - Ask questions (see "Questions to Ask" section below)

---

## How to Start: Step-by-Step

### Phase 1: Read & Understand (Days 1-2)
- [ ] Read this PR description
- [ ] Read Stakeholder Analysis § Community Members
- [ ] Read Acceptance Criteria § AC1
- [ ] Read Implementation Guide § Quick Start & Example
- [ ] **Checkpoint:** You understand what a pending spec is and why it matters

### Phase 2: Pick Your First Spec (Day 3)
- [ ] Open `spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb`
- [ ] Find Stakeholder 1, AC1
- [ ] Pick the simplest spec (usually model-layer)
- [ ] Read the spec code — understand what it's testing
- [ ] **Checkpoint:** You've chosen your first spec to implement

### Phase 3: Implement (Days 4-7, depending on spec)
- [ ] Read similar existing models/services in CE (for patterns)
- [ ] Implement the feature in the app
- [ ] Run the spec: `rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --tag SPEC_TAG`
- [ ] Verify it passes
- [ ] **Checkpoint:** Your spec is green

### Phase 4: Code Review & Stakeholder Validation (Days 8-10)
- [ ] Push a PR
- [ ] Get code review from another developer
- [ ] (Optional) Have a community member test the feature
- [ ] **Checkpoint:** Code is merged; acceptance criterion is validated

### Phase 5: Move to Next Spec (Repeat)
- [ ] Pick next spec
- [ ] Go back to Phase 3

---

## Example: Implementing AC1, Spec 1 (Community Members — Proximity Search)

### The Spec (as written in the pending spec file)

```ruby
pending 'Space has geometry column for PostGIS proximity queries (currently has float only)' do
  space = create(:space, latitude: 48.9517, longitude: -57.9474)
  expect(space.columns.find { |c| c.name == 'geometry' }).to be_present
end
```

### What the Spec is Asking
"The Space model should have a PostGIS geometry column so we can do proximity searches. Right now it only has float columns."

### How to Implement (Detailed Steps)

**Step 1: Create a migration**
```bash
rails generate migration AddGeometryToGeographySpaces
```

**Step 2: Write the migration**
```ruby
# db/migrate/[timestamp]_add_geometry_to_geography_spaces.rb
class AddGeometryToGeographySpaces < ActiveRecord::Migration[7.0]
  def change
    add_column :better_together_geography_spaces, :geometry, :geometry, geographic: true
    add_index :better_together_geography_spaces, :geometry, using: :gist
  end
end
```

**Step 3: Run the migration**
```bash
rails db:migrate
```

**Step 4: Run the spec**
```bash
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb:LINE_NUMBER -fd
```

**Step 5: Verify it passes**
```
1 example, 0 failures  ✓
```

**Step 6: Commit**
```bash
git add db/migrate/[timestamp]_add_geometry_to_geography_spaces.rb
git commit -m "add: geometry column to Space for PostGIS proximity (AC1)

- Adds PostGIS geometry column to Geography::Space
- Enables proximity queries via ST_DWithin
- Adds GiST index for performance
- Satisfies AC1 (Community Members: Event Discovery)
- Spec: spec/acceptance_criteria/.../ac_members_1"
```

---

## Common Questions & Answers

### Q: "Do I have to implement all 250 specs?"
**A:** No! This PR is the *plan* for v0.12.0. We'll assign you a specific subset. You might implement 5-10 specs over a month, not all 250.

### Q: "Which spec should I start with?"
**A:** Start with Stakeholder 1 (Community Members), AC1 (Proximity Search), first spec (usually model-layer). It's the simplest and will teach you the pattern.

### Q: "What if the spec seems too big or unclear?"
**A:** Good instinct. Break it down:
- Read the test code
- Ask: "What data am I creating?" (the `create` calls)
- Ask: "What am I testing?" (the `expect` line)
- Ask: "What would make this pass?" (implement the simplest thing)
- If still stuck, ask a mentor/code reviewer

### Q: "What if I don't understand the acceptance criterion?"
**A:** Read the acceptance criterion document for that criterion. If still unclear:
1. Read the stakeholder group's section (e.g., "Community Members")
2. Find the AC# (e.g., "AC1: Event Discovery Works for Real Members")
3. Look for "User Stories & Needs" — this explains *why* the criterion exists
4. Still confused? Ask a mentor. This is context you should understand before coding.

### Q: "How do I know if my implementation is correct?"
**A:** 
1. **Test passes** — `rspec` shows green ✓
2. **Code review approved** — another dev reviews your code
3. **Spec matches criterion** — read your spec, then read the criterion; do they align?

### Q: "What if my code passes the spec but feels wrong?"
**A:** This is important feedback. Talk to a mentor. The spec might be incomplete, or you might have found a better way. Either way, it's a learning moment.

### Q: "How long does each spec take to implement?"
**A:** Varies wildly:
- **Model-layer specs:** 15-30 min (add a column, validation, scope)
- **Service-layer specs:** 30-90 min (business logic, calculations)
- **Request/API specs:** 60-120 min (controller, serialization, authorization)
- **Feature specs:** 2-4 hours (end-to-end user flow)

Start with model-layer specs to build confidence.

---

## Asking Good Questions

You'll get stuck. That's expected. Here's how to ask for help:

### Template: "I'm stuck on a spec"

```
Spec: [quote the spec]
What I understand: [what the test is trying to do]
Where I'm stuck: [specifically, what's unclear]
What I've tried: [what you already attempted]
My question: [what do you need from me?]
```

### Example
```
Spec: pending 'Space.near(lat, lng) returns closest spaces first'

What I understand: The test creates 3 spaces at different coordinates and 
expects Space.near() to return them in distance order.

Where I'm stuck: How do I calculate distance between two lat/lng points 
in PostGIS?

What I've tried: Looked at Space model; didn't see an existing scope.

My question: Is there an existing scope I should extend, or should I create 
a new one? Do you have a PostGIS distance example I can follow?
```

This helps your reviewer give you targeted help, not re-explain everything.

---

## Red Flags: When to Escalate

**Ask a mentor immediately if:**

1. **The spec is confusing** — "I read the spec code 3 times and still don't understand what it's asking"
2. **The feature seems impossible** — "This requires changing 5 models and I'm not sure where to start"
3. **The acceptance criterion conflicts with code** — "The spec says X but the model already does the opposite"
4. **You're stuck for > 1 hour** — "I've tried A, B, and C; they all failed; I'm out of ideas"
5. **You have a better idea** — "The spec asks for X but Y would be simpler and work better"

None of these are failures. They're learning opportunities.

---

## How Code Review Works

When you submit a PR:

1. **Review checklist** (automated):
   - Tests pass locally? `rspec spec/...` green?
   - Code is readable? Follows CE conventions?
   - PR title/description clear? Links to spec?

2. **Reviewer feedback** (human):
   - "Nice work" or "consider this approach instead"
   - Request changes if needed
   - Approve when ready

3. **Merge**:
   - Your code goes to main
   - CI/CD runs full test suite
   - Your spec is now part of the baseline

4. **Stakeholder validation** (optional):
   - If applicable, have a community member test it
   - Document their feedback
   - Mark acceptance criterion as complete

---

## Progression: Easy → Medium → Hard

Start here:

### Easy (Days 1-2)
- Model specs: add column, validation, basic scope
- Examples: `Space has geometry column`, `Event#location_changed?`
- Time: 15-30 min each
- Teaches: Rails migration, model specs, factory usage

### Medium (Days 3-7)
- Service specs: business logic, notifications, calculations
- Examples: `EventDiscoveryService.find_nearby`, `LocationChangeNotificationService.notify`
- Time: 30-90 min each
- Teaches: Service objects, dependency injection, testing logic

### Hard (Days 8+)
- Request/API specs: endpoints, authorization, complex flows
- Examples: `POST /buildings`, `GET /api/v1/events?filter[latitude]...`
- Time: 1-2 hours each
- Teaches: Controllers, JSONAPI, authorization, integration

### Very Hard (Days 15+)
- Feature specs: end-to-end user flows with browser automation
- Examples: "Organizer creates building; member finds it via proximity search"
- Time: 2-4 hours each
- Teaches: Capybara, JavaScript Stimulus, full-stack testing

**Recommendation:** Do 2-3 Easy specs, then 2-3 Medium, before attempting Hard.

---

## Files to Read for Context

Before you start coding, look at existing patterns:

**For model specs:**
- `spec/models/better_together/address_spec.rb` — shows model testing patterns
- `spec/models/better_together/event_spec.rb` — shows associations, validations

**For service specs:**
- Look for any `spec/services/better_together/` files
- If none exist, ask for an example pattern

**For request specs:**
- `spec/requests/better_together/events_controller_spec.rb` — shows API testing
- `spec/requests/better_together/events_datetime_partial_spec.rb` — shows form testing

**For feature specs:**
- `spec/features/events/location_selector_spec.rb` — shows browser automation

---

## Success Looks Like

After 2 weeks:
- [ ] You've implemented 3-5 specs
- [ ] Your code has been reviewed
- [ ] You can explain why each spec matters (the stakeholder perspective)
- [ ] You've asked for help when stuck (and that was OK)
- [ ] You can look at a pending spec and estimate how long it'll take

After 1 month:
- [ ] You've implemented 10-15 specs
- [ ] You're comfortable with model, service, and request layer tests
- [ ] You're starting to see the pattern: spec → feature → pass → validate
- [ ] You can pick any pending spec and implement it with minimal help

After 3 months:
- [ ] You've implemented 30-40 specs across multiple stakeholder groups
- [ ] You've had a community member validate your work
- [ ] You understand how acceptance criteria connect to real people's needs
- [ ] You're mentoring others on this pattern

---

## TL;DR — Start Here

1. **Today:** Read Stakeholder Analysis § Community Members (30 min)
2. **Today:** Read Acceptance Criteria § AC1 (30 min)
3. **Today:** Read Implementation Guide § Example (30 min)
4. **Tomorrow:** Pick your first spec (AC1, first model-layer one)
5. **Tomorrow-Friday:** Implement it using the step-by-step example above
6. **Friday:** Submit a PR; ask for feedback
7. **Next week:** Repeat with the next spec

**One spec at a time. One step at a time. You've got this.**

---

## Questions?

Before you ask, check:
1. **Is my question answered in one of the docs above?** (search the word)
2. **Is there an existing code example I can follow?** (ask "where do you see this pattern?")
3. **Do I need to understand something else first?** (OK to say "I'm not ready yet")

Then ask! Asking good questions is a skill. We value curiosity.

---

## Links in This PR

- [Assessment Report](../docs/assessments/geography_location_system_assessment.md)
- [Stakeholder Analysis](../docs/assessments/events_geography_stakeholder_analysis.md)
- [Acceptance Criteria](../docs/assessments/events_geography_acceptance_criteria.md)
- [RSpec Specs](../spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb)
- [Implementation Guide](../docs/implementation/STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md)

---

**This PR is an invitation to help build a system that actually serves people, not just ships features. We're excited to have you.**

**Let's build something that matters.**
