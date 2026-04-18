# Membership Request System

This guide documents the membership-request flow that exists in Community Engine `0.11.0`.

## Overview

Membership requests let people ask to join a community through either:

- a public unauthenticated request flow
- an authenticated request flow for an already signed-in person

Relevant code paths:

- `app/models/better_together/joatu/membership_request.rb`
- `app/controllers/better_together/membership_requests_controller.rb`
- `app/controllers/better_together/api/v1/membership_requests_controller.rb`
- `app/resources/better_together/api/v1/membership_request_resource.rb`
- `app/policies/better_together/joatu/membership_request_policy.rb`

## Web routes

Community-scoped routes are defined under:

- `GET /c/:community_id/membership_requests`
- `GET /c/:community_id/membership_requests/new`
- `POST /c/:community_id/membership_requests`
- `GET /c/:community_id/membership_requests/:id`
- `DELETE /c/:community_id/membership_requests/:id`
- `POST /c/:community_id/membership_requests/:id/approve`
- `POST /c/:community_id/membership_requests/:id/decline`

The controller skips authentication only for `new` and `create`, so submission is public but management is not.

## Request model behavior

`BetterTogether::Joatu::MembershipRequest` is a specialized `Request` subtype with a few important rules:

- the target must be a `BetterTogether::Community`
- unauthenticated requests require `requestor_email`
- the request name is auto-generated from `requestor_name`, creator name, or email if needed
- every request is automatically assigned to the "Membership Requests" category

## Dual approval paths

The core behavior lives in `after_agreement_acceptance!` and `approve!`.

### 1. Unauthenticated visitor path

If the request has no `creator`:

1. the visitor submits a public membership request
2. a manager approves it
3. the model creates or reuses a `CommunityInvitation`
4. the visitor later registers or accepts through the invitation flow
5. membership is created from the invitation path

### 2. Authenticated person path

If the request has a `creator`:

1. a signed-in person submits the request
2. a manager approves it
3. the model creates or finds a `PersonCommunityMembership`
4. the request status is updated to fulfilled

See:

- [membership request lifecycle flow](../../diagrams/source/membership_request_lifecycle_flow.mmd)

## Status model

The current controller and model use three effective states:

- `open` for newly submitted requests
- `fulfilled` after approval
- `closed` after decline

`MembershipRequestsController#index` defaults to showing open requests unless a status filter is supplied.

## Authorization

`MembershipRequestPolicy` is intentionally asymmetric:

- `create?` is open to the public
- `approve?`, `decline?`, `destroy?`, and management reads are reserved for platform managers or community managers
- the creator of an authenticated request can read their own request when authenticated

The policy scope also allows community managers to see requests for communities they manage.

## Captcha hook

Both the HTML controller and the API controller expose a `validate_captcha_if_enabled?` hook. On this branch, the default implementation returns `true`, which means host applications are expected to override that hook if they want enforced captcha validation.

## JSON:API surface

The API layer exposes:

- `GET /api/v1/membership_requests`
- `GET /api/v1/membership_requests/:id`
- `POST /api/v1/membership_requests`
- `DELETE /api/v1/membership_requests/:id`

The create action is intentionally public. Read and destroy actions still depend on the authenticated API context.

`MembershipRequestResource` currently exposes:

- `requestor_name`
- `requestor_email`
- `referral_source`
- `target_type`
- `target_id`
- `description`

`description` is serialized as plain text for JSON consumers.

## What is not present

This branch does not include dedicated MCP tools for membership requests. Automation currently goes through:

- the HTML controller
- the JSON:API resource/controller
- the model and policy layer

There is also no anonymous self-serve tracking link in the controller flow after public submission. Public users get the success page, but later management remains authenticated and manager-scoped.
