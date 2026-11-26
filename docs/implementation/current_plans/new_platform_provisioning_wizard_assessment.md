# New platform provisioning surfaces and a seed-selecting provisioning wizard

Status: assessment and proposal. No code in this change. Written for the HPS stack (hosted platform steward parity) and the follow-up provisioning work.

Goal: one provisioning wizard, modelled on the existing setup wizards, with a step where the steward (and later the person who will steward the new platform) chooses which seeds and seed packs to plant, such as navigation areas, navigation items, roles and other available packs. First for platforms inside the shared database, later for provisioning a separate app.

## 1. What exists today

| Surface | What it does | Gaps for the goal |
|---|---|---|
| `PlatformsController#new/#create` (bare CRUD form) | Saves a platform. Model callbacks add the primary community, the primary domain and registry defaults. | No roles, no navigation, no steward. A platform made here is not usable and has no seed choice. The Platforms index already links to the wizard instead. |
| `NewPlatformSetupController` and `NewPlatformSetupStepsController` (six steps: welcome, identity, domain, steward account, invite members, review and launch) | Creates a draft platform with a placeholder `*.pending.invalid` host URL, mints a per-run `Wizard` and step definitions, walks through the steps, and completes the run. | The draft exists from the first click, so abandoned runs leave drafts (no cleanup). Seeding is a side effect of the steward step, not a visible choice. Steps are hand-written actions and per-step routes. `WizardStepsController#update` is an unimplemented stub, so every step repeats the same find-step, complete, determine-outcome code. Form classes are hard-coded per action and the generic `WIZARD_FORM_CLASSES` allow-list does not include the new forms. Review shows no seed summary. |
| `TenantPlatformProvisioningService.call` and `better_together:provision_tenant` | One transaction: platform, roles, navigation (HPS-5), optional steward. Idempotent by `host_url`. | Fixed seed set. Steward password passes as a command argument. Privacy is hard-coded. No dry run. No record of what was planted. |
| `TenantPlatformProvisioningService.provision_steward_for_existing_platform!` | The wizard's steward step. Roles, memberships, navigation. | Same fixed seed set; navigation is seeded here only because it is the last step that always runs. |
| Host `SetupWizardController` and `SetupWizardBuilder` (host setup, single use) | The model for a wizard: a seed YAML (`config/seeds/better_together/wizards/host_setup_wizard.yml`) describes the wizard and its steps, a builder mints them. | Only for the host platform. Membership code is duplicated from the provisioning service. The YAML step list and `NewPlatformSetupWizardBuilder::STEP_DEFINITIONS` are two different formats for the same idea. |
| Seed packet system (`Seeds::Plant`, `Planner`, `Applier`, packets under `config/seeds/better_together/{rbac,navigation}`) | Validated, dry-runnable, idempotent, platform-targeted planting with provenance (`SeedPlanting`). Rake: `seed_packets:plan` and `:plant`. | Only two packets exist. Each packet carries `seed_pack` metadata (`install_tier`, `selectable_in_setup_wizard`, `default_selected`, `dependencies`, `applies_to`, `installer`, `replaces_builder`) that no code reads. Both set `selectable_in_setup_wizard: false`. The protocol doc names `PackInstaller`, `InstallerRegistry` and a `seed_pack_selection` wizard step; none of them exist. |
| Builders (`NavigationBuilder`, `AccessControlBuilder`, `AgreementBuilder`, `CategoryBuilder`, `GeographyBuilder`, demo builders) | The real seeding path today. `NavigationBuilder` and `AccessControlBuilder` take `platform:`. | `AgreementBuilder`, `CategoryBuilder`, `GeographyBuilder` and the demo builders take no platform, so they cannot seed a hosted platform. No dry run, no provenance. |
| Seed catalog admin page (`SeedCatalogController`, geography only) | Operator plants optional geography data. | Not per platform, one catalog. A pattern for "optional pack" UI only. |

