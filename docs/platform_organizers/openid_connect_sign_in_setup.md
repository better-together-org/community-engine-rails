# OpenID Connect Sign-In Setup

The `openid_connect` provider lets a platform offer sign-in through any standards-compliant OpenID Connect identity provider (Keycloak, Authentik, Zitadel, another Community Engine, and so on).

## Configure

1. In the identity provider, register a client with the redirect URI
   `https://<platform-domain>/users/auth/openid_connect/callback` for every platform domain that will use it.
2. In the host dashboard: Platforms, the platform, Sign-in providers, Add provider. Choose **OpenID Connect**, enter the **Issuer URL** (https only; the provider's `/.well-known/openid-configuration` is read from it), the client id and secret, and tick the domains it may serve.

There is no environment-variable fallback for this provider. A platform can have several OpenID Connect configurations, one per issuer: adding the same issuer twice is refused (the URL is normalised first, so `https://IDP.example.org/` and `https://idp.example.org` are the same issuer). The issuer cannot be changed after the configuration is created, because people's identities are tied to it; delete the configuration and add a new one instead.

Each configuration has an optional **Button label** (default: the issuer host). A domain that allows several issuers shows one sign-in button per issuer, and Settings > Integrations lets a person connect each issuer separately.

## Behaviour

- Authorization code flow with PKCE; scopes `openid email profile` (editable per row).
- Domain scoping and per-platform identities work as for every other provider.
- An identity is the issuer plus the provider's `sub`, per platform. Two issuers that happen to issue the same `sub` are different identities.
- Which issuer a sign-in uses is chosen when the person clicks its button and remembered for that callback only. A request or callback that does not name an issuer the domain allows is refused when the domain has more than one issuer.
- An existing account is linked only when the configuration ticks **Trust this issuer's verified emails** (off by default) and the provider asserts `email_verified` for the address. Only tick it for identity providers that verify email addresses: they decide which addresses count as verified. Otherwise no link is made and new accounts require email confirmation.
- The issuer is validated at save time (https, no private or reserved addresses).
