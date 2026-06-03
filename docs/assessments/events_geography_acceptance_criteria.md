# Events & Geography System: Stakeholder-Centered Acceptance Criteria

**Document Purpose:** Define what success looks like for each stakeholder group in v0.12.0 "balanced spacetime foundation" — including value exchanged, progress metrics, and accountability mechanisms.

**Grounding:** BTS Values Charter + CE Stakeholder Analysis + v0.12.0 GitHub Issues #1424–#1436

**Framework:** Each stakeholder group has acceptance criteria organized by:
1. **Value Received** — what they get from this work
2. **Value Contributed** — what they put in (testing, co-design, feedback, patience)
3. **High-Level Acceptance Criteria** — 3–5 testable outcomes
4. **How Progress Is Measured** — concrete indicators
5. **How Progress Is Reported** — who reports, when, to whom

**Key Principle:** Acceptance criteria are **not just technical delivery**. They measure whether the system actually serves people as promised.

---

## Stakeholder 1: Community Members (End Users)

### Value Received
- Ability to discover events within manageable distance (not "everything" overwhelming)
- Confidence that location/time information is accurate and won't surprise them
- Accessibility metadata so they can decide whether they can participate
- Calendar integration with reminders so they don't over-commit
- Private tracking of their attendance; not visible to other members by default

### Value Contributed
- Testing in real communities (pilot with 3–5 communities during v0.12.0 dev)
- Feedback on event discovery UI/UX
- Patience while system is being built (clear communication on timeline)
- Use of system in practice (generating real event data for testing)

### High-Level Acceptance Criteria

#### AC1: Event Discovery Works for Real Members in Real Geography
**What we're testing:** Can a member in a small town find nearby events without frustration?

**Acceptance Criteria:**
- A member can search events within 5 km radius using proximity search (currently impossible; requires PostGIS geometry in Space)
- Results show distance, travel time, and accessibility info
- Member can filter by: distance, date, accessibility (wheelchair, ASL, quiet space), language
- Search returns events in under 2 seconds (performance)
- At least 3 test communities run events; members can find them via proximity
- Zero members report "I didn't know this event existed" for events within 10 km

**How Progress Is Measured:**
- Proximity search performance: query time, result accuracy
- Filter effectiveness: "Did filter reduce results to manageable set?"
- Member surveys: "Could you find events you wanted to attend?"
- Usage data: number of searches, number of attendees from searches vs other sources

**How Progress Is Reported:**
- Monthly: dashboard showing searches, filters used, member satisfaction (1-5 scale)
- Quarterly: community feedback session (1 hour video call with 5–10 members)
- Before release: "Can we find and attend events successfully?" (pass/fail test with real members)

#### AC2: Event Information Is Accurate & Trustworthy
**What we're testing:** Does the member get surprised or disappointed by inaccurate location/time/accessibility info?

**Acceptance Criteria:**
- Event address, time, and accessibility info are correct for 95%+ of events (audited via sample review)
- If organizer changes location, members are notified within 24 hours
- Accessibility claims are either verified (by organizer + platform audit) or marked "unverified, please confirm"
- Member can flag inaccurate info; organizer is notified; fix is visible within 48 hours
- No member reports "I showed up and the event wasn't there" or "I couldn't get in"

**How Progress Is Measured:**
- Accuracy audit: monthly sample of 50 random events, check against real info
- Notification speed: when organizer changes location, log when member receives notification
- Inaccuracy reports: track how many members flag errors; resolution time
- Member surveys: "Was event info accurate?" "Did you know in advance if location changed?"

**How Progress Is Reported:**
- Monthly: accuracy % and top 5 inaccuracy categories ("Address wrong", "Time wrong", "No accessible entrance", etc.)
- Quarterly: "Is the system trustworthy for members? Are they confident showing up?"
- Before release: accessibility claims spot-check (visit 5 venues, verify claims match reality)

#### AC3: Accessibility Info Prevents Disappointment & Exclusion
**What we're testing:** Do members with disabilities get accurate info upfront so they can make informed decisions?

**Acceptance Criteria:**
- 80%+ of events have accessibility info (wheelchair, ASL, quiet space, service animal, etc.)
- Accessibility info is accurate: verified by organizer + platform audit + member feedback
- Members with disabilities report: "I could tell in advance whether I could attend" (not discovering barrier after arrival)
- Events marked "wheelchair accessible" are actually accessible (audit: visit all marked venues)
- No member with disability experiences "I thought I could attend, but when I arrived, I couldn't get in"

**How Progress Is Measured:**
- Event coverage: % of events with accessibility metadata
- Accuracy verification: sample audits of claimed accessibility vs real accessibility
- Member feedback: post-event surveys for members with disabilities ("Could you access what was promised?")
- Incident reports: track if member reports access barrier they didn't know about in advance

**How Progress Is Reported:**
- Monthly: accessibility coverage % by community and accessibility type
- Quarterly: feedback from members with disabilities — "Did accessibility info help you decide?"
- Before release: accessibility audit report ("Visited 10 'wheelchair accessible' venues; 9 actually accessible; 1 has inaccessible bathroom")

#### AC4: Time Zone Clarity Prevents Schedule Confusion
**What we're testing:** Do members in different time zones understand when events actually happen?

**Acceptance Criteria:**
- All events show time in member's local time zone (or clearly stated what timezone)
- NL-specific complexity is handled: NL is 30 min behind Atlantic; system doesn't confuse them
- Calendar export (ICS) includes timezone data; Google Calendar/Apple Calendar imports correctly
- Members report: "I didn't miss an event because I was confused about the time"
- Zero member reports of "Event happened an hour before I expected" (time zone error)

**How Progress Is Measured:**
- Time zone handling: test events at different times; verify calendar export accuracy
- Member experience: "Did the time make sense to you?" survey after events
- Incident tracking: log any time zone confusion reports
- Calendar integration: test import into 3 major calendar apps; verify times display correctly

**How Progress Is Reported:**
- Monthly: time zone errors (target: zero)
- Quarterly: calendar integration testing results
- Before release: "Can members reliably understand when events happen?" (pass/fail test)

#### AC5: Private Attendance Tracking Doesn't Feel Surveilled
**What we're tested:** Do members trust the system's privacy on their attendance?

