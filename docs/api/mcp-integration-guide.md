# MCP Integration Guide

Better Together exposes a [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server via [fast-mcp](https://github.com/yjacquin/fast-mcp), enabling AI assistants to interact with the platform using the user's permissions.

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_ENABLED` | `true` in development | Enable/disable MCP endpoints |
| `MCP_AUTH_TOKEN` | — | Shared token for MCP requests (required in production) |
| `MCP_PATH_PREFIX` | `/mcp` | URL prefix for MCP endpoints |

For user-scoped access via OAuth, clients must request the `mcp_access` scope (trusted applications only).

---

## Transports

| Transport | Endpoint | Use case |
|-----------|----------|---------|
| HTTP + SSE | `GET /mcp/sse` | Long-lived streaming (Claude Desktop, Cursor) |
| Messages | `POST /mcp/messages` | Single-request tool calls |
| STDIO | CLI process | Local development / CLI agents |

---

## Authentication

**Shared token** — set `MCP_AUTH_TOKEN` and pass as `Authorization: Bearer TOKEN` header.

**OAuth user context** — clients with a valid Doorkeeper token (`mcp_access` scope) pass it as:

```
Authorization: Bearer OAUTH_ACCESS_TOKEN
```

All tool executions are scoped to the authenticated user's Pundit policies automatically.

---

## Available Tools

### Community Tools

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `list_communities` | List accessible communities | `read` |
| `search_geography` | Search by geographic region | `read` |

### People Tools

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `search_people` | Search people by name/handle | `read_people` |
| `application_tool` | Get application context | `read` |

### Event Tools

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `list_events` | List upcoming events | `read_events` |
| `get_event_detail` | Get full event details | `read_events` |
| `create_event` | Create a new event | `write_events` |
| `list_invitations` | List event invitations | `read_events` |

### Content Tools

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `list_pages` | List platform pages | `read` |
| `search_posts` | Search posts | `read_posts` |
| `get_post` | Get post by ID or slug | `read_posts` |
| `create_post` | Create a new post | `write_posts` |
| `list_uploads` | List uploaded files | `read` |

### Messaging Tools

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `list_conversations` | List user conversations | `read_conversations` |
| `send_message` | Send a message to a conversation | `write_conversations` |
| `list_notifications` | List unread notifications | `read` |

### Marketplace Tools

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `list_offers` | List resource offers | `read` |
| `list_requests` | List resource requests | `read` |

### Navigation & Metrics

| Tool | Description | Required Scope |
|------|-------------|---------------|
| `manage_navigation` | Read/update navigation items | `admin` |
| `get_metrics_summary` | Platform metrics summary | `read_metrics` |

---

## Privacy Scoping

All tools automatically apply Pundit policies:

- **Privacy concern** — public/private content filtered by membership
- **Blocked users** — excluded from Person and Post scopes
- **Community access** — private communities require active membership
- **Role-based** — admin-level tools require trusted OAuth app context

---

## Example: Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "better-together": {
      "url": "https://yourplatform.example.com/mcp/sse",
      "headers": {
        "Authorization": "Bearer YOUR_MCP_AUTH_TOKEN"
      }
    }
  }
}
```

---

## Example Tool Call

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "list_events",
    "arguments": {
      "community_id": "abc123",
      "limit": 10
    }
  }
}
```
