# Google Sign-In Setup

Google sign-in uses the `google_oauth2` provider. Sign-in is valid only on platform domains the provider configuration is allowed to serve; there is no fallback to another platform's configuration.

## 1. Create the Google OAuth client

1. In Google Cloud Console, create an OAuth 2.0 Client ID (type **Web application**).
2. Add one **Authorized redirect URI** for every platform domain that will offer Google sign-in:
   `https://<domain>/users/auth/google_oauth2/callback`
3. Set the consent screen's publishing status to **Production**. The scopes used (`openid`, `email`, `profile`) need no Google verification.

## 2. Configure the platform

- **Host platform (environment):** set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`. These apply to the host platform's own domains only.
- **Any platform (database):** Host dashboard, Platforms, the platform, Sign-in providers, Add provider. Choose Google, enter the client id and secret, and tick the domains it may serve. A hosted platform may share the host's configuration only if its domain is ticked and its callback URL is registered with Google (step 1).

A provider row, once it lists a domain, takes over that domain from the environment. A disabled row refuses sign-in on its domains.

## Behaviour

- Scope requested: `email,profile`.
- An existing account is linked only when Google asserts `email_verified`. An unverified or missing assertion never links to an existing account, and a new account then requires normal email confirmation.
- Google identities are matched per platform: the same Google account is a separate identity on each platform.
- Optional provider options (for example `hd` to restrict to a Google Workspace domain) can be stored in the row's options.
