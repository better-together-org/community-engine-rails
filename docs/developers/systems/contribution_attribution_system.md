# Contribution Attribution System

## Summary

Community Engine now uses `better_together_authorships` as a transitional governed contribution table.
The table name remains for compatibility, but each record can now model:

- a governed contributor (`Person` or `Robot`)
- a contributable record (`Page`, `Post`, JOATU request/offer/agreement, and later other records)
- a `role` such as `author`, `editor`, `reviewer`, `translator`, `idea_source`, `moderator`, `exchange_initiator`, or `exchange_participant`
- a `contribution_type` such as `content`, `documentation`, `code`, `financial`, `governance`, `operations`, `research`, or `community_exchange`
- structured `details` for future source-linked attribution such as GitHub-backed contribution evidence

## Why

`Authorship` alone is too narrow for the governance direction of Community Engine.
The platform needs to attribute many kinds of value creation, including:

- content creation and editing
- documentation and code work
- financial support
- moderation and review
- governance and operational labor
- survey and research participation
- JOATU exchange participation as a contribution to the scoped community

## Current Compatibility

- `author` remains the default role for existing page/post flows
- `authors` and `robot_authors` remain available as compatibility helpers
- `contributors`, `contributions`, and role-aware query helpers are now the broader interface
- page and post forms now expose a multi-role governed contribution editor
- persisted page and post records can now import GitHub-native contribution activity directly into governed contribution records

## JOATU Integration

- JOATU requests and offers now record their creator as an `exchange_initiator`
- JOATU agreements now record participating creators as `exchange_participant`
- these records use `contribution_type = community_exchange`

This is the first step toward treating exchanges as community contribution rather than only transactional data.

## GitHub-linked contribution imports

When a person has a linked GitHub identity, Community Engine can now import GitHub-native activity into governed contribution records on persisted pages and posts.

The current mapping is:

- `repository` -> `role: author`, `contribution_type: code`
- `pull_request` -> `role: author`, `contribution_type: code`
- `commit` -> `role: author`, `contribution_type: code`
- `issue` -> `role: idea_source`, `contribution_type: documentation`

The import path deliberately merges repeated GitHub activity into one governed contribution record per contributor / role / contribution type. Imported source entries are stored in `details['github_sources']` so attribution remains auditable without creating one bridge record per commit or pull request.

This gives the contribution system a first native bridge from GitHub OAuth-linked identities into CE contribution attribution while preserving the broader governed contribution model.

## Future Work

- add explicit contribution rendering for roles beyond author
- expand contributable coverage to governance, moderation, surveys, and financial records
- extend GitHub-native contribution import beyond pages and posts into broader governed records where that attribution is meaningful
