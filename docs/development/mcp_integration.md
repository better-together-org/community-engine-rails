# Model Context Protocol (MCP) Integration

## Overview

The Better Together Community Engine integrates the [Fast MCP](https://github.com/yjacquin/fast-mcp) gem to enable AI model interactions while respecting platform privacy settings and authorization policies.

**Key Features:**
- ✅ Privacy-aware data access using existing Pundit policies
- ✅ Automatic filtering by user permissions and blocked users
- ✅ Rails-friendly naming conventions (ActionTool::Base, ActionResource::Base)
- ✅ Secure authentication with token-based auth
- ✅ HTTP/SSE and STDIO transports supported

## Architecture

### Core Components

1. **PunditContext** (`lib/better_together/mcp/pundit_context.rb`)
   - Wraps User for Pundit authorization compatibility
   - Extracts user from request parameters
   - Provides `permitted_to?` delegation to Person

2. **ApplicationTool** (`app/tools/application_tool.rb`)
   - Base class for all MCP tools (namespaced: `BetterTogether::Mcp::ApplicationTool`)
   - Includes Pundit::Authorization
   - Includes TimezoneScoped for consistent timezone handling
   - Provides `current_user`, `agent`, `authorize`, `policy_scope`, `with_timezone_scope`
   - Alias: `BetterTogether::ActionTool::Base`

3. **ApplicationResource** (`app/resources/application_resource.rb`)
   - Base class for all MCP resources (namespaced: `BetterTogether::Mcp::ApplicationResource`)
   - Includes Pundit::Authorization
   - Includes TimezoneScoped for consistent timezone handling
   - Provides same helpers as ApplicationTool
   - Alias: `BetterTogether::ActionResource::Base`

4. **TimezoneScoped** (`app/models/concerns/better_together/timezone_scoped.rb`)
   - Unified timezone handling across controllers, mailers, jobs, and MCP
   - Priority hierarchy: explicit → recipient → user → platform → app config → UTC
   - Consistent timezone resolution for all time-sensitive operations

### Privacy Scoping

All tools and resources automatically respect:

- **Privacy concern** - Public/private filtering via ApplicationPolicy::Scope
- **User permissions** - Role-based access via Pundit policies
- **Blocked users** - Automatic exclusion in Post/Person scopes
- **Community membership** - Private community access requires membership

## Configuration

### Environment Variables

```bash
# Enable/disable MCP (default: true in development, false in production)
MCP_ENABLED=true

# Authentication token (required in production)
MCP_AUTH_TOKEN=your-secret-token-here

# URL path prefix (default: /mcp)
MCP_PATH_PREFIX=/mcp
```

### Initializer

The MCP server is configured in `config/initializers/fast_mcp.rb`:

```ruby
FastMcp.mount_in_rails(
  Rails.application,
  name: 'better-together',
  version: BetterTogether::VERSION,
  path_prefix: '/mcp',
  authenticate: true,  # Requires auth token
  auth_token: ENV['MCP_AUTH_TOKEN']
)
```

## Creating Tools

### Basic Tool Example

```ruby
# app/tools/list_communities_tool.rb
module BetterTogether
  module Mcp
    class ListCommunitiesTool < ApplicationTool
      description 'List communities accessible to the current user'

      arguments do
        optional(:privacy_filter)
          .filled(:string)
          .description('Filter by privacy level')
      end

      def call(privacy_filter: nil)
        # Executes in user's timezone context
        with_timezone_scope(user: current_user) do
          # Uses policy_scope - automatically filters by privacy & permissions
          communities = policy_scope(BetterTogether::Community)
          communities = communities.where(privacy: privacy_filter) if privacy_filter

          JSON.generate(
            communities.map { |c| { id: c.id, name: c.name } }
          )
        end
      end
    end
  end
end
```

### Tool with Authorization Check

```ruby
module BetterTogether
  module Mcp
    class GetCommunityDetailsTool < ApplicationTool
      description 'Get detailed information about a specific community'

      arguments do
        required(:community_id).filled(:string)
      end

      def call(community_id:)
        with_timezone_scope(user: current_user) do
          community = BetterTogether::Community.find(community_id)
          
          # Explicit authorization check - raises Pundit::NotAuthorizedError if denied
          authorize community, :show?
          
          JSON.generate(serialize_community(community))
        end
      end
    end
  end
end
```

module BetterTogether
  module Mcp
    class PublicCommunitiesResource < ApplicationResource
      uri 'bettertogether://communities/public'
      resource_name 'Public Communities'
      mime_type 'application/json'

      def content
        with_timezone_scope(user: current_user) do
          # Uses policy_scope for privacy filtering
          communities = policy_scope(BetterTogether::Community)
            .where(privacy: 'public')

          JSON.generate({
            communities: communities.map { |c| serialize(c) }
          })
        end
      end
    endUses policy_scope for privacy filtering
    communities = policy_scope(BetterTogether::Community)
      .where(privacy: 'public')

    JSON.generate({
      communities: communities.map { |c| serialize(c) }
    })
  end
module BetterTogether
  module Mcp
    class CommunityResource < ApplicationResource
      uri 'bettertogether://communities/{id}'
      resource_name 'Community'
      mime_type 'application/json'

      def content
        with_timezone_scope(user: current_user) do
          # params[:id] comes from URI pattern
          community = BetterTogether::Community.find(params[:id])
          authorize community, :show?

          JSON.generate(serialize_community(community))
        end
      end
    end
  def content
    # params[:id] comes from URI pattern
    community = BetterTogether::Community.find(params[:id])
    authorize community, :show?

    JSON.generate(serialize_community(community))
  end
end
```
BetterTogether::Mcp::ListCommunitiesTool do
  let(:user) { create(:user) }
  let!(:public_community) { create(:community, privacy: 'public') }
  let!(:private_community) { create(:community, privacy: 'private') }

  before do
    configure_host_platform
    user.person.update(time_zone: 'America/New_York')
    allow_any_instance_of(described_class)
      .to receive(:request)
      .and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
  end

  it 'filters communities by privacy' do
    tool = described_class.new
    result = tool.call

    communities = JSON.parse(result)
    expect(communities.length).to eq(1) # Only public
  end

  it 'uses user timezone for timestamps' do
    tool = described_class.new
    
    # Verify timezone context is applied
    expect(tool).to receive(:with_timezone_scope).with(user: user).and_call_original
    tool.call
  it 'filters communities by privacy' do
    tool = described_class.new
    result = tool.call

    communities = JSON.parse(result)
    expect(communities.length).to eq(1) # Only public
  end
end
```

## Using with AI Clients

### Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "better-together": {
      "command": "ruby",
      "args": [
        "-I/path/to/better-together/lib",
        "-rbetter_together/mcp",
        "/path/to/mcp_server.rb"
      ],
      "env": {
        "MCP_AUTH_TOKEN": "your-token-here",
        "DATABASE_URL": "postgresql://localhost/better_together_development"
      }
    }
  }
}
```

### HTTP/SSE Access

Make authenticated requests to the MCP endpoint:

```bash
# List available tools
curl -X POST http://localhost:3000/mcp/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": { "user_id": "123" }
  }'
