# Facebook Sign-In Setup

Facebook sign-in uses the `facebook` provider.

## 1. Create the Meta app

1. In the Meta developer console, create an app with the **Facebook Login** product.
2. Add a **Valid OAuth Redirect URI** for every platform domain that will offer it:
   `https://<domain>/users/auth/facebook/callback`
3. Request the `email` permission (standard access is enough for `email` and `public_profile`), then switch the app to **Live** mode.

## 2. Configure the platform

- **Host platform (environment):** set `FACEBOOK_CLIENT_ID` (the app id) and `FACEBOOK_CLIENT_SECRET`. These apply to the host platform's own domains only.
- **Any platform (database):** Host dashboard, Platforms, the platform, Sign-in providers, Add provider. Choose Facebook, enter the app id and secret, and tick the domains it may serve.

## Behaviour

- Scopes requested: `email,public_profile`.
- Facebook does not assert that an email address is verified, so it is **never** used to link to an existing account. A person who already has an account must sign in and connect Facebook from Settings.
- A new person who signs in with Facebook gets an account that must be confirmed through the normal confirmation email before they can sign in; no Facebook identity is stored until then.
- If Facebook returns no email (the person declined the permission or has no email on the account), no account is created and the person is told to make an email available.
- Domain scoping and per-platform identities work as for every other provider.
