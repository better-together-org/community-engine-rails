# Student Developer Onboarding: Stakeholder Acceptance Criteria Implementation

**Purpose:** Structured onboarding for implementing v0.12.0 acceptance criteria specs.

**Time commitment:** 1-2 hours/day, 5 days/week, for 4-8 weeks depending on spec difficulty and existing Rails experience.

**End goal:** You can pick any pending spec from `spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb` and implement code to make it pass.

---

## Week 1: Context & Setup

### Day 1: Understanding the Big Picture (2 hours)

**Read (1 hour):**
- [ ] This file (you're reading it)
- [ ] PR description: `.pr_templates/STAKEHOLDER_AC_IMPLEMENTATION_PR.md`

**Install/Setup (30 min):**
- [ ] Run `bundle install` (installs gems)
- [ ] Run `rails db:setup` (sets up test database)
- [ ] Run `rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --dry-run` to verify specs load

**Verify Setup (30 min):**
- [ ] Can run `rspec` without errors
- [ ] Can open `spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb` in your editor
- [ ] Can see pending specs with `rspec ... --pending`

**Checklist:**
- [ ] Understand why this project exists (BTS values: Love, Inclusivity, Care, Resilience, Hope)
- [ ] Know what a "stakeholder" is (8 groups affected by this system)
- [ ] Know what "acceptance criterion" means (concrete requirement for a stakeholder)
- [ ] Understand spec structure: pending → implemented → passing → validated

### Day 2: Reading the Documents (2-3 hours)

**Read in this order:**

1. **Stakeholder Analysis** (1 hour)
   - Path: `docs/assessments/events_geography_stakeholder_analysis.md`
   - Read: Sections 1-2, then § Stakeholder 1: Community Members
   - [ ] Read sections 1-3
   - [ ] Understand who Community Members are
   - [ ] Know their 5 acceptance criteria (AC1-5)
   - **Stop here if time is short; this is the core context**

2. **Acceptance Criteria** (1 hour)
   - Path: `docs/assessments/events_geography_acceptance_criteria.md`
   - Read: § Stakeholder 1: Community Members (AC1 fully)
   - [ ] Understand AC1: "Event Discovery Works for Real Members"
   - [ ] Read the value received/contributed section
   - [ ] Know what "high-level acceptance criteria" means
   - [ ] Understand how progress is measured

3. **Implementation Guide** (30-45 min)
   - Path: `docs/implementation/STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md`
   - Read: "Quick Start," "Implementing a Pending Spec" (example), "Definition of Done"
   - [ ] Know the 5 commands to run specs
   - [ ] Understand the example: Space.near scope
   - [ ] Know what "done" means for a spec

**Checkpoint Questions (answer before moving on):**
- [ ] Why do we care about Community Members' acceptance criteria?
- [ ] What is AC1 trying to enable? (Proximity search for events)
- [ ] What are the 3 steps to go from pending spec → passing spec?

### Day 3-4: Reading Code Patterns (2 hours)

**Read existing specs (to learn the pattern):**

- [ ] `spec/models/better_together/address_spec.rb` — model testing pattern
- [ ] `spec/requests/better_together/events_controller_spec.rb` — request testing pattern
- [ ] `spec/features/events/location_selector_spec.rb` — feature testing pattern

**For each file, ask:**
- How does it use `create()` (factories)?
- How does it use `expect()`?
- What does `is_expected.to` mean?
- How is the test organized (describe, context, it blocks)?

**Checkpoint:**
- [ ] You can explain what a factory is (`create(:event)` creates test data)
- [ ] You can read a spec and understand what it's testing
- [ ] You can see the pattern: setup data → perform action → verify result

### Day 5: Pick Your First Spec (1 hour)

**Open the spec file:**
```bash
code spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb
```

**Find Stakeholder 1, AC1:**
- Search for: `describe 'AC1: Event Discovery Works for Real Members'`
- [ ] Found it

**Pick the first model-layer spec:**
- Look for the first `context 'Model:'` block under AC1
- Pick the first `pending` test
- [ ] Example: `pending 'Space has geometry column for PostGIS proximity queries'`
- [ ] Copy the spec code to a notes file for reference

**Checkpoint:**
- [ ] You've found a spec to implement
- [ ] You understand what it's testing (adding a geometry column to Space)
- [ ] You can explain in one sentence why this matters (enables proximity queries for event discovery)

---

## Week 2: First Implementation

### Day 1-2: Understand the Spec (2 hours)

**Read your spec carefully:**

```ruby
pending 'Space has geometry column for PostGIS proximity queries (currently has float only)' do
  space = create(:space, latitude: 48.9517, longitude: -57.9474)
  expect(space.columns.find { |c| c.name == 'geometry' }).to be_present
end
```

**Answer these questions:**
- [ ] What data is being created? (a Space record with lat/lng)
- [ ] What is being tested? (does Space have a geometry column?)
- [ ] What would make this pass? (add a geometry column to the spaces table)

**Look at the Space model:**
```bash
code app/models/better_together/geography/space.rb
```

- [ ] See existing columns (id, latitude, longitude, etc.)
- [ ] See that there's no geometry column yet
- [ ] Understand it's in the `geography` subdirectory

**Checkpoint:**
- [ ] You've read the spec 2-3 times
- [ ] You understand what needs to be added
- [ ] You've looked at the Space model and understand its structure

### Day 3: Create the Migration (1-2 hours)

**Generate a migration:**
```bash
rails generate migration AddGeometryToGeographySpaces
```

- [ ] A new file appears in `db/migrate/`
- [ ] Note the timestamp filename

**Edit the migration file:**
```bash
code db/migrate/[timestamp]_add_geometry_to_geography_spaces.rb
```

**Write the migration (follow the pattern):**

Look at existing migrations in `db/migrate/` for reference:
```bash
ls db/migrate/ | head -20
```

Find one that adds a column and copy the pattern.

**Your migration should:**
- [ ] Add a geometry column to `better_together_geography_spaces` table
- [ ] Specify `geographic: true` (PostGIS type)
- [ ] Add a GiST index for performance

**Reference code:**
```ruby
class AddGeometryToGeographySpaces < ActiveRecord::Migration[7.0]
  def change
    add_column :better_together_geography_spaces, :geometry, :geometry, geographic: true
    add_index :better_together_geography_spaces, :geometry, using: :gist
  end
end
```

**Checkpoint:**
- [ ] Migration file exists with correct syntax
- [ ] You understand what each line does
- [ ] You're ready to run it

### Day 4: Run Migration & Test (2 hours)

**Run the migration:**
```bash
rails db:migrate
```

- [ ] No errors
- [ ] Message shows "AddGeometryToGeographySpaces"

**Verify the column was added:**
```bash
rails console
> BetterTogether::Geography::Space.columns.map(&:name)
```

- [ ] You see "geometry" in the list

**Run your spec:**
```bash
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb -fd -t ac_members_1
```

- [ ] Spec that was pending is now... passing? Or failing?
- [ ] If passing: [ ] Great! Move to Day 5
- [ ] If failing: [ ] Debug (ask mentor, check error message)

**Checkpoint:**
- [ ] Migration ran successfully
- [ ] Geometry column exists on Space
- [ ] Spec is passing (or you understand why it's failing)

### Day 5: Commit & Create PR (2 hours)

**Review your changes:**
```bash
git status
git diff db/migrate/
```

- [ ] You see the migration file
- [ ] Changes look correct

**Stage the file:**
```bash
git add db/migrate/[timestamp]_add_geometry_to_geography_spaces.rb
```

- [ ] File shows as staged: `git status`

**Write a good commit message:**
```bash
git commit -m "add: geometry column to Space for PostGIS proximity (AC1)

- Adds PostGIS geometry column to Geography::Space
- Enables proximity queries via ST_DWithin
- Adds GiST index for performance
- Satisfies AC1 (Community Members: Event Discovery)
- Spec: spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb"
```

- [ ] Commit message explains what & why
- [ ] Commit message references the acceptance criterion

**Create a PR (draft):**
```bash
git push origin [your-branch-name]
gh pr create --draft --title "AC1: Add geometry column to Space for PostGIS" --body "See PR template for context"
```

- [ ] PR is created (link shown in terminal)
- [ ] It's marked as draft (so it's not auto-merged)

**Checkpoint:**
- [ ] Changes are committed
- [ ] PR is created (even if draft)
- [ ] You're ready for code review

---

## Week 3: Code Review & Learning

### Day 1-2: Get Feedback (Ongoing)

**Post your PR link in the team chat/review area.**

**Ask for review:**
> "I've implemented the geometry column for Space (AC1, spec 1). Ready for feedback. First implementation, so please point out any improvements."

**When you get feedback:**
- [ ] Read each comment carefully
- [ ] Ask clarifying questions if needed
- [ ] Make requested changes
- [ ] Re-run tests to verify still passing
- [ ] Push changes (they automatically update the PR)

**Checkpoint:**
- [ ] You've received at least one review comment
- [ ] You understand the feedback
- [ ] You know how to address it

### Day 3: Merge & Celebrate (1 hour)

**Merge the PR:**
```bash
gh pr merge [PR-NUMBER] --merge
```

- [ ] PR is merged to main
- [ ] CI/CD passes (if enabled)

**Celebrate!** 🎉

You've just:
- [ ] Read and understood an acceptance criterion
- [ ] Implemented code to satisfy it
- [ ] Got code review
- [ ] Merged to main

**Checkpoint:**
- [ ] Your first spec is passing on main
- [ ] AC1 (first criterion for Community Members) has 1/8 specs passing

### Day 4-5: Reflection & Preparation (1 hour)

**Reflect:**
- [ ] What was hardest? (migration? git? understanding the spec?)
- [ ] What was easiest? (running tests? writing code?)
- [ ] What would you do differently next time?

**Prepare for next spec:**
- [ ] Find the 2nd pending spec under AC1
- [ ] Read it (understand what it's testing)
- [ ] Note any unknowns ("I don't know how to test X")
- [ ] Ask questions before coding

**Checkpoint:**
- [ ] You have clarity on what went well
- [ ] You've identified what to improve
- [ ] You're ready for spec #2

---

## Weeks 4+: Sustainable Pace

### Rhythm
- **Monday-Thursday:** Implement 1 spec (4-5 hours of focused work)
- **Friday:** Code review, merge, reflect, plan next week
- **Target:** 1 spec per week = 4 specs/month

### Progression

**Week 4:** AC1, specs 2-3 (easier model-layer specs)
- [ ] `Space.within_radius()` scope
- [ ] `Space.near()` scope

**Week 5:** AC1, spec 4+ (service layer)
- [ ] `EventDiscoveryService.find_nearby()`
- [ ] Notification on location changes

**Week 6:** AC2 (Medium difficulty)
- [ ] Accuracy audits
- [ ] Location change notifications

**Week 7:** AC3 (Medium-High difficulty)
- [ ] Accessibility metadata
- [ ] Verification system

**Week 8:** AC4-5 or jump to different stakeholder group
- [ ] Timezone handling
- [ ] Privacy controls

### Metrics: Track Your Progress

At the end of each week, update this:

| Week | Specs Completed | Layer | Difficulty | Notes |
|------|---|---|---|---|
| 1 | Space geometry column | Model | Easy | First one! Learned git/rspec |
| 2 | Space.within_radius | Model | Easy | Felt more confident |
| 3 | EventDiscoveryService | Service | Medium | Took longer, good learning |
| ... | ... | ... | ... | ... |

**Running count:**
- Total implemented: [X]
- Passing: [X]
- In code review: [X]
- Next to start: [AC#, spec description]

---

## Survival Guide: When You Get Stuck

### "The spec won't pass"

**Checklist:**
1. [ ] Did you run `rails db:migrate` (if your change needs it)?
2. [ ] Did you run `bundle install` (if you added a gem)?
3. [ ] Does the test actually load? `rspec --dry-run`
4. [ ] What's the exact error message? Copy-paste it
5. [ ] Have you searched the error in the codebase? (`grep -r "error message"`)
6. [ ] Does an existing test show a similar pattern? (copy it)

**Still stuck?**
- Post error message + what you tried + your question
- Ask on team chat with the spec line number

### "I don't understand what the spec is asking"

**Checklist:**
1. [ ] Read the spec code 3+ times
2. [ ] Break it down: setup (`create`) → action → expectation (`expect`)
3. [ ] Read the acceptance criterion document for this AC#
4. [ ] Read the stakeholder needs section (why does this matter?)
5. [ ] Ask: "If this feature existed, what would the user do?"

**Still unclear?**
- Ask: "Can you explain AC1 in one sentence?" (sometimes it's the doc, not you)

### "This seems too hard"

**Your options:**
1. [ ] Pick an easier spec (more model-layer, fewer associations)
2. [ ] Ask for help *before* you start ("I'm stuck, walk me through this?")
3. [ ] Pair program with another developer (watch them do one, then try)
4. [ ] Break it down further (ask what the smallest step is)

**Example:** If a service spec seems complex, do the model spec first (it's simpler).

### "I'm stuck for 30+ minutes"

**Do this:**
1. [ ] Take a 10-minute break (walk, water, stretch)
2. [ ] Re-read the spec like it's the first time
3. [ ] Write down what you're stuck on (be specific)
4. [ ] Ask for help with that specific thing (not "I don't get it")

**Don't do this:**
- Hack around the problem (leads to bad code)
- Guess at migrations (bad database state)
- Skip the spec and move on (you'll be stuck on the next one too)

---

## Resources

### Reading
- [Assessment Report](../docs/assessments/geography_location_system_assessment.md) — baseline gaps
- [Stakeholder Analysis](../docs/assessments/events_geography_stakeholder_analysis.md) — who we're serving
- [Acceptance Criteria](../docs/assessments/events_geography_acceptance_criteria.md) — what success looks like
- [Implementation Guide](./STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md) — detailed how-to

### Code Examples
- `spec/models/better_together/` — model specs
- `spec/requests/better_together/` — request specs
- `spec/features/events/` — feature specs
- `spec/factories/better_together/` — factories (test data)

### Commands Cheat Sheet
```bash
# Run specs
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb -t ac_members_1
rspec spec/acceptance_criteria/stakeholder_acceptance_criteria_spec.rb --pending

# See your changes
git status
git diff

# Create migration
rails generate migration AddXToY

# Run migrations
rails db:migrate

# Git workflow
git add .
git commit -m "message"
git push origin branch-name
gh pr create

# Rails console (debug)
rails console
> Model.all
```

### Getting Help
1. **Code review:** Push a PR (even draft) and ask
2. **Design question:** Ask before implementing (saves time)
3. **Stuck on error:** Post the error message (not a screenshot)
4. **Feedback:** Always welcomed (be specific)

---

## Success Checklist: By End of Week 1

- [ ] I understand what a stakeholder is (8 groups)
- [ ] I understand what an acceptance criterion is (concrete success metric)
- [ ] I've read AC1 (Community Members: Proximity Search)
- [ ] I can explain AC1 in my own words
- [ ] I've found my first spec to implement
- [ ] I can run `rspec` without errors
- [ ] I've read at least one existing model spec
- [ ] I know what a factory is (`create(:event)`)
- [ ] I feel ready (or know what questions to ask)

---

## Success Checklist: By End of Month 1

- [ ] I've implemented 4+ specs
- [ ] 3+ specs are merged to main
- [ ] I can write a spec-focused commit message
- [ ] I've had code reviewed (and addressed feedback)
- [ ] I understand the pattern: pending → code → test passes → review → merged
- [ ] I can pick a spec and estimate implementation time
- [ ] I've asked for help at least once (and that was OK)
- [ ] I feel more confident than I did on Day 1

---

## One Last Thing

**This is about building something that matters.**

The specs you implement aren't abstract exercises. They're requirements from real people:
- Members who want to find events near them
- Organizers who want to manage their spaces
- People with disabilities who need accessibility info
- Historians who want to record their community's story
- Developers who need clear contracts
- Governance stewards who need transparent decision logs
- Newcomers who need to feel welcomed
- Movement partners who need to coordinate

**Every spec you implement serves one of these groups.**

When you're stuck or tired, remember: you're not just writing code. You're building infrastructure for people to organize their communities.

**That's why this matters. You've got this.** 💪

---

**Started:** [Date]  
**Week 1 Complete:** [Date]  
**Month 1 Complete:** [Date]  
**Total Specs Implemented:** [X]