```

## Privacy & Security

### Authorization Enforcement

1. **Tool execution** - Each tool inherits from ApplicationTool with Pundit
2. **Resource access** - Each resource uses policy_scope for data filtering
3. **Explicit checks** - Use `authorize record, :action?` for specific permissions
4. **Automatic filtering** - ApplicationPolicy::Scope filters by privacy, membership, blocks

### Privacy Levels

- **Public** - Accessible to all users (authenticated or not)
- **Private** - Only accessible to:
  - Record creator
  - Platform managers
  - Community members (for community-scoped records)

### Blocked Users

Posts and data from blocked users are automatically excluded via policy scopes.

## Example Tools & Resources

### Included Examples

**TNamespace under `BetterTogether::Mcp`
3. Inherit from `ApplicationTool` (or use alias `BetterTogether::ActionTool::Base`)
4. Define `description` and `arguments`
5. Implement `call` method using `with_timezone_scope`, `policy_scope` and `authorize`
6. Tool auto-registers on Rails initialization

**Example:**
```ruby
module BetterTogether
  module Mcp
    class YourTool < ApplicationTool
      description 'Your tool description'

      def call
        with_timezone_scope(user: current_user) do
          # Your logic here with proper timezone context
        end
      end
    end
  end
end
```

### Adding Custom Resources

1. Create file in `app/resources/your_resource.rb`
2. Namespace under `BetterTogether::Mcp`
3. Inherit from `ApplicationResource` (or use alias `BetterTogether::ActionResource::Base`)
4. Define `uri`, `resource_name`, `mime_type`
5. Implement `content` method using `with_timezone_scope` and `policy_scope`
6. Resource auto-registers on Rails initialization

**Example:**
```ruby
module BetterTogether
  module Mcp
    class YourResource < ApplicationResource
      uri 'bettertogether://your-resource'
      resource_name 'Your Resource'
      mime_type 'application/json'

      def content
        with_timezone_scope(user: current_user) do
          # Your logic here with proper timezone context
        end
   Timezone Handling

