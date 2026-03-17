# Webhook Integration Guide

Better Together delivers real-time event notifications to your HTTP endpoints via signed webhooks.

---

## Overview

When platform events occur (community created, post published, etc.), Better Together sends an HTTP `POST` to each registered, active webhook endpoint subscribed to that event.

**Delivery guarantees:**
- At-least-once delivery (retries up to 3 times with exponential backoff)
- Each delivery is recorded as a `WebhookDelivery` with full request/response audit trail

---

## Registering an Endpoint

### Personal endpoints (Settings)

1. Sign in → **Settings → Developer → Webhooks**
2. Click **New Endpoint**
3. Enter your URL, select events, and save
4. A signing secret is automatically generated (store it — it's shown once)

Route: `GET /settings/applications` (link to webhooks coming in the Developer tab)

### Community endpoints (Community settings)

Community admins can register webhooks scoped to community events:

`GET /c/:community_id/webhook_endpoints/new`

### Platform-wide endpoints (Host dashboard)

Platform managers: `GET /host/webhook_endpoints`

---

## Endpoint URL Requirements

- Must be `https://` (or `http://` in development/test)
- Must resolve to a publicly routable IP address (no RFC-1918 IPs in production)
- Must respond with HTTP 2xx within 30 seconds

---

## Event Types

Events follow the pattern `resource_type.action` (e.g. `community.created`).

| Event | Triggered when |
|-------|---------------|
| `community.created` | A new community is created |
| `community.updated` | A community's attributes change |
| `community.destroyed` | A community is deleted |
| `post.created` | A new post is published |
| `post.updated` | A post is edited |
| `post.destroyed` | A post is removed |
| `event.created` | A new calendar event is created |
| `event.updated` | A calendar event is updated |
| `event.destroyed` | A calendar event is deleted |
| `webhook.test` | Triggered manually via the "Test" button |

**Wildcard subscription:** Leave the events field empty to receive all events.

---

## Payload Format

```json
{
  "event": "community.created",
  "timestamp": "2026-02-27T04:00:00Z",
  "data": {
    "id": "abc123",
    "type": "community",
    "attributes": {
      "name": "Tech Collective",
      "slug": "tech-collective",
      "privacy": "public"
    }
  }
}
```

---

## Delivery Headers

| Header | Value |
|--------|-------|
| `Content-Type` | `application/json` |
| `X-BT-Webhook-Event` | Event name (e.g. `community.created`) |
| `X-BT-Webhook-Signature` | HMAC-SHA256 hex digest |
| `X-BT-Webhook-Timestamp` | ISO8601 delivery timestamp |
| `X-BT-Webhook-Delivery-Id` | UUID of the delivery record |

---

## Verifying Signatures

Each delivery is signed with `HMAC-SHA256`. The signature covers the timestamp and body:

```
signature = HMAC-SHA256(secret, "#{timestamp}.#{body}")
```

**Ruby verification example:**

```ruby
def valid_webhook?(request, secret)
  signature = request.headers['X-BT-Webhook-Signature']
  timestamp  = request.headers['X-BT-Webhook-Timestamp']
  body       = request.raw_post

  expected = OpenSSL::HMAC.hexdigest('sha256', secret, "#{timestamp}.#{body}")
  ActiveSupport::SecurityUtils.secure_compare(expected, signature)
end
```

**Node.js verification example:**

```javascript
const crypto = require('crypto');

function isValidWebhook(req, secret) {
  const signature = req.headers['x-bt-webhook-signature'];
  const timestamp  = req.headers['x-bt-webhook-timestamp'];
  const body       = JSON.stringify(req.body);
  const expected   = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${body}`)
    .digest('hex');
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
}
```

**Reject deliveries if:**
- Signature verification fails
- Timestamp is more than 5 minutes old (replay attack protection)

---

## Retry Policy

| Attempt | Delay |
|---------|-------|
| 1 | Immediate |
| 2 | ~30s |
| 3 | ~5min |

After 3 failures, the delivery is marked `failed`. The endpoint remains active — fix your handler and use the **Test** button to re-verify.

---

## Testing Deliveries

Send a `webhook.test` event from the endpoint's show page:

```
POST /host/webhook_endpoints/:id/test
POST /c/:community_id/webhook_endpoints/:id/test
```

This queues a `WebhookDelivery` with a test payload immediately.

---

## Delivery Audit Log

Each delivery is persisted with:
- `event` — event name
- `payload` — JSON payload sent
- `status` — `pending`, `delivered`, `failed`
- `response_code` — HTTP status from your server
- `response_body` — first 1000 chars of response
- `delivered_at` — timestamp on success
