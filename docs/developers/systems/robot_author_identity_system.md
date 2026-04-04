# Robot Author Identity System

## Overview

The robot author identity system is the proposed extension that would allow Community Engine robots to become truthful, first-class authors of pages, posts, and other governed content.

Today, Community Engine robots exist as persisted configuration/runtime records, but authored content still assumes a human person model for creator and author relationships.

This design closes that gap.

## Problem Statement

Current content authorship and audit expectations are human-centered:

- content creator associations point to people
- authorship displays assume a human authoring subject
- robots can assist operationally, but they cannot yet be represented as first-class published actors

That creates two problems:

1. robot-authored content cannot be attributed truthfully in-app
2. governance and review expectations for robot publishing cannot be surfaced clearly

## Design Goals

The future robot author identity system should:

- support truthful robot authorship
- avoid impersonating human authors
- make authority and limits visible
- support mixed human/robot collaboration
- preserve auditability
- connect published actions to agreements and governance surfaces

## Recommended Model Direction

The preferred direction is to introduce a shared actor boundary for authored-content and governance records, rather than embedding special-case robot exceptions into existing person-only associations.

That actor layer should eventually support at least:

- `Person`
- `Robot`

and possibly future collective or delegated authoring patterns if the product evolves that way.

The next concrete bridge from design to implementation is documented in:

- [Actor-Safe Creator and Authorship Migration Plan](actor_safe_creator_authorship_migration_plan.md)

## Required Robot Identity Surface

A robot author should be represented with at least:

- display name
- stable handle or identifier
- role or purpose summary
- capability summary
- governing agreements and policy links
- authorized scope
- accountable steward or stewardship path where relevant

This identity should appear in:

- content authorship displays
- profile/detail views
- audit and history surfaces

## Governance Requirements

Robot authorship should only be considered complete when it includes:

- disclosure that the author is a robot
- disclosure of the robot's role and scope
- records of which agreements and policies govern it
- review or challenge paths for consequential actions
- audit logs that do not blur human and robot responsibility

## Content Workflow Implications

The future publishing workflow should support:

- robot-authored private drafts
- mixed human and robot editorial collaboration
- review states before publication
- explicit publish authority

This is especially important for release packages, launch pages, and milestone posts.

## Current Status

This design is **not yet implemented** as a first-class CE feature.

The robot system exists, but the author identity and governed authorship surfaces described here are still future work.
