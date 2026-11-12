# frozen_string_literal: true

# SafeOutboundHost resolves hostnames before outbound requests whose target a tenant controls
# (OIDC issuers). The suite never touches the network, so names resolve to a public address
# unless an example stubs a specific host otherwise.
RSpec.configure do |config|
  config.before do
    allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])
  end
end