**Acceptance Criteria:**
- Members can opt out of being visible in "who's attending" lists; default is private (opt-in to share)
- Organizers CAN see who's attending (needed for planning); members know this; it's transparent
- Members do NOT appear in other members' "who's going" lists (unless organizer has made attendee list public)
- Members report: "I feel in control of who knows I'm attending"
- RSVP data is not used for marketing, recommendation algorithms, or any purpose members didn't consent to

**How Progress Is Measured:**
- Survey: "Do you feel your attendance privacy is respected?" (target: 85%+ agree)
- Feature usage: how many members use privacy options? (indicates they care about it)
- Data audit: log any use of RSVP data outside of event management
- Privacy incidents: track any unauthorized use of attendance data

**How Progress Is Reported:**
- Monthly: privacy feature usage stats
- Quarterly: member privacy survey results
- Before release: privacy policy review ("RSVP data is used for X only") — member agreement required

---

## Stakeholder 2: Community Organizers (Elected Leaders)

### Value Received
- Self-service tools to create/manage events/buildings without asking developers
- Ability to change event locations and automatically notify members (transparency)
- Capacity management so they can plan food/chairs/facilitators
- Understanding of "where do we meet" across our community (place inventory)
- Ability to coordinate with neighboring communities (federation)
- Audit logs so they can document what happened for accountability reports

### Value Contributed
- Co-design participation during development (3–5 feedback sessions)
- Real-world event data during pilot (running their actual events through system)
- Patience with learning new tools
- Feedback on what's not working; advocacy for community needs
- Commitment to use system instead of switching to alternatives (stability)

### High-Level Acceptance Criteria

#### AC1: Building/Room Management Is Self-Service
**What we're testing:** Can organizers create/edit buildings and rooms without asking developers?

**Acceptance Criteria:**
- Organizer can create a new building in < 5 minutes (no form-field confusion)
- Building details include: name, address, floors, accessible entrance(s), parking, bathroom location
- Organizer can add/edit rooms within building (e.g., "Main Hall", "Meeting Room 2", "Youth Space")
- Organizer can mark room as "not available" temporarily (e.g., renovations, cleaning)
- No organizer requests developers to create building; zero tickets of "Can you add our building?"
- Organizers report: "I can manage our buildings myself"

**How Progress Is Measured:**
- Support ticket analysis: are organizers asking devs to create buildings? (target: zero)
- Task completion time: how long does it take organizer to create building? (target: < 5 min)
- Error tracking: are organizers making mistakes (e.g., wrong address)? (target: < 5% errors)
- Feature adoption: what % of communities have building inventory? (target: 80%+ by release)

**How Progress Is Reported:**
- Monthly: building creation volume and success rate
- Quarterly: organizer feedback session — "Is building management easy?" (target: "yes" from 85%+)
- Before release: end-to-end test — new organizer creates building without help; succeeds

#### AC2: Event Location Changes Notify Members & Are Transparent
**What we're testing:** When organizers need to move an event, can they do it without losing people?

**Acceptance Criteria:**
- Organizer can change event location in one place (not multiple forms)
- System sends notification to all RSVPs: "Event moved from [old] to [new] location"
- Notification includes: new address, travel time from member's location, new accessibility info
- Event history shows old location (members can see "we were at X, now at Y") — not rewritten
- Organizers report: "I can change location without losing attendees"
- Zero attendees report: "I didn't know location changed; I went to old place"

**How Progress Is Measured:**
- Notification delivery: log when location change notifications are sent; verify delivery (email/SMS)
- Member awareness: survey after location change — "Did you know the location changed?" (target: 95%+ yes)
- Attendance continuity: RSVPs don't drop after location change (proxy for: people knew and were OK with it)
- Incident tracking: "I didn't know location changed" reports (target: zero)

**How Progress Is Reported:**
- Monthly: location changes and notification success rate
- Quarterly: organizer feedback — "Can you manage location changes smoothly?"
- Before release: test scenario — organizer changes location; member receives notification; member can verify new location is accessible

#### AC3: Capacity Planning & Co-Organizer Support
**What we're testing:** Can organizers plan for "how many people are coming?" and share event management?

**Acceptance Criteria:**
- Organizer can set max capacity; system warns if capacity is reached
- Waitlist support: people can RSVP "interested" if full; moved to confirm list if spot opens
- Multiple organizers can edit same event; changes are logged (who changed what, when)
- Organizer can see RSVP summary: "8 confirmed, 3 waitlist, 2 tentative" (at a glance)
- Organizers report: "I know how many people are coming; I can plan food/space"
- Zero organizer complaints about "capacity planning was hard"

**How Progress Is Measured:**
- Feature adoption: % of events with capacity set (target: 80%+)
- RSVP accuracy: post-event, was actual attendance close to confirmed RSVPs? (target: 85%+ accuracy)
- Co-organizer usage: % of events with multiple organizers (target: 30%+)
- Change audit: all co-organizer edits are logged; no "lost" changes

**How Progress Is Reported:**
- Monthly: capacity management stats (how many events have capacity? how often hit max?)
- Quarterly: organizer feedback — "Can you plan events with confidence?" (target: "yes" from 80%+)
- Before release: co-organizer scenario test — 2 organizers edit same event; all changes are preserved and logged

#### AC4: Community Place Inventory & Resource Understanding
**What we're testing:** Can organizers understand "where do we actually meet?" and make decisions about resources?

**Acceptance Criteria:**
- Community can list all buildings/places they use (inventory view)
- For each place: usage frequency (how many events/month?), accessibility info, capacity, cost (if applicable)
- Organizers can add notes: "Moved from old hall in Jan 2025 due to roof damage" (continuity)
- Reports exist: "We use 3 rooms; event distribution is X% at place A, Y% at place B"
- Organizers report: "I understand where we meet and whether our resources match our needs"
- Evidence: organizers make informed decisions about space (e.g., "We're spending too much on Room B; let's consolidate")

**How Progress Is Measured:**
- Inventory completeness: do communities have all their places listed? (target: 95%+)
- Report generation: can organizers run "Where do we meet?" report? Does it answer their question? (qual feedback)
- Resource decisions: do organizers say they made better space/budget decisions because of system? (survey)
- Equity insight: can platform operators see "Which communities have better place access?" (aggregate, anonymous)

