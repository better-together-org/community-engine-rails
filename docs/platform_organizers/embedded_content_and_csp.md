# Embedded Content and CSP Controls

**Target Audience:** Platform organizers and trusted content authors  
**Document Type:** Administrator Guide  
**Last Updated:** March 2026

## Overview

Community Engine `0.11.0` adds a safer embedded-content workflow for iframes and hosted video. Instead of weakening the platform-wide Content Security Policy (CSP) globally, organizers can explicitly allow trusted origins and let content authors use embed blocks that fail visibly when an origin is not approved.

This is especially useful for services such as:

- `https://www.youtube.com`
- `https://www.youtube-nocookie.com`
- `https://forms.btsdev.ca`
- `https://player.vimeo.com`

## What changed in 0.11.0

The release lane adds:

- a dedicated `IframeBlock` for arbitrary HTTPS embeds
- a shared rendering path for iframe and video blocks
- blocked-state fallback messaging when an origin is not allowed
- host-platform settings for `frame-src`, `frame-ancestors`, and `img-src`
- cache separation by request host and resolved embed-policy context

## Why this matters

Embedded content can fail for two different reasons:

1. the remote service refuses to be embedded
2. your platform CSP blocks the embed origin

The new workflow makes the second case manageable without silently rendering a broken or blank block.

## Organizer workflow

### 1. Decide which origins are trusted

Only allow origins you are comfortable embedding into community pages. Review each origin for:

- privacy and tracking implications
- moderation risk
- long-term governance fit for your platform

### 2. Configure the host platform allowlists

Open the host platform settings and update the CSP origin lists.

Use one HTTPS origin per line. Avoid wildcards unless you have a clear governance reason to trust an entire provider surface.

#### `frame-src`

Controls which remote origins Community Engine is allowed to embed inside iframes.

Examples:

- `https://www.youtube.com`
- `https://player.vimeo.com`
- `https://forms.btsdev.ca`

#### `frame-ancestors`

Controls which parent origins are allowed to embed **your** Community Engine pages.

Use this when you intentionally want CE pages to appear inside another trusted shell or application frame.

#### `img-src`

Controls which remote origins can serve images inside the page.

This matters when an embedded or related UI path loads images from a third-party asset domain.

## Author workflow

After an organizer allows the relevant origins:

1. add an `IframeBlock` or `VideoBlock` to the page
2. paste the HTTPS embed URL
3. set an appropriate title and caption
4. preview the block

If the origin is still blocked, the page will show a visible fallback with an “open in new tab” path instead of a silent failure.

## Governance recommendations

- prefer a short allowlist over permissive defaults
- document why each origin is trusted
- review embed providers during privacy and safety audits
- test embeds on the actual host platform after changing CSP settings

## Troubleshooting

### The block shows a fallback notice

Check whether the embed origin is present in the host platform `frame-src` settings.

### The remote service still refuses to render

Some providers send their own `X-Frame-Options` or CSP headers that prevent embedding even when Community Engine allows the origin. In that case, use the fallback link or choose a provider-supported embed URL.

### The page works on one host but not another

`0.11.0` varies embed cache keys by request host and resolved frame-source context. If behavior still differs across hosts, compare each host platform’s CSP settings rather than assuming the cached fragment is shared.
