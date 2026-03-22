# JWT Authentication Guide

Better Together's REST API supports two authentication methods:

1. **Devise JWT** — short-lived tokens for interactive user sessions
2. **Doorkeeper OAuth2 bearer tokens** — for long-lived and server-to-server access (recommended for integrations)

Most integrations should prefer OAuth2 bearer tokens. Devise JWT is intended for same-session API calls (SPAs, mobile clients).

---

## Doorkeeper OAuth2 (Recommended)

See the [OAuth Integration Guide](oauth-integration-guide.md) for the full authorization code and client credentials flows.

**TL;DR — obtain a bearer token:**

```bash
# Authorization Code flow — exchange code for token
POST /oauth/token
{
  "grant_type": "authorization_code",
  "code": "AUTHORIZATION_CODE",
  "redirect_uri": "https://yourapp.example.com/callback",
  "client_id": "YOUR_CLIENT_ID",
  "client_secret": "YOUR_CLIENT_SECRET"
}

# Use it:
Authorization: Bearer DOORKEEPER_ACCESS_TOKEN
```

---

## Devise JWT

Devise JWT tokens are issued on sign-in via the API auth endpoint. They expire in **1 hour** and are revoked on sign-out.

### Sign In

```bash
POST /api/auth/sign-in
Content-Type: application/json

{
  "user": {
    "email": "alice@example.com",
    "password": "secret"
  }
}
```

**Response headers** (token is in the header, not the body):

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

Store the `Authorization` header value — this is your JWT.

### Using the JWT

Pass it in every subsequent API request:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

### Sign Out (Revoke Token)

```bash
DELETE /api/auth/sign-out
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

After sign-out, the token is added to the revocation list and can no longer be used.

---

## Token Claims

| Claim | Value |
|-------|-------|
| `sub` | User ID (UUID) |
| `jti` | Unique token identifier (for revocation) |
| `iat` | Issued at (Unix timestamp) |
| `exp` | Expires at (`iat + 3600`) |

---

## Choosing Between JWT and OAuth2

| Scenario | Recommended |
|----------|-------------|
| SPA or mobile app (interactive login) | Devise JWT |
| Third-party integration (server-to-server) | OAuth2 client credentials |
| User-delegated access from third-party app | OAuth2 authorization code |
| MCP / AI agent access | OAuth2 (`mcp_access` scope) |
| Webhook signing verification | HMAC-SHA256 (see Webhook Guide) |

---

## Configuration (Host Apps)

Set `DEVISE_SECRET` in production to a stable, randomly generated secret independent of `secret_key_base`:

```bash
rails secret  # generate a new secret
# Set DEVISE_SECRET=<output> in .env or Dokku config
```

If `DEVISE_SECRET` is unset, the app falls back to `devise_jwt_secret_key` in `credentials.yml.enc`, then `secret_key_base`. Rotating `secret_key_base` without setting an independent `DEVISE_SECRET` will invalidate all active JWT sessions.

---

## Error Responses

| Status | Meaning |
|--------|---------|
| 401 Unauthorized | Token missing, expired, revoked, or signature invalid |
| 403 Forbidden | Token valid but missing required OAuth scope |

```json
{
  "errors": [{
    "status": "401",
    "title": "Unauthorized",
    "detail": "The access token is invalid, expired, or revoked."
  }]
}
```
