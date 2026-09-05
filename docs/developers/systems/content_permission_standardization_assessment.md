# Content Permission Standardization Assessment

This document audits all inconsistencies in the current post, event, page, and community authorization model and proposes a standardized design. It is a decision document — no code has been changed. Implementation should happen once the proposed model is approved.

---

## 1. Current State: Full Role-Permission Matrix

### Community roles (from `access_control_builder.rb`)

| Permission | member | contributor | facilitator | content\_curator | strategist | legal\_advisor | governance\_council | organizer | coordinator |
|-----------|:------:|:-----------:|:-----------:|:----------------:|:----------:|:--------------:|:-------------------:|:---------:|:-----------:|
| `read_community` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `list_community` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `create_community` | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `update_community` | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `delete_community` | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `invite_community_members` | | | ✓ | | | | ✓ | ✓ | ✓ |
| `manage_community_members` | | | | | | | ✓ | ✓ | ✓ |
| `manage_community_settings` | | | | | | ✓ | | ✓ | ✓ |
| `manage_community_content` | | | | ✓ | | | | ✓ | ✓ |
| `manage_community_roles` | | | | | ✓ | | ✓ | ✓ | ✓ |
| `manage_community_notifications` | | | | | | | | ✓ | ✓ |

### Content creation rights derived from current roles

| Who | Create post | Create page | See "Create Event" button | Create event (policy) |
|-----|:-----------:|:-----------:|:-------------------------:|:---------------------:|
| `community_member` | ✗ | ✗ | ✗ | ✓ via direct URL |
| `community_contributor` | ✗ | ✗ | ✗ | ✓ via direct URL |
| `community_facilitator` | ✗ | ✗ | ✓ (has `update_community`) | ✓ |
| `community_content_curator` | ✓ | ✗ | ✗ | ✓ via direct URL |
| `community_strategist` | ✗ | ✗ | ✗ | ✓ via direct URL |
| `community_legal_advisor` | ✗ | ✗ | ✗ | ✓ via direct URL |
| `community_governance_council` | ✗ | ✗ | ✗ | ✓ via direct URL |
| `community_organizer` | ✓ | ✗ | ✓ | ✓ |
| `community_coordinator` | ✓ | ✗ | ✓ | ✓ |
| Platform steward / manager | ✓ | ✓ | ✓ | ✓ |

---

## 2. Identified Inconsistencies and Design Defects

### D1 — `create_community` is granted to nearly all community roles

Every role above `community_member` carries `create_community`. This means any contributor, facilitator, strategist, legal advisor, governance council member, etc. can create new communities on the platform. This is almost certainly unintentional — creating a new community is a platform-level act, not a consequence of membership in another community.

**Impact:** Community members with any elevated role can create new communities without platform steward involvement.

---

### D2 — `delete_community` is granted to roles far below organizer

`community_facilitator`, `community_content_curator`, `community_strategist`, `community_legal_advisor`, and `community_governance_council` all carry `delete_community`. A content curator can delete the community they manage content for.

**Impact:** Operational risk. Roles scoped to content or governance can destroy the community itself.

---

### D3 — `community_organizer` and `community_coordinator` are identical

Both roles carry exactly the same set of permissions. There is no functional distinction between them.

**Impact:** Role catalog confusion. Admins cannot make an informed choice between the two.

---

### D4 — Pages cannot be created by community-level roles

`PagePolicy#create?` only passes for `platform_content_manager?` (requires `manage_platform_settings` or `manage_platform`). Community organizers, coordinators, and content curators — who can create posts — cannot create pages even for their own community.

**Impact:** Asymmetry in what "content manager" means. A community organizer can publish a post but not a page, even though both are content.

---

### D5 — Event creation UI misrepresents actual policy

- The "Create Event" button in the community tab is gated on `CommunityPolicy#create_events?`, which requires `update?` (i.e., `update_community`).
- `community_facilitator` has `update_community` → **sees the button**.
- `community_content_curator` has `update_community` → also **sees the button**.
- `community_strategist` has `update_community` → also **sees the button**.
- But `EventPolicy#create?` checks `platform_event_manager? || event_host_member?` — any active community member qualifies as a host.

