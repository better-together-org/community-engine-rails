# Content and Event Permissions for Community Organizers

This guide explains who in your community can create posts and events, what roles you need to assign to enable those capabilities, and what the publishing agreement means for your members.

---

## Who Can Create Posts in Your Community

A member can only create posts in your community if they have one of these three roles:

| Role | Can create posts | Can also manage community settings |
|------|:----------------:|:---------------------------------:|
| **Community Organizer** | Yes | Yes |
| **Community Coordinator** | Yes | Yes |
| **Community Content Curator** | Yes | No |
| Community Facilitator | No | No |
| Community Contributor | No | No |
| Community Member | No | No |

**Default new members** join with the `Community Member` role and cannot create posts. You must explicitly upgrade a member's role to grant post creation.

> **Private posts** can be created without any extra steps — the member just needs the right role and the post will only be visible to them and platform stewards.
>
> **Community or public posts** require the member to have accepted the [content publishing agreement](#the-publishing-agreement) before the post can be saved.

---

## Who Can Create Events in Your Community

Events work differently from posts. **Any active member of your community can create an event on behalf of the community**, regardless of their role — because their community membership qualifies them as a valid event host.

However, the "Create Event" button in the community events tab is only shown to members who also have permission to manage community settings. Members without that button can still create events by going directly to the new event page and selecting your community as a host.

| Role | Sees "Create Event" button | Can create events |
|------|:-------------------------:|:-----------------:|
| **Community Organizer** | Yes | Yes |
| **Community Coordinator** | Yes | Yes |
| Community Content Curator | No | Yes (direct URL) |
| Community Facilitator | No | Yes (direct URL) |
| Community Contributor | No | Yes (direct URL) |
| Community Member | No | Yes (direct URL) |

> **Private events** can be saved immediately.
>
> **Community or public events** require the member to have accepted the [content publishing agreement](#the-publishing-agreement).

---

## Understanding Privacy Levels

Every post and event has a privacy setting that controls who can see it.

| Privacy | Who can see it | Publishing agreement needed? |
|---------|---------------|:----------------------------:|
| **Private** | Only the creator and platform stewards | No |
| **Community** | Anyone with an active membership in the community | **Yes** |
| **Public** | Anyone — including people not logged in | **Yes** |

Members can always create and edit private content freely. The publishing agreement only becomes relevant when they want to share content more widely.

---

## The Publishing Agreement

The **content publishing agreement** is a platform-level consent step that each person must complete once before they can make any content (posts or events) visible to community members or the public.

**How it works:**
1. A member creates a post or event and sets the privacy to Community or Public.
2. If they haven't yet accepted the agreement, the save fails and they see an error message with a link to read and accept it.
3. Once they accept, all future saves with community or public privacy work without interruption.
4. If they've already accepted, nothing extra is required.

**As an organizer**, you may want to remind new contributors to accept the publishing agreement before their first post or event — especially if they're joining for a time-sensitive occasion. A notice is shown automatically in the posts and events sections to members who have create permission but haven't yet accepted.

---

## How to Upgrade a Member's Role

To give a member the ability to create posts (or to see the Create Event button):

1. Go to your community's **Member Management** page.
2. Find the member and open their membership.
3. Change their role to **Community Organizer**, **Community Coordinator**, or **Community Content Curator**.
4. Save. The change takes effect within minutes (permission cache refreshes automatically on change).

> You need the **Community Organizer**, **Community Coordinator**, or **Community Governance Council** role yourself to change other members' roles.

---

## Quick Reference

**To let someone create posts in your community:**
→ Assign them `Community Organizer`, `Community Coordinator`, or `Community Content Curator`

**To let someone see the Create Event button in the community tab:**
→ Assign them `Community Organizer` or `Community Coordinator`

**To let someone create community-visible or public posts/events:**
→ They also need to accept the content publishing agreement (one-time, self-serve)

**To grant platform-wide post and event creation:**
→ A platform steward must assign a platform-level role (platform_steward or platform_manager) — this is outside community organizer scope
