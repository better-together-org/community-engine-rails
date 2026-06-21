# Robot Authored Page And Post Publishing

## Purpose

This slice introduces a narrow, truthful publishing workflow for robot-authored pages and posts.

The goal is not to redesign governed publishing. The goal is to make page and post authorship accurately represent either:

- one or more people
- one or more robots
- a mixed human and robot byline

## What This PR Changes

- `Authorship.author` becomes polymorphic for `Person` and `Robot`
- page and post forms allow explicit human and robot author selection
- page and post rendering uses governed authors instead of assuming a human-only byline
- creator fallback still works, but only when no explicit human or robot authors were selected

## Canonical Workflow

1. A platform manager opens the page or post form.
2. The editor can select one or more people, one or more robots, or both.
3. On create, explicit author selections are preserved as the authoritative byline.
4. If nothing was selected, the existing creator fallback adds the human creator as author.
5. Page and post surfaces render the governed byline truthfully.

## What This PR Does Not Change

- robots are not yet first-class `creator`s
- governed publishing agreements are not part of this PR
- citation, evidence, and contribution-role expansion are not part of this PR

Those belong to separate governance and evidence PRs and should not be reviewed as part of this narrow branch.

## Reviewer Focus

Review this PR for:

- schema correctness of polymorphic authorship
- create-path fallback behavior
- truthful rendering of robot-only and mixed bylines
- absence of broader governance scope drift

## Evidence

- flow diagram: [`pr_1496_robot_authored_page_post_flow.mmd`](../../diagrams/source/pr_1496_robot_authored_page_post_flow.mmd)
- screenshots:
  - [`robot_authored_page_form.png`](../../screenshots/desktop/robot_authored_page_form.png)
  - [`robot_authored_post_form.png`](../../screenshots/desktop/robot_authored_post_form.png)
  - [`robot_authored_page_show.png`](../../screenshots/desktop/robot_authored_page_show.png)
  - [`robot_authored_post_show.png`](../../screenshots/desktop/robot_authored_post_show.png)
