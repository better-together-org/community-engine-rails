# Hosted platform manual provisioning runbook and steward smoke test

Audience: the operator (host platform steward or a person with shell access to the host app) who sets up a hosted platform by hand, and the reviewer who signs off that its steward can run it.

This is the interim path. It stays valid until provisioning is automated (see [the provisioning wizard assessment](../implementation/current_plans/new_platform_provisioning_wizard_assessment.md)). Part A creates and hands over the platform. Part B is the acceptance test, run on staging before production and again after any change to the steps in Part A.

Related: [Multi-Platform Deployment Guide](multi_platform_deployment.md) for domain and proxy background.

## Part A: operator runbook

### 0. Before you start

- Run the whole procedure on staging first. A production run follows the same steps and is a gated change: get explicit confirmation from the person accountable for the host app before each write.
- Snapshot the database before the first provisioning run of a change set. Provisioning is additive, but the snapshot is the rollback for anything unexpected.
- Decide, with the steward, the platform name, privacy (the safe default is private and invitation only), time zone, and the hostname.
- Hostname rules the server enforces for a steward (an operator is exempt):
  - exactly one label under an allowed zone: the host platform's primary domain, plus any zones listed in `BetterTogether.platform_domain_zones`;
  - the first label must not be reserved (`BetterTogether.reserved_domain_labels`; the host app should append every name already live in its zones);
  - a domain a steward requests is created inactive, never primary and never a share domain.
- A custom domain outside the allowed zones is operator-created only. There is no steward self-serve path for client-owned domains yet.

### 1. Create the platform

Two paths. Use the wizard when a person is present, the rake task for scripted staging runs.

**Wizard (preferred).** Sign in as a host steward and use the provision button on the Platforms index (`/new_platform_setup`). The run creates a draft platform, then walks through welcome, platform identity, domain, steward account, invite members, and review and launch. The steward step also seeds the platform's roles and navigation.

**Rake task.**

```bash
bin/dc-run bin/rails "better_together:provision_tenant[Tenant A,https://tenant-a.example.org,America/St_Johns,steward@example.org,<temporary password>,Tenant Steward]"
```

Every argument after `host_url` is optional, and the steward is created only when both email and password are given. The password lands in shell history and process listings, so use a temporary one and make the steward reset it, or skip the steward arguments and use the wizard's steward step instead. Re-running with the same `host_url` is safe: it finds the existing platform.

Either path creates, in one transaction:

- the hosted platform (`BetterTogether::HostedPlatform`, not the host) and its primary community;
- the primary domain from `host_url`;
- the platform's own copy of the default roles and permissions;
- the platform's own navigation areas (header, footer, host admin menu, better-together) and their pages, so the platform does not show the host's menu;
- when a steward is supplied: the steward user, the `platform_steward` membership and the `community_governance_council` membership, with the steward as the community's creator.

### 2. Verify what was created

Use the host dashboard or a read-only console session on staging.

- The platform exists with `host: false`, type `HostedPlatform`, and the expected privacy.
- It has a primary community and exactly one primary, active domain.
- It owns roles (`platform_steward`, `platform_manager` and the rest) and navigation areas. Its navigation areas must not be the host's.
- The host platform's navigation areas and roles are unchanged.

### 3. Domain, DNS, certificate and routing

These happen outside the Community Engine app and are gated changes in the operator's own environment.

1. DNS: point the new hostname at the shared edge as a CNAME to the edge hostname, never an A record to an IP.
2. Certificate: issue or extend a certificate that covers the hostname, both at the edge and on the app host if the edge re-presents SNI.
3. Routing: add the hostname to the edge routing and to the app host's accepted domains. An edge routing change needs a reviewed pull request.
4. Activate the domain in the app: if the steward requested it, the operator opens the platform's domains, checks the hostname, and turns it on. Make it primary only when the old primary has been verified to redirect.

Verify from outside the mesh: the hostname resolves, serves a valid certificate chain, and returns the new platform (not the host) on its public page.

### 4. Grants and limits

Feature access and quota grants are administered by the governing operator, not by the steward of the platform itself. Grant only what the platform's plan covers, with the operator account, on the platform's grants page. A steward cannot grant themselves capacity.

### 5. Hand over

- Give the steward the sign-in address on their own domain. Accounts are per platform, so their user belongs to the hosted platform and signs in only there.
- If the steward was created with a temporary password, require a reset on first sign-in.
- Walk them through Part B items 1 to 4. The steward then configures the rest themselves.

### 6. If something goes wrong

- A failed provisioning run rolls back. Fix the cause and re-run with the same `host_url`.
- A wizard run abandoned part way leaves a draft platform with a `*.pending.invalid` host URL. Delete the draft before retrying with the same name.
- Do not repair a production platform by direct database edits. Fix the source and redeploy.
- Domain mistakes: deactivate the domain in the app; DNS and routing changes follow the same gated procedure as in step 3.

## Part B: steward smoke test

Run on staging with a real hosted-platform steward account (not a host steward). Record pass or fail, who ran it, the date, and the commit under test. A failed item blocks production.

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Open the platform's own domain and sign in as the steward | Signs in on that domain only, using the platform's branding | |
| 2 | Land after sign-in | The steward's dashboard opens without a permission error | |
| 3 | Dashboard overview counts and recent records | Only this platform's data. Seed a second platform with distinct records and confirm none appear | |
| 4 | Roles and permissions index | Counts and lists are this platform's only | |
| 5 | Navigation | The header, footer and admin menu are the platform's own. Edit an item and confirm the host's menu does not change | |
| 6 | Members and invitations | Invite a person, set a role, suspend and restore. Confirm the invitation link uses the platform's own domain | |
| 7 | Pages and content | Create, edit and publish a page. It appears only on this platform | |
| 8 | Theme and branding | Change logo or colors. Only this platform changes | |
| 9 | Request a domain inside an allowed zone | Created inactive and not primary. The steward cannot turn it on | |
| 10 | Request a domain with a reserved name, or outside the allowed zones | Refused with a clear error | |
| 11 | Grants | The steward has no way to grant themselves features or quota | |
| 12 | Host-only surfaces (host platform administration, other platforms, jobs, code snippets) | Denied or absent from the menu | |
| 13 | Directly request another platform's record by id or URL | Not found or denied | |
| 14 | Sign out, then sign in on the host domain with the same credentials | Fails: accounts are per platform | |

Sign-off: all fourteen pass, screenshots of items 2, 5 and 9 attached to the change, and the steward confirms they can find each function they need.