**How Progress Is Reported:**
- Quarterly: "How complete is your community's place inventory?" (target: 95%+ complete)
- Annual: organizer interviews — "Did understanding your place inventory help you make decisions?"
- Before release: scenario test — organizer generates "where do we meet?" report; uses it to decide about space consolidation

#### AC5: Cross-Community Coordination (Federation)
**What we're testing:** Can communities coordinate on shared events/spaces without conflict?

**Acceptance Criteria:**
- Organizers from Community A can see events from Community B when they're in shared space (not hidden)
- Clear booking system for shared venues: "Shared hall is booked Tues 6–8pm by Community A; available other times"
- Organizers report: "We can coordinate without stepping on each other's toes"
- No conflicts: "2 communities booked same room same time" (zero instances)
- When conflicts arise, clear escalation: who decides? How is it resolved? (documented, transparent)

**How Progress Is Measured:**
- Booking conflict tracking: log any double-bookings (target: zero by release)
- Cross-community event visibility: do organizers see events from other communities? (feature adoption %)
- Organizer satisfaction: "Can you coordinate with other communities?" (target: "yes" from 80%+)
- Escalation testing: if conflict happens, is there a clear resolution process?

**How Progress Is Reported:**
- Monthly: shared space bookings and conflict rate
- Quarterly: organizer feedback — "Can you coordinate across communities?"
- Before release: stress test — 3 communities book shared space over 3 months; zero conflicts because system prevents them

---

## Stakeholder 3: Members with Accessibility Needs

### Value Received
- Accessible event information in advance so they can make informed decisions
- Confidence that "accessible" venues are actually accessible (verified)
- Access service booking (interpreters, captions, accommodations) coordinated in one place
- No surprises at venue; venue details help them plan
- Sensory/neurodivergent event info so they can assess whether they can participate

### Value Contributed
- Accessibility audits: visit venues and verify claimed accessibility (if willing)
- Feedback on what accessibility info matters most to them
- Real usage data during pilot (booking events, testing access services)
- Advocacy work: pushing community to think about accessibility

### High-Level Acceptance Criteria

#### AC1: Accessibility Info Is Verified & Trustworthy
**What we're testing:** Can members with disabilities trust that "wheelchair accessible" actually means they can get in?

**Acceptance Criteria:**
- 100% of events with accessibility claims are verified by platform or community audit (before release)
- Unverified claims are marked "organizer-reported; not yet verified" (transparent)
- Verified claims have a badge/icon members can recognize
- Members report: "I trust accessibility info; if it says accessible, I know I can get in"
- Audit results: 90%+ of "wheelchair accessible" venues are actually accessible
- For venues that don't meet claims: organizers are notified; plan to fix (with timeline visible)

**How Progress Is Measured:**
- Audit completion: % of accessibility claims that are verified (target: 100% before release)
- Accuracy: for verified venues, what % are actually accessible as claimed? (target: 95%+)
- Member trust: survey — "Do you trust accessibility info?" (target: 85%+ trust)
- Incident tracking: members report barriers they didn't expect (target: < 5% of attendees)

**How Progress Is Reported:**
- Monthly: audit progress (% verified, any major issues found)
- Quarterly: member feedback — "Can you trust accessibility info?" + incident summary
- Before release: accessibility audit report ("Audited X venues; X% are accessible as claimed; flagged Y issues for fixes")

#### AC2: Access Service Booking Is Coordinated
**What we're tested:** Can members book interpreters, captions, etc. without hunting for different systems?

**Acceptance Criteria:**
- Members can request access services (ASL interpreter, CART captions, physical accommodations) in event form
- Request goes to organizer; organizer confirms availability/timeline
- Clear tracking: member knows "interpreter confirmed for June 15, 7pm"
- Organizer knows: "Member needs interpreter; I've confirmed; need to include in budget/plan"
- Members report: "I can ask for accommodations and get clear confirmation"
- Zero members report: "I requested interpreter; organizer never confirmed"

**How Progress Is Measured:**
- Access service requests: how many are made? what types? (ADA/AODA reporting)
- Confirmation rate: % of requests that get confirmed? (target: 100%)
- Confirmation speed: how long until organizer responds? (target: < 48 hours)
- Member satisfaction: "Did you get the accommodations you requested?" (target: 95%+ yes)

**How Progress Is Reported:**
- Monthly: access service request volume and confirmation rate
- Quarterly: member feedback — "Can you get accommodations you need?" + incident summary
- Annual: accessibility metrics report (ADA-style: requests made, confirmed, types of services)

#### AC3: Venue Navigation Support
**What we're tested:** Can members with mobility/sensory disabilities navigate to the right place at the event?

**Acceptance Criteria:**
- Venue map includes: main entrance, accessible entrance (if different), parking, drop-off, accessible washroom location, elevator/stairs
- Event details include: where to meet organizer, where interpreter will be (if applicable), where quiet space is (if applicable)
- Members report: "I knew exactly how to get in and where to go"
- Zero members report: "I couldn't figure out how to get into the building" or "I had nowhere to sit/rest"

**How Progress Is Measured:**
- Map completion: % of venues with full navigation details (target: 95%+)
- Member feedback: "Could you navigate the venue easily?" post-event survey (target: 90%+ yes)
- Incident tracking: navigation problems reported (target: < 5% of attendees)

**How Progress Is Reported:**
- Quarterly: venue navigation coverage and member feedback
- Before release: venue navigation test — members with various disabilities navigate 3 venues; feedback collected

#### AC4: Sensory & Neurodivergent Event Info
**What we're tested:** Can neurodivergent and sensory-sensitive members find events they can tolerate?

**Acceptance Criteria:**
- Events include sensory info: noise level (quiet/moderate/loud), lighting (natural/fluorescent/mixed), fragrance policy, stimming welcome/not
- Event structure is clear: "7–8pm: social hour (conversation), 8–9pm: workshop (presentation, optional interaction)"
- Organizers are trained: "If someone stims, that's not a problem; don't comment" (inclusive culture)
- Members report: "I know in advance whether I can handle the sensory environment"
- Organizers report: "I understand neurodivergent accessibility; I can plan for it"

**How Progress Is Measured:**
- Sensory info coverage: % of events with sensory details (target: 80%+)
- Organizer training: % of organizers trained on neurodivergent accessibility (target: 60%+)
- Member satisfaction: "Did the sensory environment match what I expected?" (target: 85%+ yes)
- Incident tracking: sensory overwhelm reports (target: < 10%)

