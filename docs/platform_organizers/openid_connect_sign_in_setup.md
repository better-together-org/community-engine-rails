# OpenID Connect Sign-In Setup

The `openid_connect` provider lets a platform offer sign-in through any standards-compliant OpenID Connect identity provider (Keycloak, Authentik, Zitadel, another Community Engine, and so on).

## Configure

1. In the identity provider, register a client with the redirect URI
   `https://<platform-domain>/users/auth/openid_connect/callback` for every platform domain that will use it.
2. In the host dashboard: Platforms, the platform, Sign-in providers, Add provider. Choose **OpenID Connect**, enter the **Issuer URL** (https only; the provider's `/.well-known/openid-configuration` is read from it), the client id and secret, and tick the domains it may serve.

There is no environment-variable fallback for this provider. Each platform has at most one OpenID Connect configuration, so different platforms (and their domains) can use different identity providers.

## Behaviour

- Authorization code flow with PKCE; scopes `openid email profile` (editable per row).
- Domain scoping and per-platform identities work as for every other provider.
- An existing account is linked only when the provider asserts `email_verified` for the address. Only configure identity providers you trust: they decide which addresses are verified. Without that assertion no link is made and new accounts require email confirmation.
- The issuer is validated at save time (https, no private or reserved addresses).
