# frozen_string_literal: true

# Helpers for MCP tool and resource specs
# Provides methods to stub Warden-based request context for FastMcp tools/resources
module McpTestHelpers
  # Build a Rack::Request double with Warden session for the given user
  # @param user [User, nil] The authenticated user (nil for anonymous)
  # @return [Rack::Request] Double with Warden env configured
  def build_mcp_request(user: nil)
    warden = instance_double(Warden::Proxy, user: user)
    request = instance_double(Rack::Request, env: { 'warden' => warden })
    allow(request).to receive(:respond_to?).with(:env).and_return(true)
    request
  end

  # Stub an MCP tool/resource class to use Warden-based auth with the given user.
  #
  # NOTE: allow_any_instance_of is intentional here. FastMcp instantiates tool and
  # resource classes internally during request handling — we cannot obtain a reference
  # to the instance before `call`/`content` is invoked. This is the only reliable way
  # to inject a Warden-backed request into the tool/resource under test.
  #
  # @param klass [Class] The tool or resource class
  # @param user [User, nil] The authenticated user
  def stub_mcp_request_for(klass, user:)
    request = build_mcp_request(user: user)
    allow_any_instance_of(klass).to receive(:request).and_return(request) # rubocop:disable RSpec/AnyInstance
  end
end

RSpec.configure do |config|
  config.include McpTestHelpers, type: :model
  config.include McpTestHelpers, file_path: %r{spec/tools}
  config.include McpTestHelpers, file_path: %r{spec/resources}
  config.include McpTestHelpers, file_path: %r{spec/lib/better_together/mcp}
end