**How Progress Is Reported:**
- Quarterly: sensory info coverage by community
- Annual: organizer training participation rate
- Before release: neurodivergent member feedback — "Can you find events you can attend?"

---

## Stakeholder 4: Historians & Accountability Stewards

### Value Received
- System that records "why" (not just "what" happened)
- Historical continuity visible: when did we move? why? what was the impact?
- Place/event timelines so community can understand its own evolution
- Collective memory; not siloed with one person
- Audit trail for accountability: decisions documented, not retroactively rewritten

### Value Contributed
- Time spent recording history (labor donation)
- Research/documentation work (finding old records, connecting to current data)
- Guidance on what history matters to their community
- Validation work: checking that records are accurate

### High-Level Acceptance Criteria

#### AC1: Event/Place Historical Notes Are Recorded & Visible
**What we're tested:** Can historians record "why" events/places matter and have that history persist?

**Acceptance Criteria:**
- Historians can add notes to events/places: "Moved from old hall in Jan 2025 due to roof damage"
- Notes are visible to all members (transparent history; not hidden from community)
- Notes are editable by historians; edited versions show "changed on X by Y" (audit trail, not rewriting)
- Notes persist: if place is deleted, history is still accessible (archived)
- Historians report: "I can document why we do things; the history is preserved"
- Evidence: communities can answer "why did we move?" without asking elders in person

**How Progress Is Measured:**
- Historical note creation: how many notes added? by how many historians? (adoption rate)
- Completeness: for major moves/changes, are there notes? (% of major events documented)
- Member awareness: survey — "Can you understand why your community made decisions?" (target: 70%+ yes)
- Historian satisfaction: "Can you preserve history?" (target: 80%+ yes)

**How Progress Is Reported:**
- Quarterly: historical note volume and historian engagement
- Annual: historian interviews — "Is the system helping you preserve community memory?"
- Before release: historical documentation test — historians document 3 major community events; members can read and understand the history

#### AC2: Place Timeline & Continuity
**What we're tested:** Can communities understand how their places have evolved?

**Acceptance Criteria:**
- Place history shows: when acquired/rented, major changes (renovations, damage, name changes), when lost (moved away)
- Timeline view shows: "Venue A used from 2015–2023, then moved to Venue B in 2023"
- Photos/documents can be attached to timeline entries (archival)
- Historians can update timeline; all members see current + historical view
- Community report available: "Our place journey" (visual timeline)
- Historians report: "I can show how our spaces have evolved"

**How Progress Is Measured:**
- Timeline completeness: for how many places is full history recorded? (target: 90%+ of major places)
- Photo/document attachment: what % of timeline entries have supporting evidence? (target: 70%+)
- Member understanding: survey — "Do you understand your community's place history?" (target: 75%+ yes)
- Historian satisfaction: "Can you build timelines?" (target: 80%+ yes)

**How Progress Is Reported:**
- Quarterly: place timeline completeness
- Annual: "Place Journey" reports generated for 3 communities; shared in annual report
- Before release: timeline test — historians create complete timeline for major place; community can view and understand

#### AC3: Gentrification & Displacement Tracking
**What we're tested:** Can communities document changes in place access due to economics/gentrification?

**Acceptance Criteria:**
- Historians can record: "We used this space from 2000–2015; lost it to rent increase in 2015"
- Loss is visible: place marked "historical, no longer accessible" not deleted
- Reason is documented: "Rent increased from $X to $Y; not affordable"
- Community can see pattern: "We've lost 3 spaces to gentrification; gained 0 new spaces"
- Impact is visible: historical decision-making (other communities faced same choice; what did they do?)
- Historians report: "I can document displacement; community can see the pattern"

**How Progress Is Measured:**
- Displacement documentation: how many spaces documented as lost/displaced? (volume, completeness)
- Reason documentation: for lost spaces, % with documented reasons? (target: 100%)
- Pattern visibility: can organizers see "how many spaces have we lost?" (aggregate view working?)
- Historical continuity: do records help communities make better decisions? (qual feedback)

**How Progress Is Reported:**
- Annual: displacement report ("X spaces lost, Y reasons, Z patterns")
- Quarterly: historian feedback — "Can you document displacement impacts?"
- Before release: documentation test — historians document 5 lost spaces with reasons; aggregate report generated

#### AC4: Collective Stewardship of Memory
**What we're tested:** Can multiple historians collaborate on shared history without conflict?

**Acceptance Criteria:**
- Multiple historians can edit same record; no "lost" changes
- Version history is visible: "Changed on June 1 by Alice (added photo); changed June 2 by Bob (corrected date)"
- Conflict resolution: if historians disagree on fact, there's a process (discussion, evidence required)
- Historians report: "I can work with other historians; we don't step on each other"
- Evidence: communities have multi-person historian teams; decisions are made collectively

**How Progress Is Measured:**
- Multi-historian engagement: % of places/events with 2+ historians contributing? (target: 50%+ by year 2)
- Edit history completeness: all edits tracked and visible? (audit trail quality)
- Conflict resolution: when historians disagree, is there a documented process? Is it working?
- Historian satisfaction: "Can you work together on history?" (target: 80%+ yes)

**How Progress Is Reported:**
- Quarterly: historian collaboration stats (how many places have multi-historian teams?)
- Annual: conflict resolution case studies (if any, how were they handled?)
- Before release: collaboration test — 3 historians work on same timeline; all edits are preserved; no conflicts

---

## Stakeholder 5: Developers & Maintainers

### Value Received
- Clear contracts for models/APIs so they can confidently implement features
- Stable schema (not constantly changing; changes have migration path)
- Comprehensive tests so they can refactor without breaking things
- Transparent values in code: decisions are auditable, not guessed
- Extensibility: communities can customize without forking

### Value Contributed
- Implementation work (build the features)
- Testing & verification (automated + manual)
- Code review & architecture thinking
- Patience with requirements changing as we learn from communities

### High-Level Acceptance Criteria

#### AC1: Clear, Stable Model Contracts
**What we're tested:** Can developers understand and implement geography/location/event/calendar models without confusion?