All MCP tools and resources include the `TimezoneScoped` concern for consistent timezone handling:

### Automatic Timezone Resolution

Priority hierarchy (first available wins):
1. Explicit timezone parameter
2. Recipient timezone (for targeted operations)
3. Current user timezone
4. Platform timezone
5. Application config timezone
6. UTC fallback

### Usage in Tools/Resources

```ruby
def call
  with_timezone_scope(user: current_user) do
    # All time operations use user's timezone
    time = Time.current  # In user's timezone
    event.starts_at.in_time_zone  # Converted to user's timezone
  end
end
```

### Benefits

- **Consistency**: Same timezone logic as controllers, mailers, and jobs
- **User Experience**: Timestamps displayed in user's preferred timezone
- **Platform Defaults**: Falls back to platform timezone when user has no preference
- **Testing**: Easy to test timezone-specific behavior

## Performance Considerations

- **Use policy_scope** - Filters at database level (efficient)
- **Avoid N+1 queries** - Use `.includes()` for associations
- **Limit results** - Cap list sizes (e.g., `limit(100)`)
- **Timezone scoping** - Minimal overhead, executed at Ruby level
4. Implement `call` method using `policy_scope` and `authorize`
5. Tool auto-registers on Rails initialization

### Adding Custom Resources

1. Create file in `app/resources/your_resource.rb`
2. Inherit from `ApplicationResource` (or `ActionResource::Base`)
3. Define `uri`, `resource_name`, `mime_type`
4. Implement `content` method using `policy_scope`
5. Resource auto-registers on Rails initialization

## Troubleshooting

### Tools not appearing

Check logs for registration messages:
```
MCP server initialized at /mcp
Registered tool: ListCommunitiesTool
```

### Authorization errors

Ensure `user_id` parameter is passed in MCP requests:
```json
{
  "params": {
    "user_id": "user-uuid-here"
  }
}
```

### Privacy filtering issues

Verify policy scope is being used:
```ruby
# Good
communities = policy_scope(BetterTogether::Community)

# Bad - bypasses authorization
communities = BetterTogether::Community.all
```

## Performance Considerations

- **Use policy_scope** - Filters at database level (efficient)
- **Avoid N+1 queries** - Use `.includes()` for associations
- **Limit results** - Cap list sizes (e.g., `limit(100)`)
- **Cache when possible** - Consider fragment caching for resources

## References

- [Fast MCP Documentation](https://github.com/yjacquin/fast-mcp)
- [MCP Specification](https://github.com/modelcontextprotocol)
- [Acceptance Criteria](docs/implementation/mcp_integration_acceptance_criteria.md)
- [Pundit Documentation](https://github.com/varvet/pundit)

## Development

### Running Tests

```bash
# Run all MCP-related tests
bin/dc-run bundle exec prspec spec/tools spec/resources spec/lib/better_together/mcp

# Run specific test
bin/dc-run bundle exec prspec spec/tools/list_communities_tool_spec.rb
```

### Testing with MCP Inspector

```bash
# Install inspector
npm install -g @modelcontextprotocol/inspector

# Test your server
npx @modelcontextprotocol/inspector path/to/your_mcp_server.rb
```

## Future Enhancements

- [ ] Pagination support for large datasets
- [ ] Real-time resource subscriptions
- [ ] Caching layer for frequently accessed resources
- [ ] Rate limiting per user
- [ ] Audit logging for AI interactions
- [ ] Multi-tenancy support
