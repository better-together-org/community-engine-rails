# Democratic By Design

The Community Engine is built to empower communities to operate in line with the 7 Cooperative Principles. Our defaults, feature choices, and extensibility aim to strengthen democratic control and local autonomy rather than weaken it.

## 1) Voluntary and Open Membership
- Invitation‑required by default: Hosts invite members deliberately, ensuring safe, values‑aligned onboarding (can be opened as needed).
- Accessible UX and i18n: Pages/blocks + Mobility translations support multilingual participation.
- Transparent access rules: RBAC and privacy settings make it clear who can see/do what.

## 2) Democratic Member Control
- Roles and memberships: People hold roles within Communities and Platforms; permissions are explicit and auditable.
- Policy‑driven access: Authorization is expressed in policies that map to meaningful permissions (e.g., update_community, manage_platform).
- Documentation first: Governance‑relevant settings (privacy, visibility, invitations) are documented and easy to review.

## 3) Member Economic Participation
- Exchange (Joatu): Requests, offers, and agreements help communities coordinate value exchange (time, skills, goods) without imposing external platforms.
- Minimal data collection: Economic coordination is facilitated without tracking identity in metrics (event‑only metrics).

## 4) Autonomy and Independence
- Self‑hosting and modularity: Communities can run their own stack and keep control over data and policies.
- No third‑party trackers by default: Hosts may opt‑in to tools like GA or Sentry in line with their privacy policy and consent.
- Open formats: Reports export to CSV for portability and community accountability.

## 5) Education, Training, and Information
- Pages & Blocks: Rich content areas (Hero, RichText, Image, Template) make it easy to publish governance docs, onboarding guides, and learning materials.
- Navigation areas: Global and sidebar navigation support structured access to educational content.

## 6) Cooperation Among Cooperatives
- Multi‑community design: People can belong to communities and platforms; navigation and content patterns scale across groups.
- Shared conventions: Common RBAC/metrics/content patterns allow communities to collaborate with minimal friction.

## 7) Concern for Community
- Privacy‑first metrics: We record what happened, not who did it, to reduce risk while still enabling community‑level insights.
- Transparent visibility: Content privacy and published_at states prevent accidental exposure; admins see clear controls instead of dark patterns.

## How Design Choices Support Democracy
- Private by default: Communities choose who joins and what’s visible.
- Explicit permissions: Roles + resource permissions reflect real responsibilities; policies stay readable and testable.
- Local language & context: Translations and configurable navigation put community voice first.
- Extensible, not extractive: Add integrations on your terms; remove them just as easily.

## Examples in Practice
- Set up a community: Keep invitations on and publish a plain‑language charter as a Page.
- Delegate maintenance: Create a community_admin role with permissions (list/read/update community; manage membership) and grant via membership.
- Teach & inform: Use Pages + sidebar nav for governance FAQs and proposals archive; link from the header nav.
- Share value: Use Exchange to match needs with offers and close agreements transparently.
- Report carefully: Use built‑in reports (CSV) for page views/link clicks to learn what content helps, without tracking identities.

## Roadmap & Extensions (Community‑Led)
- Proposals & polls: Lightweight deliberation modules (e.g., polls, consensus workflows) built on the same RBAC and privacy foundations.
- Participatory budgeting: Simple budget items with community voting; compatible with private‑by‑default metrics.
- Federation: Optional interoperability with other community engines to share knowledge without centralization.

If you’re building a specific democratic workflow, we’ll help map it onto the engine’s patterns (RBAC, content, exchange, metrics) so it remains privacy‑respecting and community‑owned.