**Acceptance Criteria:**
- Space model contract is defined: "Is Space geometry or float? Answer: [decision]. Here's the migration path."
- Event location contract is clear: "Event can have zero or one Location; Location can be simple/address/building"
- Each model has documented: attributes, associations, validations, scopes, side-effects (e.g., GeocodingJob)
- No commented-out code; no dead methods (clean, maintainable)
- Contract document exists and is referenced in model files
- Developers report: "I understand the models; I can build features confidently"

**How Progress Is Measured:**
- Contract documentation: complete for all geography/location/event models? (target: 100%)
- Code cleanliness: commented-out code? dead methods? (target: 0)
- Developer confidence: "Do you understand the models?" survey (target: 85%+ yes)
- Rework rate: features that are built and then have to be redone (target: 0)

**How Progress Is Reported:**
- Monthly: contract documentation progress
- Quarterly: developer feedback — "Are the models clear?" + list any confusion
- Before release: architecture review — external developers read contracts; verify they're clear and accurate

#### AC2: Comprehensive Test Coverage
**What we're tested:** Are the system's features well-tested so changes don't break things?

**Acceptance Criteria:**
- Model specs: all geography/location/event model behavior is covered by tests
- Request specs: EventResource attributes, filters, geographic queries are tested
- System specs: end-to-end flows (organizer creates event → member finds it → attends) are tested
- Regression specs: v0.12.0 features are protected by tests that prevent re-breaking them
- Test coverage: 80%+ code coverage for geography/location/event systems (target)
- Developers report: "I can refactor without worrying about breaking things"

**How Progress Is Measured:**
- Test coverage: code coverage % (target: 80%+ for geography/location/events)
- Test-driven development: tests written before features? (target: 100%)
- Regression detection: when a change is made, how quickly do tests catch issues? (speed of feedback)
- Test maintenance: are tests keeping up with code? outdated tests? (quality signal)

**How Progress Is Reported:**
- Monthly: code coverage metrics
- Quarterly: test quality assessment ("Are tests catching real bugs?" vs "Are tests just rubber-stamping?")
- Before release: test suite passes; coverage report published

#### AC3: Spatial Queries Work & Perform Well
**What we're tested:** Can PostGIS proximity queries work correctly and fast?

**Acceptance Criteria:**
- Proximity search works: "Find events within 5 km" returns correct results (tested with known locations)
- Query performance: proximity search on 10k events returns results in < 1 second
- GiST indexes are created and used: query plans confirm index usage
- Developers can add new spatial queries without performance degradation
- Developers report: "Spatial queries work as expected; I'm confident using PostGIS"

**How Progress Is Measured:**
- Query correctness: unit tests verify proximity search math (ST_DWithin behavior)
- Query performance: benchmark tests track query time (target: < 1s for 10k events)
- Index usage: EXPLAIN plans show index usage (not full table scan)
- Regression: performance tests fail if a change makes queries slower (automated detection)

**How Progress Is Reported:**
- Monthly: proximity query performance metrics
- Quarterly: performance review ("Are queries still fast?" + incident analysis if degradation)
- Before release: performance benchmark report ("Proximity search on 10k events: 0.8s")

#### AC4: Extensibility & Customization
**What we're tested:** Can different communities customize geography/events without forking code?

**Acceptance Criteria:**
- Hooks/override points exist for: custom geography models, custom event attributes, custom accessibility fields
- Configuration exists for: timezone defaults, geography labels, accessibility templates
- Plugin architecture documented: "Here's how to add custom geography hierarchy"
- Example: Dene community can define their own place-naming without code changes
- Developers report: "I can customize the system; I don't need to fork"
- Communities report: "My specific needs are supported; I'm not fighting the system"

**How Progress Is Measured:**
- Hook documentation: all hooks documented and examples provided? (target: 100%)
- Configuration coverage: what % of customization needs can be met via config? (target: 80%+)
- Customization usage: how many communities customize? what do they customize? (adoption)
- Fork prevention: are any communities forced to fork? (target: 0)

**How Progress Is Reported:**
- Quarterly: customization usage stats
- Annual: case study — "How did [community] customize the system?" + what hooks/configs were used?
- Before release: extensibility test — add custom geography model without code changes to core

---

## Stakeholder 6: Platform Organizers & Governance

### Value Received
- Visible data on cross-community patterns (where are events? are they equitable?)
- Clear incident tracking (safety issues, conflicts, equity gaps)
- Policy decision records so future platform organizers understand "why did we decide that?"
- Escalation procedures for when communities disagree
- Audit trail that prevents cover-ups or institutional gaslighting

### Value Contributed
- Governance time (policy development, conflict resolution, decision-making)
- Oversight work (reviewing incidents, auditing equity)
- Patience with decentralized decision-making (slower than top-down)
- Commitment to transparency (even when uncomfortable)

### High-Level Acceptance Criteria

#### AC1: Cross-Community Patterns Are Visible
**What we're tested:** Can platform organizers understand whether events/places are equitable across communities?

**Acceptance Criteria:**
- Dashboard exists: events per community/region, attendees per event, accessibility %
- Data is accurate: sampled against real event data; < 1% error
- Equity gaps are visible: "Settlement X has 10 events/month; Settlement Y has 1 event/month"
- Trend analysis is possible: "Over 6 months, have we improved equity or gotten worse?"
- Organizers report: "I understand where resources are concentrated; I can see gaps"
- Evidence: platform decisions are informed by data (e.g., "We're investing in rural communities because attendance is low")

**How Progress Is Measured:**
- Dashboard completeness: all key metrics visible? (target: 100%)
- Data accuracy: monthly verification against event database (target: < 1% error)
- Equity gap detection: can dashboard spot "Settlement Y is underserved"? (qualitative: does organizer notice?)
- Decision impact: are equity-focused investments made based on data? (yes/no)

**How Progress Is Reported:**
- Monthly: equity dashboard report (events/communities, accessibility %, attendance patterns)
- Quarterly: organizer feedback — "Does the data help you understand equity?" + decisions made based on data
- Annual: equity trends report ("Here's how equity has changed over the year")

#### AC2: Safety Incidents Are Tracked & Responded To
**What we're tested:** When safety issues arise at venues/events, is there a clear, auditable process?