Bugs found while assessing, already fixed in HPS-5: items took no platform before the identifier check (clashed with the host's), and the seeded pages were created without a platform.

## 2. What the wizard needs

The existing wizard machinery is enough to build on: `Wizard`, `WizardStepDefinition` (identifier, step number, message, form class, template), `WizardStep` completion, `max_completions`, and a per-run wizard minted by a builder. The work is to make steps data rather than code, and to put seeding behind a catalog and a choice.

### 2.1 A catalog of seed packs (the foundation)

Everything the new step needs is "which packs can this platform install, what do they depend on, which are on by default". The `seed_pack` metadata already says that. Needed:

1. **`SeedPackCatalog`**: reads every packet's `seed_pack` block from the engine and any host app folders, validates it against `envelope.schema.json`, and answers: the packs that apply to `platform` (via `applies_to`), their tier (`core` always on, `recommended` default on, `optional` and `demo` default off), `default_selected`, dependencies, and a human name and description.
2. **`PackInstaller` and `InstallerRegistry`** (named in the protocol doc): one interface, `plan(platform)` and `install(platform)`, with two kinds of installer behind it. A packet installer calls `Seeds::Plant` (dry run for plan). A builder installer wraps an existing builder until its packet exists (`replaces_builder` records which). A pack with a builder that takes no platform is not selectable until the builder takes one.
3. **Selection resolver**: given the chosen pack identifiers, adds the dependencies, rejects unknown and non-applicable packs, rejects a selection that leaves a `core` pack out, and returns plant order (access control, navigation and pages, agreements and categories, then optional and demo content), matching the order in the multi-tenancy notes.
4. **New packets** for what is still builder-only: agreements, categories, and per-pack navigation granularity.

### 2.2 Packs worth offering (initial list)

| Pack | Tier | Notes |
|---|---|---|
| Roles and permissions (`better-together-rbac`) | core, always on | Required before anything else; every platform owns its copy. |
| Navigation and static pages | recommended, default on | Today one packet. Splitting it lets a steward pick areas independently: header, footer, host admin menu, better-together menu, with items and pages inside each area. Needs the packet split, with dependencies between the pieces (items need their area, linked pages need the pages). |
| Agreements and legal pages | recommended | New packet from `AgreementBuilder`. |
| Categories | optional | New packet from `CategoryBuilder`. |
| Geography reference data | optional | Not per platform today; keep it out until it is. |
| Demo and joatu content | demo, default off | After the builders take a platform. |

The steward sees marketing name and description, and for navigation a preview of what will be created (the plan counts: create, update, skipped).

### 2.3 The wizard itself

Keep one wizard identifier, `new_platform_setup`, and extend its step list. Proposed steps:

1. Welcome (unchanged).
2. Platform identity (unchanged).
3. Domain (unchanged, and shows the zone and reserved-name rules).
4. **Seed selection (new)**: a checkbox list built from `SeedPackCatalog`, with core packs shown as required and recommended packs ticked. Dependencies tick automatically and explain why. Saves the choice on the draft platform (a small wizard-run record, not columns on `Platform`).
5. Steward account (the account only: no seeding as a side effect).
6. Invite members (unchanged).
7. **Review and launch**: shows the plan from a dry run of the chosen packs (counts per pack, anything that would be skipped or conflict). Launch plants, writes one `SeedPlanting` per pack, and completes the wizard.

Differences that matter:

- **Plant on launch, not mid-wizard.** Today the steward step seeds. Moving seeding to launch means the review step can show what will happen, a failed plant leaves the wizard incomplete and re-runnable, and abandoning a run plants nothing.
- **Step definitions as data.** Move the step list to a seed YAML like `host_setup_wizard.yml`, with `NewPlatformSetupWizardBuilder` reading it. Both wizards then share one format and a host app can add or reorder steps by shipping a packet.
- **One generic step controller.** Replace the per-step hand-written actions with the base controller's `show` and `update` driven by the step definition (form class resolved through `SafeClassResolver` and the allow-list, which must include the new forms). Keep a step-specific hook for the few steps with side effects (domain, steward, invitations). This removes the repeated completion code and the per-step routes.
- **Draft cleanup.** A scheduled job removes draft platforms whose wizard never completed after a set time, and the draft is created at the identity step rather than at the first click.
- **Authorization**: a platform steward can later run the wizard for a platform they are creating on the operator's behalf. Today the check is `PlatformPolicy#create?` for the whole run, because nobody holds a membership on the draft yet. Keep that check, and add the access-control contract entry for the wizard when it changes.

### 2.4 Two kinds of person in the wizard

The user's note: the steward now, perhaps later the person who will become the new platform's steward. Two modes, same steps:

- **Operator-run** (now): the host steward fills every step.
- **Handover** (later): the operator runs steps 2 to 4 and 7's launch gate, and sends the steward an invitation that opens at the steward-account step on the new platform's own domain. The steward then picks seeds on step 4 (or reviews the operator's choice) and sets their own password. This needs the initial-steward invitation from the larger plan and a draft that is addressable by a token rather than by the operator's session. Not in the first iteration; design the draft record and steps so it can be added without reshaping them.

## 3. Provisioning a separate app later

The shared-database wizard provisions rows. Provisioning an app also provisions infrastructure (database, storage, secrets, domain, certificate, routing, deploy). The same wizard fits if each infrastructure concern is a step type with a dispatch and a status, not an inline action.

- Add a **target** to the wizard run: `shared_database` or `dedicated_app`. The target decides which steps appear (identity, domain, seed selection and steward exist in both; infrastructure steps appear only for `dedicated_app`).
- Infrastructure steps do not execute work in the web request. Each one creates a provisioning job record with an idempotency key, calls a dispatcher, and shows its status (queued, running, needs approval, done, failed with a reason and a retry). A step completes when its job completes. The dispatcher is a port: the CE gem defines the interface and a null implementation; the operator's own application supplies the real one (signed requests to its infrastructure automation). The gem holds no infrastructure secrets or fleet commands.
- Any step that changes production infrastructure needs a recorded human approval that the executing side verifies independently of the application. The wizard shows the pending approval; it never approves.
- Seed selection in a dedicated app uses the same packs, planted by the new app on first boot from the recorded selection, so the choice made in the wizard is the choice the app applies. That makes the catalog and the packet format the shared contract, which is why section 2.1 comes first.
- The step list stays data (2.3), so `dedicated_app` is a second YAML, not a second wizard.

## 4. Phased plan

Each phase is a small reviewable change with specs, screenshots for any view, and an access-contract update where authorization changes.

1. **Catalog**: `SeedPackCatalog`, schema validation, `applies_to` and tier handling, specs on the two existing packets. No UI.
2. **Installers**: `PackInstaller`, `InstallerRegistry`, the packet installer and a builder installer wrapper, dependency resolver, plan (dry run) and install, `SeedPlanting` per pack.
3. **Platform-aware builders and packets**: `AgreementBuilder`, `CategoryBuilder` take a platform; navigation split into selectable packs; agreements and categories packets.
4. **Wizard data and generic controller**: step definitions in YAML, one generic step controller, draft cleanup job, domain rules shown on the domain step.
5. **Seed selection step and review plan**: the new step, the dry-run review, plant on launch, wizard run record, move seeding out of the steward step. Screenshots and DOM contracts.
6. **Service parity**: `TenantPlatformProvisioningService` and the rake task accept a pack selection and use the same installers (so there is one seeding path), keep the idempotent behavior, stop taking the steward password as an argument.
7. **Handover mode**: invitation-driven steward steps on the new platform's domain.
8. **Dedicated app target**: provisioning job records, dispatcher port, approval display, infrastructure steps.

Open questions for the maintainer:

- Is `core` always-on right for access control (roles), or should a platform be allowed to start with none and install roles later?
- Should the steward choice be locked after launch, or can packs be added later from the same catalog on the platform's own admin page (the add-only packet mode makes that safe)?
- Where do host-app packs live (a folder the engine scans, or registration in an initializer like the seed type registry)?
- Who may select demo packs on a production platform, if anyone?
