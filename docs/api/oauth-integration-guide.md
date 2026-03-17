# OAuth 2.0 Integration Guide

Better Together provides OAuth 2.0 via [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper), supporting both user-facing authorization flows and machine-to-machine access.

---

## Overview

| Concept | Value |
|---------|-------|
| Authorization endpoint | `GET /oauth/authorize` |
| Token endpoint | `POST /oauth/token` |
| Token introspect endpoint | `POST /oauth/introspect` |
| Token revoke endpoint | `POST /oauth/revoke` |
| Grant flows | `authorization_code`, `client_credentials` |
| Default scope | `read` |

---

## Registering an OAuth Application

### As a user (personal apps)

1. Sign in and navigate to **Settings → Developer**
2. Click **New Application**
3. Fill in name, redirect URI(s), and select scopes
4. Save — note your **Client ID** (`uid`) and **Client Secret**

Route: `GET /settings/applications/new`

### As a platform manager (all apps)

Navigate to **Host Dashboard → OAuth Applications** (`/host/oauth_applications`).

---

## Scopes

| Scope | Description | Trusted-only? |
|-------|-------------|--------------|
| `read` | Default — read public resources | No |
| `write` | Write access to owned resources | No |
| `read_communities` | List and read communities | No |
| `write_communities` | Create/update communities | No |
| `read_people` | Read person profiles | No |
| `read_events` | Read events | No |
| `write_events` | Create/update events | No |
| `read_posts` | Read posts | No |
| `write_posts` | Create/update posts | No |
| `read_conversations` | Read conversations | No |
| `write_conversations` | Send messages | No |
| `read_metrics` | Access metrics data | No |
| `write_metrics` | Record metrics | No |
| `admin` | Full admin access | **Yes** |
| `mcp_access` | MCP tool invocation | **Yes** |

**Trusted-only scopes** (`admin`, `mcp_access`) are only granted to applications whose owner can `manage_platform`. Regular user OAuth apps cannot request these scopes.

---

## Authorization Code Flow (user-facing integrations)

**Step 1 — Redirect user to authorization endpoint:**

```
GET /oauth/authorize
  ?response_type=code
  &client_id=YOUR_CLIENT_ID
  &redirect_uri=https://yourapp.example.com/callback
  &scope=read+write_posts
  &state=RANDOM_CSRF_TOKEN
```

**Step 2 — Exchange code for token:**

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=AUTHORIZATION_CODE
&redirect_uri=https://yourapp.example.com/callback
&client_id=YOUR_CLIENT_ID
&client_secret=YOUR_CLIENT_SECRET
```

Response:

```json
{
  "access_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 7200,
  "refresh_token": "...",
  "scope": "read write_posts",
  "created_at": 1709000000
}
```

---

## Client Credentials Flow (machine-to-machine)

Used for server-to-server integrations without a user context.

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=YOUR_CLIENT_ID
&client_secret=YOUR_CLIENT_SECRET
&scope=read
```

---

## Using a Token

Include the Bearer token in all API requests:

```http
GET /api/v1/communities
Authorization: Bearer YOUR_ACCESS_TOKEN
```

---

## Revoking a Token

```http
POST /oauth/revoke
Content-Type: application/x-www-form-urlencoded

token=ACCESS_TOKEN
&client_id=YOUR_CLIENT_ID
&client_secret=YOUR_CLIENT_SECRET
```

---

## GitHub Social Login (OmniAuth)

Users can sign in with GitHub. The platform must be configured with:

```
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
```

The callback is handled at `/users/auth/github/callback`. On first login:
- A `BetterTogether::OauthUser` record is created
- A `PersonPlatformIntegration` links the GitHub UID to the user
- Community membership is created automatically

Users who signed up via GitHub can later set a password in Settings to convert to a standard account.

---

## Error Responses

OAuth errors follow RFC 6749 format:

```json
{
  "error": "invalid_grant",
  "error_description": "The provided authorization grant is invalid, expired, revoked..."
}
```

Common errors:

| Error | Meaning |
|-------|---------|
| `invalid_client` | Wrong client_id or client_secret |
| `invalid_grant` | Authorization code expired/used |
| `invalid_scope` | Requested scope not permitted |
| `access_denied` | User denied authorization |
| `unauthorized_client` | Client not allowed to use this grant type |