**Acceptance Criteria:**
- Incident log exists: all reported safety issues are logged (harassment, discrimination, violence, accessibility failures)
- Response tracking: incident logged → community contacted → investigation → resolution visible
- Escalation is clear: community tries to handle internally → platform supports → platform intervenes (3-tier)
- Transparency: affected communities know incident was reported and how it was resolved (not secret)
- Prevention: patterns are identified (e.g., "Venue X has had 3 incidents; platform intervenes")
- Organizers report: "If safety issues arise, we have support and transparency"

**How Progress Is Measured:**
- Incident tracking: are all reports logged? (completeness)
- Response speed: incident → platform response time (target: < 48 hours)
- Resolution visibility: affected communities know outcome? (survey)
- Pattern detection: major incident patterns are caught? (e.g., "Venue X is unsafe")

**How Progress Is Reported:**
- Monthly: incident log summary (types, locations, response times) — anonymized
- Quarterly: pattern analysis ("What types of incidents are rising/falling?")
- Annual: safety report ("Here's what happened, how we responded, what we learned")

#### AC3: Policy Decisions Are Recorded & Appealable
**What we're tested:** When platform makes policy decisions (about shared venues, accessibility standards, etc.), is the reasoning transparent and appealable?

**Acceptance Criteria:**
- Decision log exists: all platform policy decisions are recorded with reasoning
- Reasoning is visible: "We decided X because of Y, considering Z perspectives"
- Appeals are possible: if community disagrees, clear process for appeal
- Resolution is tracked: appeal → review → new decision → communication
- Decisions are revisable: if new evidence emerges, decisions can change
- Organizers report: "I understand platform policies; they make sense; I can appeal if I disagree"

**How Progress Is Measured:**
- Decision documentation: all major policies documented? (target: 100%)
- Reasoning clarity: outside readers understand the rationale? (qualitative review)
- Appeal usage: how many appeals? what was outcome? (process validation)
- Decision reversals: policies changed based on new evidence? (flexibility signal)

**How Progress Is Reported:**
- Quarterly: new policy decision summary (what was decided, reasoning, appeal outcomes)
- Annual: policy review ("Which policies worked? Which caused problems?")
- Before release: policy documentation review (external reader can understand policies and rationale)

#### AC4: Conflict Resolution Has Clear Process
**What we're tested:** When communities conflict over shared space or policy, is there a clear, fair process?

**Acceptance Criteria:**
- Conflict resolution process is documented: how are disputes resolved? (step-by-step)
- Escalation is clear: community discussion → mediator → platform decision (3-tier)
- Timeline is visible: "Community A reported conflict on X; we expect resolution by Y"
- Resolution is transparent: all parties understand outcome and reasoning
- Process is tested: mock conflict is walked through; process works? (simulation)
- Organizers report: "If conflict arises, we know how to resolve it fairly"

**How Progress Is Measured:**
- Process documentation: clear conflict resolution procedure exists? (target: yes, before release)
- Conflict tracking: conflicts logged and resolved? (adoption of process)
- Resolution satisfaction: all parties satisfied with outcome? (survey)
- Appeal usage: conflicts that escalate to appeal? (process quality indicator)

