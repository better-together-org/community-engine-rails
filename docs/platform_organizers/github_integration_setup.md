# GitHub Integration Setup for Platform Organizers

This guide explains how to set up and configure GitHub OAuth integration for your Better Together platform instance.

## Prerequisites

- A GitHub account
- Access to your platform's environment configuration
- Administrative access to your Better Together instance

## Setup Steps

### 1. Create a GitHub OAuth App

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Fill in the application details:
   - **Application name**: Your Platform Name (e.g., "My Community Platform")
   - **Homepage URL**: `https://yourdomain.com`
   - **Authorization callback URL**: `https://yourdomain.com/users/auth/github/callback`
4. Click "Register application"
5. Note your **Client ID** and generate a **Client Secret**

### 2. Configure Environment Variables

Add these environment variables to your platform configuration:

```bash
# GitHub OAuth Configuration
GITHUB_CLIENT_ID=your_github_client_id_here
GITHUB_CLIENT_SECRET=your_github_client_secret_here
```

For Dokku deployments:
```bash
dokku config:set your-app-name GITHUB_CLIENT_ID=your_github_client_id_here
dokku config:set your-app-name GITHUB_CLIENT_SECRET=your_github_client_secret_here
```

### 3. Restart Your Application

After adding the environment variables, restart your application:

```bash
# For Dokku
dokku ps:restart your-app-name

# For Docker
docker-compose restart

# For Systemd
systemctl restart your-app-name
```

### 4. Verify the Integration

1. Navigate to your platform's sign-in page
2. Look for the "Sign in with GitHub" button
3. Click it to test the OAuth flow
4. You should be redirected to GitHub for authorization
5. After approving, you'll be redirected back to your platform

## User Experience

### For End Users

Users can:
- **Sign in** with their GitHub account
- **Link** their GitHub account to an existing platform account
- **Access GitHub data** through platform features that use the GitHub API

### Sign-In Flow

1. User clicks "Sign in with GitHub"
2. Redirected to GitHub to authorize the app
3. After approval, redirected back to platform
4. If new user:
   - Account is created automatically
   - User completes required agreements
   - Profile is populated with GitHub data (name, handle, avatar)
5. If existing user:
   - GitHub account is linked to existing account
   - Access tokens are stored for API access

## OAuth Scopes

The default configuration requests these GitHub scopes:

- `user` - Read user profile information
- `user:email` - Access user email addresses

To request additional scopes, update your OmniAuth initializer:

```ruby
# config/initializers/omniauth.rb or your host app configuration
provider :github,
         ENV.fetch('GITHUB_CLIENT_ID'),
         ENV.fetch('GITHUB_CLIENT_SECRET'),
         scope: 'user,repo'  # Add 'repo' for repository access
```

Available scopes:
- `repo` - Full access to public and private repositories
- `read:org` - Read organization membership
- `gist` - Create gists
- See [GitHub OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)

## Security Considerations

### Token Storage

- OAuth tokens are **encrypted at rest** using Rails Active Record Encryption
- Tokens are stored per-user in the `person_platform_integrations` table
- Tokens are never exposed in logs or URLs

### Privacy Policy

**Important**: You must disclose GitHub OAuth integration in your privacy policy:

> "When you connect your GitHub account, we store your GitHub access token (encrypted) 
> to enable GitHub features. We collect your public GitHub profile information including 
> your username, name, email, and avatar. This data is used to enhance your platform 
> profile and enable GitHub-related features."

### User Data

Data collected from GitHub:
- Username (handle)
- Display name
- Email address
- Profile picture URL
- Public profile information

### Token Expiration

- GitHub OAuth tokens typically do not expire unless revoked
- Users can revoke access at any time from their [GitHub settings](https://github.com/settings/applications)
- Revoked tokens will cause API calls to fail - users must reconnect their accounts

## Troubleshooting

### "Could not authenticate you from GitHub"

**Causes:**
- Client ID or Client Secret incorrect
- Callback URL mismatch
- GitHub OAuth app not approved

**Solutions:**
1. Verify environment variables are correct
2. Check callback URL matches exactly (including protocol: `https://`)
3. Ensure OAuth app is active in GitHub

### "This integration is not for GitHub" Error

**Cause:** Trying to use GitHub API methods on a non-GitHub integration

**Solution:** Always check integration type:
```ruby
if integration&.github?
  github_client = integration.github_client
else
  # Handle missing or wrong integration type
end
```

### Missing OAuth Button

**Causes:**
- Environment variables not set
- Application not restarted after configuration
- OmniAuth not properly configured

**Solutions:**
1. Verify `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` are set
2. Restart the application
3. Check `config/initializers/devise.rb` or OmniAuth configuration

## Managing User Integrations

### Viewing Connected Accounts

As a platform organizer, you can view which users have connected GitHub accounts:

```ruby
# In Rails console
BetterTogether::PersonPlatformIntegration.github.count
# => Number of GitHub integrations

# List all users with GitHub connected
BetterTogether::PersonPlatformIntegration.github.includes(:person).map(&:person)
```

### Revoking Access

Users can disconnect their GitHub accounts from Settings > Integrations. When they do:
- The `PersonPlatformIntegration` record is deleted
- All stored tokens are permanently removed
- User can reconnect at any time

## Advanced: Using the GitHub API

The platform can make API calls to GitHub on behalf of users who have connected their accounts. See the [GitHub API Integration Guide](../developers/github_api_integration.md) for developer documentation.

### Example Use Cases

- Display user's GitHub repositories
- Show contribution activity
- List organizations
- Create issues or pull requests (with appropriate scopes)

## Monitoring

### Check Integration Health

```ruby
# Count active GitHub integrations
BetterTogether::PersonPlatformIntegration.github.count

# Check for expired tokens (if applicable)
BetterTogether::PersonPlatformIntegration.github.where('expires_at < ?', Time.current).count
```

### Rate Limiting

GitHub has API rate limits:
- **5,000 requests/hour** for authenticated users
- Check current limits: [GitHub Rate Limits](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)

Platform features using the GitHub API should implement:
- Response caching
- Rate limit checking
- Graceful error handling

## Disabling GitHub Integration

To remove GitHub OAuth:

1. Remove environment variables:
   ```bash
   dokku config:unset your-app-name GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET
   ```

2. Restart the application

3. The "Sign in with GitHub" button will no longer appear

**Note**: Existing `PersonPlatformIntegration` records will remain in the database but will not be usable.

## Support Resources

- [GitHub OAuth Documentation](https://docs.github.com/en/apps/oauth-apps)
- [Better Together OAuth Integration Assessment](../oauth_integration_assessment.md)
- [GitHub API Integration Guide (Developers)](../developers/github_api_integration.md)
- [External Services Configuration](../production/external-services-to-configure.md)

## Questions?

If you encounter issues:
1. Check application logs for OAuth errors
2. Verify environment variables are set correctly
3. Test with a fresh GitHub account
4. Contact the development team if problems persist
