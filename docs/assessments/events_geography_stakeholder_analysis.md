# Events & Geography System: Stakeholder Analysis & Values-Grounded Improvement Plan

**Author:** Claude Code  
**Date:** June 3, 2026  
**Scope:** Stakeholder needs, user stories, and values alignment for CE events/geography system improvements (informed by v0.12.0 "balanced spacetime foundation" milestone and BTS foundational values)  
**Grounded in:** [BTS Values Charter](../../bts-cloud/n8n/management-tool/docs/bts-values-charter.md), [CE Values & Governance Map](../../bts-cloud/n8n/management-tool/docs/community-engine-in-universe-0.md), [ICA Cooperative Principles](https://www.ica.coop/en/cooperatives/cooperative-identity)

---

## Foundation: BTS Values & Cooperative Mission

### BTS 5 Foundational Principles

1. **Love** — Genuine human connection, dignity, and flourishing (not engagement metrics)
2. **Inclusivity** — Genuinely accessible to excluded communities (queer, newcomers, undocumented, people without resources)
3. **Care** — Responsibility for effects on vulnerable people first
4. **Resilience** — Tools that work when things are hard
5. **Hope** — Collective action works; technology as evidence, not substitute

### BTS 8 Core Values (Action Compass)

1. **Curiosity** → keep asking if this actually serves people
2. **Kindness** → design for the person having a hard day
3. **Generosity** → share knowledge and capacity freely
4. **Reciprocity** → give back to commons; no extracting without contributing
5. **Cooperation** → humans and bots working together
6. **Solidarity** → stand with communities in their struggles
7. **Accountability** → own mistakes, log actions, make reasoning visible
8. **Stewardship** → long-term thinking for systems others depend on

### 3 Transformative Pathways

- **Discovery** — help communities understand their situation and learn
- **Connection** — build infrastructure for coordination and relationships
- **Empowerment** — communities more capable, not more dependent

### Cooperative Principles (ICA 1995, embedded in CE)

1. ✅ Voluntary and open membership
2. ✅ Democratic member control
3. ✅ Member economic participation
4. ✅ Autonomy and independence
5. ✅ Education, training, and information
6. ✅ Co-operation among cooperatives
7. ✅ Concern for community

---

## Stakeholder Map: Events & Geography System

The events and geography system serves **7 distinct stakeholder groups**, each with unique needs, constraints, and relationships to the BTS values. This assessment identifies the stakeholder-specific user stories and improvement priorities.

---

## 1. Community Members (End Users)

**Who they are:** Individuals attending, organizing, and learning about community events and places. Includes newcomers, members with disabilities, people managing multiple community commitments, members from marginalized communities.

**Why they matter to this system:** They are the "why" — the people whose lives events and places directly shape. Their ability to find, understand, join, and safely participate in events determines whether the platform serves its mission.

**Core values grounding:**
- **Love** — Design with dignity; platform should help people find belonging
- **Inclusivity** — Events and places must be accessible to people with disabilities, language barriers, economic constraints, and safety concerns
- **Care** — Heightened scrutiny for members who are queer, newcomers, undocumented, or have safety histories
- **Hope** — Technology should make it easier (not harder) to participate in collective action

### User Stories & Needs

#### 1.1 Finding Events in My Locale

**User story:** As a newcomer to NL, I want to discover community events happening near where I live or work so I can build local connections and learn how to participate.

**Stakeholder constraints:**
- May not know the local geography (city/street/neighborhood names)
- May not know what a "settlement" or "region" means in NL context
- May have accessibility needs (wheelchair ramps, ASL, sensory-friendly events)
- May have language barriers
- Limited transportation; distance matters

**Improvement priorities (grounded in geography system):**
- **Proximity search on events** — "Show me events within 5 km of my address" (currently impossible due to float-only coordinates)
- **Accessible geography names** — use familiar names (neighborhood, street) not just Census administrative divisions
- **Accessibility metadata on events** — venue accessibility, transportation, childcare, language services, cost
- **Timezone/local context** — show times in my local timezone; don't lose members to schedule confusion

**Values alignment:**
- **Inclusivity:** Removes friction for people unfamiliar with local geography
- **Care:** Accessibility metadata prevents situations where members show up unable to participate
- **Discovery:** Geographic discovery is a pathway to learning about what's happening

#### 1.2 Understanding Where & When an Event Really Is

**User story:** As someone with cognitive disability or anxiety about new places, I need clear, concrete information about where an event is happening so I can plan my attendance without stress or surprise.

**Stakeholder constraints:**
- May need step-by-step directions or visual landmarks
- May need to know building layout (which door, where to wait, bathroom location)
- May need to verify address multiple times due to executive function challenges
- May need to know parking, transit, accessibility details

**Improvement priorities (grounded in geography system):**
- **Rich location data** — not just address, but venue details (room/floor, parking, building entrance)
- **Event location history** — if organizer has moved event location, show old and new clearly
- **Venue accessibility profiles** — building/room accessibility, transit access, parking
- **Confirmation reminders** — with location details, sent 24h and 1h before event

**Values alignment:**
- **Care:** Removes barriers for people with disabilities and anxiety
- **Kindness:** Design for "the person having a hard day" — who needs extra information to participate safely
- **Inclusivity:** Accessibility data is universal design, benefits everyone

#### 1.3 Privately Tracking Personal Commitments

**User story:** As someone managing multiple roles (parent, worker, volunteer), I need to see my events on a calendar and get reminders so I don't over-commit or miss important gatherings.

**Stakeholder constraints:**
- May be on multiple communities' calendars
- May have different roles with different event responsibilities
- May need privacy from other community members about which events I attend
- May need reminders in my preferred channel (SMS, email, in-app)

**Improvement priorities (grounded in geography + calendar system):**
- **ICS calendar export** (already exists) — should include location, timezone, accessibility notes
- **Privacy on attendance** — I can see my events, but others only see "X people attending", not who
- **Role-based visibility** — if I'm hosting vs attending, I see different information
- **Conflict detection** — warn me if I've RSVP'd to overlapping events

**Values alignment:**
- **Care:** Prevents over-commitment and burnout
- **Autonomy:** Privacy controls let me manage my own information
- **Stewardship:** Not exploiting my attention for engagement metrics

---

## 2. Community Organizers (Elected Leaders)

**Who they are:** Elected representatives accountable to their communities. In CE terms: people in organizer roles who manage memberships, create events, allocate community resources, represent community at platform level.

**Why they matter to this system:** They are the bridge between member needs and platform capability. Their ability to create, locate, and manage events determines whether the platform enables their community's organizing work.

**Core values grounding:**
- **Solidarity** — Organizers stand with their communities; platform should distribute power, not concentrate it
- **Accountability** — Organizers are elected and answerable; they need tools to make decisions transparent and contestable
- **Stewardship** — Organizers hold community space in trust; tools should support long-term thinking
- **Reciprocity** — Organizers give time; platform should respect that and make their work easier, not harder

### User Stories & Needs

#### 2.1 Creating & Managing Community Events

**User story:** As a community organizer, I need to create events that locate members at our specific buildings or meeting spots, manage capacity, track who's coming, and handle location changes without losing people.

**Stakeholder constraints:**
- Limited technical skill; needs accessible UI without command-line or API learning
- May be managing events for a physical building they know well but platform doesn't yet know
- May need to change location at last minute (room unavailable, too many attendees, accessibility issue)
- Needs to track RSVPs for planning (food, chairs, facilitators)
- Needs privacy controls so internal planning isn't public

**Improvement priorities (grounded in geography system):**
- **Building/Room CRUD UI** — create "Community House, Main Hall" without needing developers
- **Event location change workflow** — update location, auto-notify RSVPs, keep history visible (transparency)
- **Capacity management** — set max capacity, waitlist support, occupancy tracking
- **Co-organizer support** — multiple people can edit same event; change logging (who changed what, when)
- **Template events** — weekly meetings at same place; fill in once, repeat easily

**Values alignment:**
- **Empowerment:** Self-service tools let organizers own their data, not ask developers
- **Accountability:** Change logging creates transparency; members can see why event moved
- **Stewardship:** Capacity tracking and room management help communities use resources sustainably

#### 2.2 Understanding Community Place & Resource Allocation

**User story:** As a community organizer, I need to see all the places (buildings, parks, meeting spots) my community uses, understand how often we use each space, and make decisions about where to invest or partner.

**Stakeholder constraints:**
- May not have a single "home building"; community uses multiple spaces
- May not know whether a location has historical significance or past problems
- May need to coordinate with other communities sharing same space
- May need to budget or justify space costs to members

**Improvement priorities (grounded in geography system):**
- **Community place inventory** — list all places we use with usage frequency and accessibility info
- **Place history & notes** — record: "We used this room until roof leak, moved to main hall in Jan 2025" (continuity)
- **Resource allocation view** — "We spend $X/month on 3 rooms; is that aligned with member priorities?"
- **Shared space coordination** — if multiple communities use same venue, visibility without friction

**Values alignment:**
- **Accountability:** Transparent resource allocation; members can see where money/space goes
- **Stewardship:** Long-term place understanding; not starting over each year
- **Cooperation:** Shared spaces can be managed with clear visibility and agreements

#### 2.3 Coordinating Events Across Geography (Regional/Network)

**User story:** As an organizer in a small settlement with limited events, I need to see events happening in nearby towns so I can help members travel together, or coordinate joint events with neighboring communities.

**Stakeholder constraints:**
- May be from small, isolated communities; nearest event might be 1–2 hours away
- May not know neighboring communities or settlement names
- May need to coordinate transport (van, carpool) for safety and access
- May want to co-host events with other communities (training, conferences, celebrations)

**Improvement priorities (grounded in geography system):**
- **Regional event discovery** — "Show me events in our region (Avalon Peninsula)" with distance info
- **Transport coordination** — "5 people from here attending event in St. John's; share rides?"
- **Settlement/region definitions** — make it clear what "region" means; let communities self-identify
- **Neighboring community view** — "Other organizers I should know about" (connection)

**Values alignment:**
- **Cooperation & Solidarity** — Helps small communities access opportunities and support each other
- **Connection** — Geography surfaces natural coordination opportunities
- **Resilience** — Distributed communities stronger together

#### 2.4 Safety & Capacity Planning

**User story:** As an organizer in a community with safety concerns (intimate-partner violence, harassment history, new-member vetting), I need to manage event access carefully while being transparent with members about safety expectations.

**Stakeholder constraints:**
- May need invite-only events or tiered access
- May need to document safety policies and have members agree (consent, not coercion)
- May need to handle accessibility & safety together (e.g., no dogs due to trauma, but support animals OK)
- May need support from platform moderators if safety issues arise

**Improvement priorities (grounded in geography system):**
- **Event privacy & access controls** — public vs community-only vs organizer-only events
- **Safety note on events** — "This is a trans-friendly space" or "Fragrance-free please" (visible, transparent)
- **Accessibility & safety combined** — can mark events as wheelchair-accessible AND fragrance-free AND trans-affirming
- **Venue history & context** — note if building has past safety issues or particular accessibility

**Values alignment:**
- **Care:** Explicit safety & accessibility planning prevents harm
- **Inclusivity:** Trans-affirming, fragrance-free, etc. are accessibility, not special requests
- **Accountability:** Transparent safety policies build trust; not hidden gatekeeping

---

## 3. Members with Accessibility Needs

**Who they are:** Community members with disabilities (physical, sensory, cognitive, developmental, invisible). Includes people managing chronic illness, neurodivergent members, elders, parents with small children.

**Why they matter to this system:** They are the canary in the coal mine. If events and places are not accessible to them, the platform fails on inclusivity — and accessibility practices usually benefit everyone else too (curb cuts example).

**Core values grounding:**
- **Inclusivity** — "Genuinely accessible to excluded communities"
- **Care** — Heightened attention to members whose barriers are not obvious
- **Kindness** — Design for "the person having a hard day"
- **Love** — Everyone deserves to participate with dignity

### User Stories & Needs

#### 3.1 Finding Accessible Events

**User story:** As a wheelchair user, I need to know whether a venue has ramps, accessible washrooms, and accessible parking BEFORE I RSVP, so I don't waste energy preparing to attend only to find I can't get in.

**Stakeholder constraints:**
- Inaccessible building info requires mental energy to find and verify
- May have limited spoons (energy); asking the organizer takes effort
- May face gatekeeping ("Are you *really* coming?" challenge when asking about accessibility)
- May need to plan route, find para-transit, arrange care — all upstream of learning venue is inaccessible

**Improvement priorities (grounded in geography system):**
- **Venue accessibility data (first-class)** — ramps, accessible washroom, accessible parking, door width, elevator, etc.
- **Self-reported & verified** — organizers input what they know; external audit/verification badges build trust
- **Change notification** — if venue accessibility changes, notify people who marked it as accessible
- **Outdoor/distance accessibility** — "5 km from nearest parking" affects people on scooters/walkers
- **Sensory accessibility** — lighting, noise level, fragrance policies, service-animal-friendly

**Values alignment:**
- **Inclusivity:** First-class accessibility data removes gatekeeping
- **Accountability:** Verified vs self-reported badges show transparency
- **Care:** Prevents the harm of wasted energy and broken promises

#### 3.2 Navigating to & Within Venues

**User story:** As a deaf person, I need to know whether events will have ASL interpreters or captions, and for in-person events, where the interpreter will be positioned so I can see both the interpreter and the content.

**Stakeholder constraints:**
- Needs advance notice so interpreters can be booked
- May need captions (live or video-recorded) for asynchronous access
- May need to know positioning ahead of time (not arrive and find interpreter hidden behind speaker)
- May face extra logistics (interpreter travel, cost sharing with organizer)

**Improvement priorities (grounded in geography system):**
- **Access service booking on events** — "Request ASL interpreter", "Request captions", "Request Braille program"
- **Venue access map** — "Interpreter will be in corner near main entrance" with photo/diagram
- **Building detail: accessibility features** — "Has gender-neutral accessible washroom on 2nd floor, accessible entrance via west door"
- **Service-animal explicit welcoming** — clear statement "Service animals welcome; no questions asked"

**Values alignment:**
- **Inclusivity:** Access services are not special requests; they're how people participate
- **Accountability:** Transparency on what access will be provided; organizers make commitments
- **Respect:** Asking in advance respects both people's dignity and organizers' planning needs

#### 3.3 Neurodivergent Event Navigation

**User story:** As an autistic person with sensory sensitivities and social anxiety, I need to know event structure (schedule, noise level, whether I can stim freely, whether it's drop-in or requires interaction) so I can decide whether I can attend.

**Stakeholder constraints:**
- Changes or unclear expectations cause high anxiety
- Sensory environment (noise, light, smell, texture) directly affects ability to participate
- May need to leave early or take breaks; needs permission to do so without social pressure
- May communicate differently (text, written notes, silence); needs acceptance

**Improvement priorities (grounded in geography system):**
- **Event structure & neurodivergent info** — detailed schedule, noise level (quiet/moderate/loud), sensory note, break policy
- **Venue sensory profile** — fluorescent vs natural lighting, hard vs soft surfaces (acoustics), fragrance policy
- **Optional social expectations** — "This is a talking circle; participation is fully optional; no one will pressure you"
- **Accessibility of async participation** — can I watch video later if I can't attend live? Can I participate via text?

**Values alignment:**
- **Kindness:** Explicit structure removes anxiety; neurodivergent people can trust what they're told
- **Inclusivity:** Neurodivergent communication styles are valid; not something to overcome
- **Hope:** Accessible events make collective action possible for more people

---

## 4. Historians & Accountability Stewards

**Who they are:** Community members responsible for memory, continuity, and historical record. Includes designated historians, elders, long-term members, people building organizational archives.

**Why they matter to this system:** They carry institutional memory and accountability. Their ability to link past events/places to present decisions determines whether communities learn from their history or repeat mistakes.

**Core values grounding:**
- **Stewardship** — Long-term thinking; not starting over each year
- **Accountability** — Transparent decisions grounded in what's been tried before
- **Care** — Respect for community knowledge and experience
- **Solidarity** — Community history belongs to the community, not to platforms

### User Stories & Needs

#### 4.1 Recording Community Event & Place History

**User story:** As a community historian, I need to record why certain events matter, when locations changed, and what happened that shapes current practices so future members can understand our continuity.

**Stakeholder constraints:**
- Historical info is often in elders' memories, not documents
- Need to record "Why did we stop using the old hall?" or "This is where the movement started"
- Records must be editable by multiple historians; not siloed with one person
- Need to link events across years (annual event; built continuity)

**Improvement priorities (grounded in geography system):**
- **Event/place historical notes** — "Moved from old hall (2023) due to roof damage; switched to community center"
- **Timeline view** — show how a place or event series has evolved; not just current state
- **Linked histories** — "This annual gathering has happened in these locations over 15 years"
- **Collective stewardship of memory** — multiple historians can add to records; voting/consensus on shared narrative

**Values alignment:**
- **Stewardship:** Community knowledge encoded in system, not lost when elders leave
- **Accountability:** "Why" is documented; future decisions grounded in learning
- **Reciprocity:** Platform stores community history; platform is servant of community knowledge

#### 4.2 Understanding Built Environment Changes

**User story:** As someone documenting community resource allocation and change, I need to understand: Which buildings do we own? Which do we rent? How have our spaces evolved? What does our "home" mean over time?

**Stakeholder constraints:**
- May involve deed research, partnership agreements, historical photos
- May be politically sensitive (gentrification, displacement, reclaimed spaces)
- Need to distinguish "we own this" vs "we use this" vs "we lost this"
- Need archival photo/document storage linked to places

**Improvement priorities (grounded in geography system):**
- **Building ownership/partnership status** — own, rent, partner arrangement; terms & dates
- **Building historical photos** — exterior, key rooms; archive over time
- **Place significance markers** — "Where we held our first gathering", "Site of police incident"
- **Gentrification/displacement tracking** — "This was our space 2000–2015; no longer accessible due to rent increase"

**Values alignment:**
- **Care:** Honors community struggle and history
- **Stewardship:** Document shows long-term pattern; informs future resource strategy
- **Solidarity:** Displaced spaces are still part of our history; not erased

---

## 5. Developers & Maintainers

**Who they are:** Technical team building and maintaining CE and integrated systems (n8n, Borgberry, local AI). In BTS context: people working to make the technology transparent, modular, and extensible.

**Why they matter to this system:** They translate design intent into code. Their ability to understand, implement, and test the system determines whether it actually embodies BTS values or only claims to.

**Core values grounding:**
- **Curiosity** — Keep asking if this actually serves people; code should reflect that
- **Stewardship** — Long-term maintainability; not technical debt
- **Cooperation** — Humans and bots working together; code should be understandable by humans
- **Accountability** — Code is not neutral; it enforces values or enables them

### User Stories & Needs

#### 5.1 Clear, Stable Contracts

**User story:** As a developer maintaining CE, I need clear contracts for geography/location/event/calendar models so I can confidently add features without breaking existing code or creating bugs.

**Stakeholder constraints:**
- Currently: Space is float-based, breaking PostGIS proximity (gap #1 in assessment)
- Currently: Event geocoding commented out; dead code referencing non-existent associations
- Currently: 13 open GitHub issues for v0.12.0 with no implementation started
- Need: Clear responsibility boundaries (whose job is it to store geometry vs floats?)

**Improvement priorities (grounded in assessment findings):**
- **Define Space/Geography contracts** — is Space float-only or geometry-enabled? Decide; communicate; test
- **Remove dead Event code** — clean up commented geocoding; make event location flows explicit
- **API contracts** — what does EventResource expose? What filters work? Document & test
- **Schema migrations** — clear deprecation/migration path for coordinate storage changes

**Values alignment:**
- **Accountability:** Contracts are visible; developers can verify they're building right thing
- **Stewardship:** Clear contracts prevent technical debt from snowballing
- **Cooperation:** Well-documented code is how developers cooperate across time

#### 5.2 Testability & Verification

**User story:** As a developer, I need the geography/location/event system to be thoroughly tested so I can refactor or add features without breaking things and trust that changes actually work.

**Stakeholder constraints:**
- Currently: No spatial index tests (GiST indexes exist but are untested for PostGIS)
- Currently: EventResource has zero location-related tests
- Currently: No proximity-search tests (feature doesn't exist, but when it's built, how do we prevent regression?)
- Need: Test-first discipline across the system

**Improvement priorities (grounded in assessment findings):**
- **Model specs** — Space geometry, Address geocoding, Event location, Building association
- **Request specs** — EventResource location attributes, geographic filters, proximity search
- **System specs** — organizer creates event at building; member finds event by proximity; timezone correct
- **Regression specs** — as v0.12.0 adds features, write tests that prevent re-breaking old features

**Values alignment:**
- **Accountability:** Tests verify behavior matches intent; test failures surface value conflicts
- **Care:** Tests prevent shipping broken features that affect members
- **Stewardship:** Test suite is community resource; future developers depend on it

#### 5.3 Extensibility & Local Customization

**User story:** As a developer in a different Newfoundland/Labrador community deploying CE locally, I need to customize event and geography data to match our community context without forking the codebase.

**Stakeholder constraints:**
- May need different geography hierarchy (e.g., Dene communities use different place-naming)
- May need different timezone behavior (NL is unique; other regions different)
- May need different event accessibility standards (desert community needs water/shade; coastal needs warmth)
- Need: hooks, override points, configuration that don't require custom code

**Improvement priorities (grounded in cooperative values):**
- **Customizable geography labels** — "We call these areas X, not Y; use our names" (localization, not translation)
- **Event accessibility templates** — communities define what "accessible" means for them (e.g., Dene communities' accessibility norms)
- **Timezone configuration** — configure which timezones appear in picker, which is default
- **Plugin architecture** — custom geography models can coexist with core

**Values alignment:**
- **Autonomy:** Communities control their own data and terminology
- **Inclusivity:** Different communities have different needs; platform adapts
- **Reciprocity:** Custom implementations contribute back improvements that benefit all

---

## 6. Platform Organizers & Governance

**Who they are:** Elected representatives accountable to platform members and communities. Responsible for cross-community policies, safety decisions, platform-wide resource allocation, representing CE in larger movement.

**Why they matter to this system:** They hold the platform in trust for communities. Their ability to understand, govern, and make decisions about events/geography determines whether the platform serves its cooperative mission or concentrates power.

**Core values grounding:**
- **Accountability** — Decisions are visible, logged, appealable
- **Democratic Control** — Stakeholders have say in platform governance
- **Solidarity** — Policies protect marginalized communities first
- **Stewardship** — Preserve platform health for long term

### User Stories & Needs

#### 6.1 Cross-Community Coordination & Conflict Resolution

**User story:** As a platform organizer, I need to understand when events/places create conflicts (competing for same venue, timing conflicts that affect members, accessibility disputes) so I can help communities resolve them with transparency.

**Stakeholder constraints:**
- May need to see all events across all communities to spot patterns
- May need audit logs: "Who booked this venue? When? What was the agreement?"
- May face conflicts between communities' values (one wants fragrance-free; another has scent-dependent member)
- Need to make decisions visible so all can understand reasoning

**Improvement priorities (grounded in geography system):**
- **Cross-community event view** — timeline of events at shared venues; spot conflicts early
- **Venue booking/agreement logs** — who booked it, dates, terms, any issues
- **Policy decision records** — "We decided to prioritize X community access to Hall on Tuesdays because Y"
- **Appeal/escalation tracking** — clear record if conflict happens

**Values alignment:**
- **Accountability:** Decisions visible; not made in backchannels
- **Cooperation:** Conflicts resolved with community input, not top-down
- **Stewardship:** Cross-community patterns inform platform-level improvements

#### 6.2 Safety Policy & Incident Response

**User story:** As a platform organizer, I need to ensure that events and venues maintain safety standards (against harassment, discrimination, violence) while respecting community autonomy to define safety on their terms.

**Stakeholder constraints:**
- Communities may define safety differently (one prioritizes trans safety; another prioritizes sexual-assault survivors)
- Need to intervene if venue/event becomes unsafe; but respect community decision-making first
- Need clear escalation path: community handles internally → platform supports → platform intervenes
- Need audit trail to prevent cover-ups or retroactive "we didn't know"

**Improvement priorities (grounded in geography system):**
- **Venue safety incident logging** — "Reports of harassment in building X; community Y reported to platform"
- **Event safety flags** — visible tracking if event has had safety incidents; community context visible
- **Policy appeals** — if community disagrees with platform's safety decision, clear appeal process
- **Transparency on platform actions** — "We paused booking at venue X because of [reason]; here's what community is doing"

**Values alignment:**
- **Care:** Safety prioritized; decisions center on affected members
- **Solidarity:** Marginalized communities' safety reports taken seriously
- **Accountability:** Visible incident logs prevent institutional gaslighting

#### 6.3 Resource Allocation & Equity

**User story:** As a platform organizer, I need to understand whether events and spaces are accessible to all communities or concentrated among some, so I can identify equity gaps and guide platform investment.

**Stakeholder constraints:**
- May see patterns: rural/small communities have fewer events; no events in certain times/languages
- May see accessibility disparities: some venues accessible; others not
- May need to track whether platform resources (developer time, infrastructure) are distributed equitably
- Need data without violating member privacy

**Improvement priorities (grounded in geography system):**
- **Platform-level event metrics** — events per community/region, attendees per event, accessibility % (aggregated, privacy-safe)
- **Equity gap analysis** — "Settlement X has 10 events/month; Settlement Y has 1 event/month" (flags for help)
- **Accessibility inventory** — "How many of our venues are wheelchair-accessible?" (aggregate; not identifying)
- **Underserved community alerts** — "No recent events in this region; is there community interest?"

**Values alignment:**
- **Care:** Visible inequity can be addressed; hidden inequity perpetuates
- **Solidarity:** Data centers marginalized communities' experiences
- **Stewardship:** Equity monitoring is long-term system health

---

## 7. Newcomers & Immigrant Communities

**Who they are:** People new to NL, immigrant communities, Indigenous peoples connecting to CE through movement partners. Often face barriers: language, unfamiliar geography, cultural differences, economic constraints.

**Why they matter to this system:** They are explicitly in BTS's scope ("platform serves newcomers to Newfoundland and Labrador"). Their ability to access events and find safe communities determines whether the platform fulfills its mandate or excludes those most in need.

**Core values grounding:**
- **Inclusivity** — "Genuinely accessible to excluded communities" (newcomers are excluded by default)
- **Love** — Platform should welcome, not require proof of belonging
- **Care** — Heightened attention to linguistic, cultural, economic barriers
- **Hope** — Technology can lower barriers to belonging, not raise them

### User Stories & Needs

#### 7.1 Geographic Orientation & Localization

**User story:** As a newcomer from outside Canada, I don't know what "Avalon Peninsula" or "Bay Roberts" means. I need events described in ways I can understand my location relative to them.

**Stakeholder constraints:**
- May not know provincial/regional geography; only know own neighborhood or "St. John's area"
- May use metric distances; might not know miles
- May speak English as additional language; benefit from simple descriptions
- May use different place-naming conventions (home country, lived previous places)

**Improvement priorities (grounded in geography system):**
- **Hierarchical, searchable geography** — fine-grained: "Newfoundland > Eastern Avalon Peninsula > St. John's > Downtown > [street]" with simple descriptions
- **Distance in multiple units** — "5 km away" and "3 miles away" and "15-minute bus ride"
- **Landmarks & descriptions** — "Near bus station", "Downtown St. John's", "Beach area" (not just coordinate)
- **Multilingual geography** — settlement names with translations/explanations for non-English speakers

**Values alignment:**
- **Inclusivity:** Removes barriers that only English-literate locals can navigate
- **Kindness:** Simple descriptions welcome newcomers; not gatekeeping behind local knowledge
- **Discovery:** Geographic clarity is the first step to community discovery

#### 7.2 Culturally-Appropriate Event Information

**User story:** As a refugee or immigrant, I want to know whether an event is culturally safe for me and my family, and whether I'll be welcomed or treated as "other".

**Stakeholder constraints:**
- May not know which communities are welcoming to immigrants/refugees/people of color
- May have experienced discrimination; anxious about new spaces
- May have family who speak different language; need info on child safety, babysitting help
- May have dietary, religious, or cultural needs that need accommodation

**Improvement priorities (grounded in geography system):**
- **Community welcome markers** — "This community is LGBTQ2S+-welcoming", "Immigrant-led", "Refugees welcome" (community self-describes)
- **Event cultural accessibility** — "Halal/Kosher food provided", "Childcare included", "Multiple languages spoken"
- **Safe space indicators** — ratings/reviews from people in marginalized groups (not generic star ratings)
- **Accessibility beyond disability** — "This community uses land-back practices; gathering on Indigenous land"

**Values alignment:**
- **Care:** Explicit welcome removes anxiety; member can assess safety before committing
- **Inclusivity:** Cultural accessibility is as important as physical accessibility
- **Love:** Platform actively invites marginalized people; not just inclusive in theory

#### 7.3 Language & Literacy Access

**User story:** As a newcomer with Limited English Proficiency, I need events, places, and community information available in my language so I can fully participate, not rely on community members to translate for me.

**Stakeholder constraints:**
- May speak English but prefer other language for comfort
- May have low literacy in all languages; need visual/verbal alternatives to text
- May have family speaking different language; need multi-language household support
- May not have resources to pay for translation; need community translations

**Improvement priorities (grounded in geography system):**
- **Platform i18n** — events & geography accessible in Spanish, French, Arabic, Chinese (common in NL communities)
- **Crowdsourced translation** — community members can translate event descriptions; not relying on paid services
- **Audio & visual descriptions** — venue photos, video walkthroughs of buildings (not text-only)
- **Plain-language event info** — simple descriptions, not jargon ("3rd floor, south wing" vs visual map)

**Values alignment:**
- **Generosity:** Community members translating is reciprocal help; not a burden
- **Inclusivity:** Language is not gatekeeper; everyone can access
- **Hope:** Language access enables newcomers to fully participate in collective action

---

## 8. Movement Partners & Larger Ecosystem

**Who they are:** Organizations, collectives, and communities working with BTS on shared goals (settlement services, Indigenous sovereignty, queer liberation, housing justice, climate, etc.).

**Why they matter to this system:** They provide context and accountability. CE's geography/events system should serve movement work, not compete with or duplicate other tools.

**Core values grounding:**
- **Cooperation among cooperatives** — ICA Principle 6; CE cooperates with other organizations
- **Solidarity** — Movement partners are allies, not competitors
- **Reciprocity** — CE serves movement; movement shapes CE
- **Autonomy** — Orgs remain independent; CE is a tool, not a parent

### User Stories & Needs

#### 8.1 Federated Organizing & Inter-Community Events

**User story:** As an organizer in a multi-community movement, I need to create events that bring together members across several communities (cross-community training, conferences, celebrations) and track participation by community/role.

**Stakeholder constraints:**
- Event involves people from 3+ communities; each community manages their own RSVP
- Need visibility: "Community A has 8 confirmed, Community B has 3, need to reach out to C"
- Need to handle different time zones across communities
- Need to coordinate post-event (sharing notes, next steps) across communities

**Improvement priorities (grounded on geography system):**
- **Multi-location events** — event in one place but communities travel from different locations; show distances
- **Federation support** — clearly show which community each RSVP is from; cross-community summary
- **Timezone handling** — confirm time is same across time zones (e.g., NL is 30 min behind rest of Atlantic)
- **Post-event coordination** — shared notes/decisions; linked followup events

**Values alignment:**
- **Cooperation:** Federation mechanism enables cross-community work
- **Solidarity:** Geography/timing visibility strengthens coalition-building
- **Autonomy:** Each community remains independent; federation is voluntary

#### 8.2 Resource Sharing & Equipment Booking

**User story:** As a movement partner with a shared van or equipment library, I need to track when items are booked for events, coordinate sharing across communities, and prevent double-booking.

**Stakeholder constraints:**
- Equipment (van, projector, sound system) is shared resource; multiple communities depend on it
- Booking needs to link to events; people plan transport around equipment availability
- May need insurance/liability info when equipment is booked for specific events
- May need maintenance tracking; record damage or maintenance needs

**Improvement priorities (grounded in geography system):**
- **Equipment availability view** — "Van is booked for Community A's event on Saturday 2-4pm; next available Monday"
- **Equipment + event linking** — "Our event on June 15 needs van; check if available; book in same system"
- **Insurance & liability** — "This equipment requires $X liability insurance; certify when booking"
- **Maintenance history** — "Equipment was damaged at event in May; fixed; available again"

**Values alignment:**
- **Reciprocity:** Shared resources are how movements amplify capacity
- **Accountability:** Booking logs prevent disputes; clear who is responsible
- **Stewardship:** Shared equipment managed collectively; not hoarded by one community

---

## Summary: Stakeholder-Grounded Improvement Framework

### The Unified Principle

All stakeholders, from individual members to movement partners, have **legitimate and complementary needs** rooted in BTS foundational values. The events/geography system should:

1. **Serve members first** — discover events, understand places, participate safely
2. **Empower organizers** — create/manage events/places, coordinate locally, preserve continuity
3. **Support accessibility** — proactive, first-class accessibility; not afterthought
4. **Honor history** — record why, not just what; continuity over time
5. **Enable developers** — clear contracts, testable code, transparent values in architecture
6. **Inform governance** — visible data for equitable decisions
7. **Welcome newcomers** — multiple languages, clear orientation, cultural respect
8. **Strengthen movements** — federation, resource-sharing, alignment with partners

### Values-Grounded Prioritization

Use BTS Four Pre-Action Tests to prioritize improvements:

1. **Love/Inclusivity** — Does this respect humanity & agency? Could it exclude someone?
2. **Cooperation/Solidarity** — Does this distribute power or concentrate it?
3. **Accountability/Stewardship** — Is this auditable, reversible, explained?
4. **Care/Resilience** — Could this harm vulnerable members?

Any improvement that fails a test should be redesigned or deferred until alignment is achieved.

### Critical Path for v0.12.0

The 13 open issues (#1424–#1436) can be organized by stakeholder impact:

**High impact (affects many stakeholders, enables others):**
- #1427 — Audit/normalize geography models (affects all)
- #1428 — Complete geography views/forms/APIs (affects members, organizers, developers)
- #1435 — Define spacetime API contract (affects members, movement partners, devs)

**Specialized impact (critical for specific stakeholders):**
- #1431 — Timezone + geography (affects members, organizers, newcomers)
- #1432 — Infrastructure UI (affects organizers, members, historians)
- #1433 — Built-environment history (affects historians, organizers, accountability stewards)

**Foundation & governance:**
- #1436 — Stakeholder docs & diagrams (affects all)
- #1430 — Temporal cohesion (affects organizers, members, developers)

### Stakeholder Engagement for Implementation

Before building v0.12.0, engage stakeholders:
1. **Members** — user testing for event discovery & accessibility
2. **Organizers** — co-design for event/place management UI
3. **Accessibility advocates** — review accessibility standards & metadata
4. **Historians** — document what "continuity" means for different communities
5. **Developers** — define contracts & testing standards
6. **Governance** — understand cross-community impact & equity considerations
7. **Movement partners** — federation/resource-sharing needs
8. **Newcomer orgs** — language/cultural accessibility

This engagement is not "feature requests"; it's **accountability to the people the system serves**. It's how CE embodies "humans decide; AI advises."

---

## References & Grounding

- BTS Values Charter: `/bts-cloud/n8n/management-tool/docs/bts-values-charter.md`
- CE Values & Governance Map: `/bts-cloud/n8n/management-tool/docs/community-engine-in-universe-0.md`
- CE Stakeholder Documentation Structure: `/community-engine-rails/docs/stakeholder_documentation_structure.md`
- v0.12.0 Epic: GitHub issue #1424 (CE repo)
- Geography System Assessment: `geography_location_system_assessment.md` (this project, companion doc)
- ICA Cooperative Principles: https://www.ica.coop/en/cooperatives/cooperative-identity

---

**Next Steps:**
1. Validate this stakeholder map with actual representatives from each group
2. Prioritize v0.12.0 sub-issues using stakeholder impact
3. Engage stakeholders in co-design of improvements
4. Update this doc as new stakeholder needs emerge
5. Link v0.12.0 acceptance criteria to stakeholder stories

This framework ensures that improvements serve the people, not the platform; and that values stay visible in architecture, not just documents.
