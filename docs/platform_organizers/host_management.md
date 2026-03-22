# Host Management

This section covers all administrative features available to platform hosts.

## Host Navigation

The host navigation bar provides quick access to key administrative areas:

- **Dashboard**: View high-level metrics, recent activity logs, and shortcuts to common tasks.
- **Communities**: Create and manage community instances, configure privacy and membership settings.
- **Navigation Areas**: Define and publish header, footer, and sidebar menus with nesting and visibility controls.
- **Pages**: Build and maintain CMS pages using the block editor, schedule publishing, and assign navigation.
- **People**: Search and edit person records, manage profiles, community memberships, and special access flags.
- **Platforms**: Configure platform-wide metadata (name, description, logo) and global privacy/invitation rules.
- **Roles**: Establish user roles at platform and community levels, specifying purpose and default privileges.
- **Resource Permissions**: Assign fine-grained CRUD permissions on resources to defined roles for access control.
- **Resources**: Upload, categorize, and version downloadable assets (PDFs, images, reports) for reuse.
- **Content Blocks**: Review and configure reusable block types (rich text, images, templates, etc.) for the page editor.
- **Metrics Reports**: Generate CSV exports and view charts for page views, link clicks, downloads, and shares.

## Dashboard Overview

### Newcomer Navigator NL

- **Partners**: Onboard partners by creating profiles with names, descriptions, logos, and geo-coordinates.
- **Resources**: Curate newcomer assets (guides, checklists, videos) and control download permissions.
- **Journey Stages**: Outline sequential phases of the newcomer experience, assign stage labels and ordering.
- **Topics**: Tag resources and pages with topic labels for easier filtering and discovery.
- **Journey Maps**: Build visual flowcharts mapping stages, topics, and resource links to guide newcomers.

### Better Together Core

- **Communities**: Spin up new community sites, configure membership rules, customize branding and privacy.
- **Navigation Areas**: Manage site-wide menu structures, assign them to layouts or specific pages.
- **Pages**: Author content pages with drag-and-drop block editing, manage drafts and publish schedules.
- **Platforms**: Update platform metadata (name, logo, description), set language/localization defaults.
- **People**: Administer person records, view activity logs, reset access, and manage guest access tokens.
- **Roles & Permissions**: Define role-based access rules, map permissions to resources, and cache policy for performance.
- **Users, Conversations & Messages**: Monitor registered users, initiate or audit conversation threads, and review message history.
- **Categories**: Create and manage taxonomy for content and events to improve discoverability.

## Platform Details

Under **Platforms**, edit these platform settings:

- **Name & Description**: Set the display name, subtitle, and descriptive text for the platform header and meta tags.
- **Privacy Settings**: Choose whether the platform is public, private (invite-only), or hidden from unregistered users.
- **Invitation Requirements**: Toggle whether users need an invitation code to register or if self-registration is open.

### Privacy & Invitation Tokens (Events)

- Private platforms: when privacy is set to private/invite-only, public browsing is limited. However, valid event invitation tokens allow invitees to access the specific event page without broad platform access.
- How it works:
  - Invitee opens an event invitation link (`/invitations/:token`) or an event URL with `?invitation_token=...`.
  - The token is validated against a pending, non-expired `EventInvitation` for that event.
  - On success, the token (and invitation locale) is stored in session, allowing access to that event page even if the platform is private.
  - Invalid/expired tokens on private platforms redirect users to sign-in.
- Registration mode: if “Requires Invitation” is enabled for platform registration, new users must provide a valid platform invitation code to register. Event invitations do not replace platform registration codes; they only grant access to view/respond to the specific event.
- Security notes:
  - Tokens are scoped to a single event and do not grant global access.
  - Token validity windows can be set per invitation (valid_from/valid_until) and status changes remove access.

## Roles & Permissions

Roles and permissions are managed independently at the platform and community levels to provide scoped access control.

### Platform Roles & Permissions
- Define global roles that apply across the entire platform, then grant or revoke specific resource permissions per role to control CRUD access.

### Community Roles & Permissions
- Create roles scoped to individual communities and assign permissions to control access to community-specific features and content.

> **Note:** Permission checks are cached per role to optimize database performance and reduce authorization overhead.

## User Accounts

- **List**: View all registered users, filter by status, role, or last sign-in date.
- **Registration & Sign In**: Configure email workflows for user onboarding, password resets, and account confirmations.
- **Profiles**: Enable users to update personal information (avatar, contact info, preferences) and manage privacy settings.

## Metrics & Reporting

- The engine collects and visualizes these core metrics:

- **PageView**: Measures views on pages, people, communities, and partners. Available charts include views by page (bar) and daily totals (line).
- **LinkClick**: Logs each tracked link interaction with charts for clicks by URL and daily trends.
- **Download**: Records downloads of resources and exported reports with charts of downloads by file name.
- **Share**: Tracks share button clicks per social platform, offering charts for shares by platform and per-URL breakdowns.

All metrics support date-range filtering and locale-specific breakdowns, with CSV export for offline analysis.

**Future reports** will include user engagement dashboards, invitation conversion analytics, partner link-click reports, and additional metric types such as search queries and journey map interactions.

## Search & Notifications & Caching

- **Search**: Full-text search powered by Elasticsearch, indexing pages, posts, people, and events with faceted filtering support.
- **Notifications**:
  - **Email**: Configurable notification templates for actions such as invitations, mentions, and password resets.
  - **In-app**: Real-time alerts delivered via ActionCable with both ephemeral toast messages and persistent notification feeds.
- **Caching**: Implements fragment and page caching for navigation and content blocks, with Redis-backed cache stores and optional CDN integration to speed up delivery.