The button visibility (`update_community`) and the actual creation gate (`event_host_member?`) are entirely unrelated checks. Members without `update_community` can create events via direct URL but are given no UI affordance to do so.

**Impact:** Members with a legitimate need to create events (facilitators whose express purpose is running events) have no discoverable creation path unless they also happen to have `update_community`.

---

### D6 — `community_facilitator` can see the event button but not create posts or pages

A facilitator's stated purpose is to facilitate community activity. Yet:
- They have `update_community` (structural change permission) → UI shows Create Event button ✓
- They have no `manage_community_content` → cannot create posts or pages ✗
- They can create events (via `event_host_member?`) → but only if someone tells them the URL ✗

The role grants structural authority over the community but no content creation authority.

---

### D7 — No `manage_community_events` permission exists

Events inside a community use `event_host_member?` (computed from `valid_event_host_ids`) rather than a permission check. There is no way to say "this person can manage events in this community" as a role-based grant. The event hosting model is based on identity (are you a member?) rather than authorization (have you been granted event management?).

**Impact:** Cannot express "this person is the events coordinator for this community" through the role system. Cannot remove event creation access without removing community membership entirely.

---

### D8 — Posts auto-assign to `host_community`; pages do not

`PostsController#community_context` falls back to `host_community` when no `community_id` is provided. `PagesController` has no equivalent. A platform manager creating a page on the platform homepage has no community to associate it with by default, but a post would be silently assigned to the host community.

**Impact:** Inconsistent behavior between content types. Pages created on the platform have no community; posts always have one.

---

### D9 — `community_contributor` role has no meaningful community-level function

`community_contributor` has `read_community`, `list_community`, and `create_community`. The first two are shared with `community_member`. The third (`create_community`) is a defect per D1. There is no permission that distinguishes what a contributor actually contributes.

---

## 3. Proposed Standardized Model

### Principles

1. **Role intent must match permissions.** A facilitator facilitates; they manage events and invitations. A content curator creates content. A strategist manages structure and roles. Permissions must match these purposes exactly.

2. **Community roles must not carry platform-level rights.** `create_community` and the ability to `delete_community` are platform-level acts. Community roles should only control what happens within a single community, not across the platform.

3. **Content types in a community follow a consistent permission pattern.** Posts, pages, and events should all use a named permission gate so that administrators can reason about who can create what.

4. **UI affordances must match policy.** If the policy allows someone to create X, they should see the button for X. If they are not allowed, they should not see it.

5. **Organizer and coordinator must be meaningfully different** or one should be retired.

---

### New permission: `manage_community_events`

Add a dedicated community-scoped permission to gate event creation and management within a community. This mirrors `manage_community_content` and allows the role system to express "events coordinator" cleanly.

---

### Proposed role redesign

| Permission | member | contributor | facilitator | content\_curator | strategist | legal\_advisor | governance\_council | coordinator | organizer |
|-----------|:------:|:-----------:|:-----------:|:----------------:|:----------:|:--------------:|:-------------------:|:-----------:|:---------:|
| `read_community` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `list_community` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `invite_community_members` | | ✓ | ✓ | | | | ✓ | ✓ | ✓ |
| `manage_community_events` | | | ✓ | | | | | ✓ | ✓ |
| `manage_community_content` | | | | ✓ | | | | ✓ | ✓ |
| `manage_community_settings` | | | | | | ✓ | | ✓ | ✓ |
| `update_community` | | | | | ✓ | ✓ | | ✓ | ✓ |
| `manage_community_members` | | | | | | | ✓ | ✓ | ✓ |
| `manage_community_roles` | | | | | ✓ | | ✓ | ✓ | ✓ |
| `manage_community_notifications` | | | | | | | | ✓ | ✓ |
| `delete_community` | | | | | | | | | ✓ |
| `create_community`* | — | — | — | — | — | — | — | — | — |

\* `create_community` removed from all community roles. Community creation should be gated by platform-level permission only.

**Role purpose summary:**

