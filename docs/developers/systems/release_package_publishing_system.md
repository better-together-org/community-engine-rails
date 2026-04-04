# Release Package Publishing System

## Overview

The release package publishing system is the proposed CE-native workflow for publishing high-quality launch and release packages similar in tone and coherence to the Borgberry May 1 launch package.

The intended publication unit is:

1. a **private draft page** with the full package
2. a **private or unpublished announcement post** pointing to that page

This system should sit on top of the governance and authorship foundations rather than bypassing them.

## Why This Is A System Problem

Release packages are not just content pages.

They raise system-level questions:

- who authored this package?
- under what authority?
- what evidence supports the claims?
- what review happened before publication?
- what screenshots and diagrams are primary evidence?
- when is the package public versus still under review?

That means the workflow needs explicit support for:

- draft state
- review state
- author attribution
- evidence linking
- private-before-public publishing

## Target Workflow

### Draft creation

- create a private page for the release package
- build the narrative using blocks, screenshots, and diagrams
- keep the package hidden from the public until reviewed

### Announcement pairing

- create a shorter post that summarizes the release
- link the post to the full package page
- keep the post unpublished or private until package review is complete

### Review

- verify claims against implementation
- verify screenshots show the right user context
- verify diagram and PR links remain current
- verify the package reflects actual rollout state

### Publication

- publish page and post explicitly
- maintain clear authorship and audit history

## Quality Standard

The release package should:

- be visually intentional
- be legible to community members, not only engineers
- integrate diagrams and screenshots cleanly
- use plain language where possible
- preserve rollout honesty and implementation truthfulness

## Relationship To Other Systems

- **Community action network governance**
  - defines authority, review, and rights/duties context
- **Robot author identity**
  - enables truthful authorship where a robot is the writer
- **Agreements system**
  - may later support publication or review agreements where needed
- **Documentation and evidence systems**
  - supply screenshots, diagrams, and release proof

## Immediate Product Implications

The system suggests future product work in:

- content privacy and draft-state visibility
- richer review-state UX
- better longform release layouts
- page/post linkage patterns
- governed authorship and audit trails

## Current Status

This is currently a **documentation and design target**.

Community Engine can already compose strong pages and posts, but the dedicated private-draft release workflow and governed robot authorship layer are not yet implemented as a complete product feature.

