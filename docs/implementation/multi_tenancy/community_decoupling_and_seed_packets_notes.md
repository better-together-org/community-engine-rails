# Community decoupling, seed packets and per platform access control: notes for later

Status: assessed, not started. Nothing in this note is implemented. Written 2026-11-12 on `feature/multi-tenancy-v2` (draft PR #2165) so the work can be reviewed and resumed later. The full working plan lives outside the repo; this note carries everything needed to restart.

## Facts

- Production has one host platform and no account that spans platforms. There is no multi platform data to split.
- Other platform rows exist but are external (OAuth providers, federation). Any backfill must use the platform marked `host: true`, never "the only platform" and never `Platform.first`.
- 77 of the 106 tables with a `platform_id` allow it to be empty. Many were left nullable only because the host platform did not exist yet when the first rows were created.
- Roles, permissions and their assignments are global in practice. Identifiers are unique across the install, lookups are global (about 16 places in the app, about 260 in specs).
- The builders for default data (access control, navigation and pages, agreements, categories, wizards) are about 3,400 lines that find or create records globally. Their "clear" option deletes every platform's data.
- The Seed model (YAML envelope, safe loader, allowed folder `config/seeds`) and SeedPlanting already exist and are used for a wizard definition and a geography catalog.

## Decisions made

1. Roles, permissions and their assignments are copied per platform. A platform may differ from every other platform.
2. Seed packets are built on the existing Seed and SeedPlanting models.
3. Replant adds new items only and never touches a record a platform has edited.
4. A platform's `community_id` becomes optional. The primary community behaviour is removed from Platform. OAuth providers and federated platforms get no community.
5. The `host` column and concern are removed from communities. The host community is the community the host platform points to.
6. The host platform is created first in the seed, and its community is created afterward.
7. Person communities and the other auto-created communities (geography, infrastructure) are to be removed.

## Open questions

- Should a community created on purpose still get a default calendar and contact detail automatically? Left as is for now.
- Should the building to floor to room ("Main") auto-creation chain also go? Left alone for now.
- Community roles across platforms (a person on one platform joining a community of another) need a rule before the access control step.
- What counts as an "edit" for packet fingerprints on translated and rich text content.
- Whether the communities API exposes `host`, the default calendar or the community map. Not checked.
- Whether, in production, the host community equals the one the host platform points to. Not checked.
- How the test database cleaner treats seeded rows, how the role admin screens are built, and whether production role and permission rows differ from the builders' defaults. Not checked.

## Findings: what is auto-created today

- Ten kinds of record create a community of their own on first validation, copying name and description: platform, person, continent, country, region, state, settlement, building, floor, room.
- Every community then creates a contact detail (before validation) and a default calendar named `default-<identifier>` (after create), and a map (after create and update, through `Mappable`).
- Person communities are marked protected, with the person set as creator after create. Platform communities are marked host and protected and carry bootstrap flags.
- Buildings create a floor, and floors create a room named "Main". Geography records create a map through their location concerns. Platforms create their primary domain after commit (intended).
- Nothing in the code reads the community of a geography or infrastructure record, and nothing reads a person's primary community except the personal calendar below.

## Findings: how those records are used

Calendars
- `Community has_one :default_calendar` is declared (`community.rb:73`) and never called. Nothing finds or uses a community's default calendar.
- Policies read calendars by `community_id`: `scoped_calendar_ids` in `application_policy.rb` and `CalendarPolicy#same_community?` (`calendar_policy.rb:43`, compares the agent's `community_id` with the calendar's). `PersonHardDeletionExecutor` unlocks calendars by creator and owned communities.
- The personal calendar is the one live dependency. `Person#primary_calendar` (identifier `<identifier>-personal-calendar`, created on demand with `community: person.community`) is used by `EventAttendance` (`event_attendance.rb:53,64,69`) and by `Person#all_calendar_events` and the profile calendar section. Removing person communities means this calendar must belong to the person, the policy check must change, and existing personal calendars need a data move.

Contact details
- Real UI for Community and Person: edit tabs, show pages (guarded by `has_contact_details?`), and `PersonDeletionAnonymizer`.
- The host community's contact details are rendered by a navigation block template (`_host_community_contact_details.html.erb`, built in `navigation_builder.rb:271`). It must keep working: read it from the host platform's community.
- Empty auto-created contact details are invisible because the views hide a contact detail with no entries.
- Buildings, floors and rooms include `Contactable` themselves and also get one through their community, so they get two.

Maps
- Communities include `Mappable`, so each gets a map. It is shown only when the record has a space or location (community page `communities/show.html.erb:56,223`; event page `@event.map`). A community without a location has an empty map nothing displays.
- Geography and infrastructure records geocode through their own location concerns, so removing their communities does not remove their maps.

## Planned work, grouped by outcome (each step ends with tests, PR review and sign off)

A. Host platform first, with an optional community
- Platform `community_id` optional; Platform stops auto creating a community and declares its own name and description translations.
- Community created explicitly after the platform (seed for host, provisioning for tenants). A validation requires a community unless the platform is external. Unique index on the platform's community id.
- Remove `communities.host`, its concern, unique index and class cache. Host community = the host platform's community.
- Delete the bootstrap exceptions: "no platform exists yet" allowance, bootstrap flags on community, contact detail and calendar, the `update_column` backfill, the pre-destroy nulling. Those tables can then require a platform.
- Platform destruction becomes an explicit service.
- Seed order: platform, access control, host community, remaining packets. Remove code that quietly picks the first platform. Deploy order: migrate, then seed.
- Test suite: one shared host platform per worker; review specs that assume no platform, about 250 spec files that mention a host community, and database cleaner behaviour.

B. Seed packets
- Versioned declarative files on the Seed and SeedPlanting models; records refer to others by identifier, resolved against the target platform.
- Planters per record kind, keyed by platform and identifier. Provenance (packet, version, fingerprint) stored on planted records.
- Replant adds new records only and reports differences. Unplant removes only unedited planted records. Each run recorded as a SeedPlanting. Packets ship in the engine; host apps can add their own.
- Plant order: access control, navigation and pages, agreements and categories, wizards, optional demo content. Old builders become wrappers, then are removed.

C. Roles, permissions and assignments per platform
- Platform required on all three; identifiers and positions unique within a platform. A membership's role must belong to the same platform (code plus composite foreign key).
- Valid permission names stay in code. Default roles and permissions become the first packet. Scoped lookups replace global ones; role admin screens scoped to the current platform. Backfill existing rows to the host platform. About 260 spec lookups move to a helper.

D. Platform ids become required
- Reclassify tables (platform configuration, per platform security and identity, tenant content, global). Make required in that order, security and identity first. Backfill to the host platform, raise if any remain. Global data keeps optional with a recorded reason. A spec fails when an optional platform column lacks a manifest reason.

E. Remove auto-created communities
- Remove the primary community concern from all ten kinds and make their `community_id` optional.
- Move the personal calendar to the person; change `CalendarPolicy#same_community?` and the calendar scoping accordingly; keep the host community contact block working.
- Cleanup of existing data is a separate reviewed step: dry run report (counts by owner type; any community with members, posts, events, pages, other content or a non auto-created creator), database snapshot, then delete only unused auto-created communities with their contact details, default calendars and maps. Anything with content is listed for a decision.
- Drop the `community_id` columns later, once nothing refers to them.
- Specs and factories that rely on `person.community` or geography communities move to explicit setup.

Order: 1) A plus E (stop creating communities), 2) packet framework with one small packet, 3) access control as a packet and per platform roles, 4) remaining packets and provisioning, 5) required platform ids, 6) remove old builders and the global clear.

## Risks

- Step 1 changes how every platform and community is created and destroyed and removes a column touched in about 80 places in the app and 250 spec files. Rehearse on a copy of production first.
- Take counts of communities per owner type and a database snapshot before any cleanup migration.
- Moving about 260 spec lookups is mechanical but large.

## Related

- Draft PR #2165 (phases 0 and 1 of tenancy); review notes in `phase_0_1_review_notes.md`.