| Role | Purpose |
|------|---------|
| `community_member` | Reads and participates in discussions |
| `community_contributor` | Recruits and invites new members |
| `community_facilitator` | Organizes and hosts events |
| `community_content_curator` | Creates and manages posts and pages |
| `community_strategist` | Manages role structure and governance |
| `community_legal_advisor` | Reviews community settings and compliance |
| `community_governance_council` | Manages membership and roles; governance |
| `community_coordinator` | Manages content and events; mid-tier organizer |
| `community_organizer` | Full community management authority |

**What distinguishes coordinator from organizer (proposed):**
- `community_coordinator` → content + events + members, but NOT `delete_community` or full settings management
- `community_organizer` → everything including deletion and settings

---

### Proposed policy changes

#### PagePolicy — align with PostPolicy

```ruby
# Current:
def create?
  platform_content_manager?
end

# Proposed:
def create?
  platform_content_manager? || community_content_manager?
end
```

Where `community_content_manager?` checks `manage_community_content` scoped to the page's community (same pattern as PostPolicy).

Pages should also auto-assign `community_id` from `community_context` in PagesController, mirroring PostsController.

#### EventPolicy — add `manage_community_events` path

```ruby
# Current:
def create?
  platform_event_manager? || event_host_member?
end

# Proposed:
def create?
  platform_event_manager? || community_event_manager? || event_host_member?
end

private

def community_event_manager?
  target_community = record.event_hosts.find { |h| h.host_type == 'BetterTogether::Community' }&.host
  return false unless target_community
  permitted_to?('manage_community_events', target_community)
end
```

`event_host_member?` is retained for person-hosted events (events not belonging to any community). Community-hosted events get the cleaner `community_event_manager?` path.

#### CommunityPolicy — replace `create_events?` check

```ruby
# Current — requires update? (update_community):
def create_events?
  update? && BetterTogether::EventPolicy.new(user, Event.new).create?
end

# Proposed — uses the new permission directly:
def create_events?
  permitted_to?('manage_community_events', record) ||
    permitted_to?('manage_platform_settings') ||
    permitted_to?('manage_platform')
end
```

This makes the button visible to facilitators (who have `manage_community_events`) and hides it from strategists and legal advisors (who have `update_community` but are not event managers).

---

### Privacy and publishing agreement — no changes proposed

The current model (private: no agreement; community/public: agreement required) is correct and should remain as-is across all content types.

---

## 4. Migration Considerations

### Breaking changes
- Removing `create_community` from community roles: any existing member relying on this to create new communities will lose that ability. **Low risk** — this was likely unintentional.
- Removing `delete_community` from facilitator, content_curator, strategist, legal_advisor, governance_council: existing members in these roles lose community deletion rights. **Low risk** — deletion should be rare and controlled.
- Removing `update_community` from facilitator and content_curator: these roles currently have update rights they probably should not. **Medium risk** — if any facilitator or content curator has been using community settings management, they will lose access.

### Additive changes (safe)
- Adding `manage_community_events` permission and populating it on facilitator, coordinator, organizer
- Updating PagePolicy to accept `manage_community_content`
- Updating EventPolicy to add `community_event_manager?` path

### Seed/builder run required
After changing `access_control_builder.rb`, run the builder to apply changes to the database. Existing `RoleResourcePermission` records will need to be reseeded or selectively updated.

---

## 5. Open Questions for Decision

1. **Should `community_contributor` gain `invite_community_members`?** Currently they have only read access. Their name implies active participation — should they be able to grow the community?

2. **Should `community_content_curator` lose `update_community` and `delete_community`?** The proposed model removes these. This makes content curation a purely content-scoped role without structural authority. Is that the intent?

3. **Should any community role retain `create_community`?** Or should new community creation always require a platform-level action?

4. **Should the event `host_member?` path remain for regular community members?** The proposed model keeps it for person-hosted events only. If we want all events to be permission-gated, we could remove `event_host_member?` entirely from the community event path.

5. **Coordinator vs. organizer distinction** — is the proposed split (coordinator: no delete, no full settings; organizer: full authority) the right boundary?

6. **Pages and host_community auto-assignment** — should pages created at the platform level be assigned to `host_community` like posts are? Or should platform-level pages remain community-less?