**How Progress Is Reported:**
- Quarterly: conflict resolution summary (# of conflicts, # resolved at community level vs escalated, timeframes)
- Annual: conflict case studies (anonymous, but showing how conflicts were resolved)
- Before release: process simulation (mock conflict walked through; process validated)

---

## Stakeholder 7: Newcomers & Immigrant Communities

### Value Received
- Geographic orientation that makes sense in their language/context
- Culturally-safe event information (knowing they'll be welcomed)
- Multiple languages so they're not dependent on translation
- Accessible event information (not requiring local knowledge to decipher)
- Immigration-aware accessibility (understanding service availability, digital literacy, etc.)

### Value Contributed
- Feedback on language/cultural appropriateness (testing in their languages)
- Real-world usage (testing the system in multiple languages)
- Advocacy work (pushing system to be inclusive)
- Patience with iteration and improvement

### High-Level Acceptance Criteria

#### AC1: Geographic Orientation Works Without Local Knowledge
**What we're tested:** Can a newcomer unfamiliar with NL geography understand "where is this event?"

**Acceptance Criteria:**
- Events show: specific address + neighborhood + distance from landmark (e.g., "Near downtown St. John's")
- Geography is searchable: newcomer can search "St. John's" or "Avalon Peninsula" without knowing exactly what to search
- Hierarchy is clear: "Newfoundland → Eastern Avalon → St. John's → Downtown → Water Street" (navigable for non-locals)
- Descriptions are simple: not using local jargon ("Townie", "Bay" as direction, etc.)
- Maps are included: visual navigation (not just text addresses)
- Newcomers report: "I could figure out where the event was without asking locals"

**How Progress Is Measured:**
- Geography search usability: can newcomers find neighborhoods/towns via search? (task-based test)
- Landmark usage: do events include landmarks? (adoption, completeness)
- Member feedback: "Could you find the location?" post-event survey (target: 85%+ yes)
- Local jargon audit: system avoids NL-specific jargon? (code review)

**How Progress Is Reported:**
- Quarterly: geography coverage and landmark usage stats
- Before release: newcomer usability test ("Find this event's location" task with 5 newcomers; track success)

#### AC2: Cultural Safety & Accessibility of Events
**What we're tested:** Do newcomers know whether events are culturally safe and whether they'll be welcomed?

**Acceptance Criteria:**
- Events show: community self-descriptions ("LGBTQ2S+-welcoming", "Newcomer-led", "Immigrant-friendly")
- Events note cultural specifics: "Halal/Kosher food provided", "Multiple languages", "Children welcome"
- Organizers are trained: "Welcome newcomers; don't assume they know local norms"
- Reviews from newcomers/immigrants: other newcomers can rate "Did I feel welcomed?" (peer trust)
- Newcomers report: "I knew I would be welcomed; I felt safe"
- Evidence: newcomers attend events; return for more (vs one-time visitors)

**How Progress Is Measured:**
- Self-description adoption: % of events with community welcome info? (target: 60%+)
- Newcomer reviews: how many newcomer-written reviews? are they positive? (sentiment analysis)
- Repeat attendance: do newcomers who attend once attend again? (retention)
- Newcomer feedback: "Do you feel welcomed?" survey (target: 80%+ yes)

**How Progress Is Reported:**
- Monthly: community welcome info adoption
- Quarterly: newcomer feedback — "Do you feel welcomed?" + sentiment analysis of reviews
- Before release: newcomer usability test — newcomers browse events; assess cultural safety

#### AC3: Platform Available in Multiple Languages
**What we're tested:** Can non-English-speaking community members use the system?

**Acceptance Criteria:**
- Major UI languages supported: Spanish, French, Arabic, Chinese (priority based on NL demographics)
- Event descriptions translated by communities: volunteers translate event info; organizers approve
- Key docs available: how to RSVP, accessibility info, community guidelines (in multiple languages)
- Platform is usable, not just translated: navigation works in all languages; no broken UI elements
- Newcomers report: "I can use this system in my language"
- Evidence: signups/usage increase in communities with language support

**How Progress Is Measured:**
- Translation coverage: % of platform in each language (target: 80%+ for major UI)
- Crowdsourced translation adoption: how many communities translate events? (% of events)
- Usability in each language: does UI work correctly in all languages? (QA testing)
- Usage growth: do signups increase after language is added? (impact measurement)

**How Progress Is Reported:**
- Quarterly: translation coverage by language and system area
- Annual: impact report ("After Spanish support was added, X% more Spanish-speaking events created")
- Before release: language usability test (navigate UI in 3 languages; all core tasks work)

#### AC4: Digital Accessibility for Low-Literacy Users
**What we're tested:** Can people with low digital literacy or literacy in general use the system?

**Acceptance Criteria:**
- Venue photos and maps are available (visual navigation, not text-only)
- Event information includes spoken/video descriptions (not just text)
- System uses simple language: "Show map" not "Display geospatial representation"
- Community support is available: "Call this number to get help RSVPing" (not tech support, human support)
- Organizers can read event info aloud for members (accessibility, not assumption of literacy)
- Low-literacy users report: "I could figure out how to RSVP without reading long forms"

**How Progress Is Measured:**
- Visual coverage: % of events with venue photos/maps? (target: 80%+)
- Simple language audit: is UI language simple? (readability scoring)
- Support access: how many people use non-digital support? (phone, in-person help)
- Low-literacy user feedback: "Could you use the system?" (qualitative)

**How Progress Is Reported:**
- Quarterly: visual content coverage and language simplicity audit results
- Before release: low-literacy user test ("RSVP for an event" task with 5 low-literacy users; track success)

---

## Stakeholder 8: Movement Partners & Larger Ecosystem

### Value Received
- Ability to coordinate multi-community events (training, conferences, celebrations)
- Access to aggregated data on community organizing (research/learning)
- Shared infrastructure for resource management (equipment, funding)
- Integration with other movement tools (not duplicate effort)
- Alignment on values (technology serves movement, not the reverse)

### Value Contributed
- Partnership work (integrating with other movement tools/organizations)
- Data sharing (with privacy safeguards; learning from their events)
- Governance participation (movement voice on platform decisions)
- Long-term commitment (using CE instead of building separate tools)

### High-Level Acceptance Criteria

#### AC1: Multi-Community Event Coordination Works
**What we're tested:** Can movement partners organize large, cross-community events via the system?

**Acceptance Criteria:**
- Multi-location events are supported: event in one place; communities travel from different locations; distances shown
- Federation view works: organizer from Community A can see who's RSVPing from Community B, Community C (for planning)
- Coordination is clear: "Community A: 8 confirmed, Community B: 3 waiting for car arrangement, Community C: 6"
- Messaging is possible: organizers can coordinate within platform (not third-party tools)
- Partners report: "We can coordinate large cross-community events smoothly"
- Evidence: multi-community events successfully coordinated; no missed logistics

**How Progress Is Measured:**
- Multi-location event adoption: how many events involve 2+ communities? (% of events)
- Coordination success: organizers report smooth coordination? (survey)
- Attendance coordination: do communities arrange rides/logistics together? (observed behavior)
- Event success: multi-community events have high attendance/satisfaction? (metrics)

**How Progress Is Reported:**
- Quarterly: multi-community event volume and success metrics
- Annual: case study ("How [movement] coordinated X-community conference via CE")
- Before release: multi-community event scenario test (3 communities, 100 expected attendees, coordinate logistics via system)

#### AC2: Shared Resource Management (Equipment/Funding)
**What we're tested:** Can partners share equipment (van, projector, etc.) or funding via the system?

**Acceptance Criteria:**
- Equipment booking is visible: "Van is booked Sat 2–4pm by Community A; available other times"
- Equipment + event linking works: "We need van for June 15 event; book in same place"
- Insurance/liability tracked: "This equipment has $X liability requirement; certify when booking"
- Funding tracking exists: "We allocated $X to Community A; they've spent $Y so far" (transparent budget)
- Partners report: "We can share resources efficiently; no double-booking or lost track of money"

**How Progress Is Measured:**
- Resource booking usage: % of equipment with bookings? (adoption)
- Booking conflict rate: double-bookings? (target: 0)
- Insurance tracking: liability requirements documented/met? (compliance)
- Budget tracking: partners can see spend vs allocation? (feature works)

**How Progress Is Reported:**
- Monthly: resource booking stats and conflict rate
- Quarterly: budget utilization report (resources allocated vs spent)
- Before release: shared resource scenario test (equipment + funding tracking for 3 organizations)

#### AC3: Data Sharing & Learning (Research/Evaluation)
**What we're tested:** Can movement partners access aggregated data to learn from organizing patterns?

**Acceptance Criteria:**
- Aggregated data available (no individual privacy leaks): "X events across Y communities; Z attendance"
- Analysis possible: "Over 6 months, which event types are growing? declining?" (learning)
- Research partnerships possible: external researchers can access anonymized data (with approval)
- Partners report: "We can understand movement trends and learn from each other"
- Evidence: partners use data to inform strategy (e.g., "We see events declining; let's investigate why")

**How Progress Is Measured:**
- Data access availability: can partners access aggregated data? (yes/no)
- Privacy verification: is data actually anonymized? (audit)
- Research usage: are movement partners using data? (adoption)
- Decision impact: do partners make strategy decisions based on data? (evidence)

**How Progress Is Reported:**
- Quarterly: aggregated data report (event trends, attendance patterns, community health signals)
- Annual: research partnership case study ("How did [movement] use CE data to improve?")
- Before release: data access & privacy audit (external review of anonymization)

#### AC4: Values Alignment & Governance Partnership
**What we're tested:** Does CE embody movement values? Does movement have voice in governance?

**Acceptance Criteria:**
- Values are visible in decisions: "We designed X because of Y value" (not opaque choices)
- Movement partners are in governance: representative(s) on platform organizer team
- Decisions are transparent: movement can see/contest platform policies that affect them
- Conflicts are resolved with movement input: not top-down decisions
- Partners report: "CE reflects our values; we have say in decisions"
- Evidence: movement organizations choose CE over alternatives; recommend to others

**How Progress Is Measured:**
- Values documentation: are decisions documented with values reasoning? (completeness)
- Movement representation: movement partners on governance team? (yes/no + frequency of participation)
- Decision transparency: movement can see and contest decisions? (process works)
- Partner satisfaction: "Does CE reflect your values?" (survey, target: 80%+ agree)

**How Progress Is Reported:**
- Quarterly: governance participation summary (who participated, what was decided)
- Annual: partner satisfaction survey ("Does CE reflect your values?" + open feedback)
- Before release: values audit (external movement partner reviews CE design; verifies alignment)

---

## Cross-Stakeholder Success Metrics (Holistic Health Check)

Beyond individual stakeholder criteria, the system should be evaluated on **systemic health**:

### 1. No Stakeholder Is Sacrificed for Another
- ✅ **Test:** If improving for one stakeholder breaks something for another, does it get fixed?
- **Measurement:** track trade-offs; verify none are one-way (A always loses, B always wins)

### 2. Values Alignment Improves Over Time
- ✅ **Test:** Does the system get more aligned with BTS values as v0.12.0 ships?
- **Measurement:** Four Pre-Action Tests assessed monthly; trend direction (improving/declining)

### 3. Movement Partners Stay & Deepen Commitment
- ✅ **Test:** Are movement partners using CE more, or less, over time?
- **Measurement:** usage growth, new partnerships, retention rate

### 4. Members Feel Heard
- ✅ **Test:** Do members believe their feedback is incorporated?
- **Measurement:** survey — "When I give feedback, does the platform improve?" (target: 70%+ agree)

### 5. Community Autonomy Increases
- ✅ **Test:** Can communities self-service more without asking developers/organizers?
- **Measurement:** % of organizer requests that can be self-served (target: 90%+)

### 6. Accessibility Becomes Default, Not Afterthought
- ✅ **Test:** Are new features accessible by default, or bolted on later?
- **Measurement:** accessibility audit on new features (target: 100% accessible from initial release)

---

## Implementation Strategy

### Phase 1: Stakeholder Engagement (Before v0.12.0 Development Starts)
- [ ] **Weeks 1–2:** Share stakeholder analysis with representatives from each group
- [ ] **Weeks 3–4:** Facilitate feedback sessions (1–2 hours each group); refine acceptance criteria
- [ ] **Week 5:** Publish final acceptance criteria; get stakeholder sign-off

### Phase 2: Development with Accountability (During v0.12.0 Implementation)
- [ ] **Monthly:** Report progress on all acceptance criteria
- [ ] **Monthly:** Stakeholder check-in calls (15 min each group; "Is this working as promised?")
- [ ] **Quarterly:** Full stakeholder feedback sessions; revise criteria if needed
- [ ] **Continuous:** Catch failing criteria early; address before release

### Phase 3: Release Validation (Before v0.12.0 Ships)
- [ ] **2 weeks before release:** Complete all acceptance criteria tests
- [ ] **1 week before release:** Stakeholder signoff ("We've met your needs")
- [ ] **At release:** Publish progress report + "What we learned" + "What's next"

### Phase 4: Post-Release Learning (Continuous)
- [ ] **Monthly:** Measure metrics defined in each acceptance criteria
- [ ] **Quarterly:** Assess whether improvements actually served people as promised
- [ ] **Annual:** Full system review — "Did v0.12.0 succeed?" grounded in stakeholder voice, not feature checklist

---

## Values-Grounded Evaluation Framework

At any point, evaluate v0.12.0 using **BTS Four Pre-Action Tests**:

### 1. Love/Inclusivity
- ❓ Does this respect the humanity of all stakeholders?
- ❓ Could any group be harmed or excluded?
- ✅ **Evidence:** Accessibility audits, member feedback, newcomer testing

### 2. Cooperation/Solidarity
- ❓ Does this distribute power or concentrate it?
- ❓ Are marginalized communities' needs centered?
- ✅ **Evidence:** Governance representation, priority allocation, voice in decisions

### 3. Accountability/Stewardship
- ❓ Is this auditable and transparent?
- ❓ Is reasoning visible? Can decisions be contested?
- ✅ **Evidence:** Decision logs, stakeholder appeal processes, public reporting

### 4. Care/Resilience
- ❓ Could this harm vulnerable members?
- ❓ Is the system resilient to failure (single point of failure prevention)?
- ✅ **Evidence:** Incident tracking, safety procedures, redundancy in critical systems

**If v0.12.0 fails any test, redesign before release.**

---

## Success = Sustained Trust & Repeat Use

The ultimate acceptance criteria: **"Would stakeholders use this system again? Would they recommend it to others?"**

- Members: "I found an event; I went; I felt safe; I'll use this again"
- Organizers: "I created an event; people found it; I didn't have to ask developers; I'll do this again"
- Accessibility advocates: "I got the info I needed; barrier-free; I trust it"
- Historians: "My community's history was preserved; future people can understand our decisions"
- Developers: "The code is clear; I can maintain this; I'm confident"
- Governance: "We can make fair decisions; transparency is real; conflict resolution works"
- Newcomers: "I belonged; the platform welcomed me in my language; I'm part of this"
- Movement partners: "We coordinated seamlessly; the system serves our values; we're using this long-term"

If all 8 groups can say yes, v0.12.0 succeeded.

---

## Revision & Iteration

These acceptance criteria are **living documents**. They should be:
- Updated quarterly as we learn what actually matters to stakeholders
- Revised if unintended consequences emerge (e.g., "This accessibility feature works but created a new barrier")
- Expanded if new stakeholder needs emerge (e.g., "We didn't think about people with hearing voices, but they exist and have needs")

**Owner:** Platform Organizers (governance) + Developers (implementation)  
**Stakeholder input cadence:** Monthly check-ins + quarterly feedback sessions + annual review  
**Public reporting:** Monthly progress report visible to all stakeholders; no hidden metrics
