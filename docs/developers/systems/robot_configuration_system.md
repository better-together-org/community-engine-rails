# Robot Configuration System

## Overview

Community Engine now persists AI-capable robot records in `better_together_robots`
instead of relying only on environment variables or hard-coded bot classes.

This gives CE a stable place to define:

- which robot identifier should service a task
- which provider and model that robot should use
- whether configuration applies globally or only to one platform
- what system prompt and provider-specific settings should accompany that robot

The current implementation is intentionally infrastructure-first. The persisted
model and runtime resolution exist now, but there is not yet a dedicated admin
UI for creating or editing robot records.

## Core Files

- Model: `app/models/better_together/robot.rb`
- Migration: `db/migrate/20260402120000_create_better_together_robots.rb`
- Runtime base class: `app/robots/better_together/application_bot.rb`
- Translation implementation: `app/robots/better_together/translation_bot.rb`
- Platform association: `app/models/better_together/platform.rb`

## Data Model

The `better_together_robots` table stores:

- `platform_id`
  - optional
  - when present, the record is scoped to one platform
  - when null, the record acts as a global fallback
- `name`
  - human-readable label
- `identifier`
  - stable runtime lookup key such as `translation`
- `robot_type`
  - current allowed values: `translation`, `assistant`, `automation`
- `provider`
  - logical provider key used for adapter dispatch, for example `openai`
- `default_model`
  - default chat/completion model for this robot
- `default_embedding_model`
  - default embeddings model for this robot
- `system_prompt`
  - persisted instruction text used by the robot when present
- `settings`
  - JSON provider/runtime options
- `active`
  - inactive robots are ignored by runtime resolution

## Uniqueness and Scope Rules

Two index rules enforce runtime safety:

- one unique record per `platform_id + identifier`
- one unique global fallback per `identifier` where `platform_id IS NULL`

That means CE can support:

- one platform-specific translation robot for Platform A
- one different platform-specific translation robot for Platform B
- one global `translation` robot used only when a platform-specific record does
  not exist

## Resolution Flow

Runtime resolution happens in `BetterTogether::Robot.resolve` and currently
follows this order:

1. active robot for the current platform and identifier
2. active global robot for that identifier
3. no persisted robot found

When no persisted robot is found, the bot classes still fall back to
environment-driven provider and model defaults.

Diagram:

- Source: [robot_configuration_resolution_flow.mmd](../../diagrams/source/robot_configuration_resolution_flow.mmd)
- PNG: [robot_configuration_resolution_flow.png](../../diagrams/exports/png/robot_configuration_resolution_flow.png)
- SVG: [robot_configuration_resolution_flow.svg](../../diagrams/exports/svg/robot_configuration_resolution_flow.svg)

## ApplicationBot Runtime Contract

`BetterTogether::ApplicationBot` now owns the shared resolution logic:

- resolve a robot by identifier and platform
- prefer persisted `provider` and `default_model` values when present
- dispatch to `BetterTogether.llm_chat` or `BetterTogether.embed_text`
- attach robot metadata for audit/context:
  - `robot_id`
  - `robot_identifier`
  - `platform_id`

This keeps higher-level bots thin. They only define:

- default identifier
- workflow-specific prompt handling
- domain-specific preprocessing or postprocessing

## Current Translation Path

`BetterTogether::TranslationBot` is the concrete implementation using the new
contract today.

It:

- resolves the `translation` robot by default
- prefers the persisted `system_prompt` when present
- dispatches through the adapterized AI wrapper
- preserves Trix attachments during translation
- logs usage and estimated cost for initiated translations

So the runtime stack is now:

`TranslationsController` -> `TranslationBot` -> `ApplicationBot` ->
`BetterTogether::Robot.resolve` -> adapterized `llm_chat`

## Settings Contract

`settings` is intentionally open-ended JSON for provider/runtime options. The
currently consumed flag in core CE is:

- `assume_model_exists`
  - when true, skip strict model-availability assumptions in downstream dispatch

This field should stay small and auditable. Provider gems should only consume
documented keys and should not treat `settings` as an arbitrary secrets store.

## Relationship to Adapterization

Robot persistence and provider adapterization solve different layers:

- `Robot` decides *which* provider/model/prompt profile should handle a task
- the adapter registry decides *how* that provider is invoked

So the robot model is a runtime configuration layer above the adapter registry,
not a replacement for it.

## Current Gaps

Implemented now:

- persisted robot records
- platform-aware and global fallback resolution
- bot metadata attached to adapterized AI calls
- translation path migrated to the new runtime contract

Not implemented yet:

- admin CRUD UI for robot management
- dedicated policy/controller layer for robot administration
- richer typed validation for `settings`
- additional first-class robot workflows beyond translation
- screenshots, because no robot-management UI exists on branch tip

## Reviewer Notes

This is an important architecture change even though the visible UI is still
minimal. Reviewers should treat it as:

- a new data model for AI runtime configuration
- a scoping mechanism for per-platform AI behavior
- a prerequisite for future provider-gem extraction and audited local routing
