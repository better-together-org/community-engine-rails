# frozen_string_literal: true

# Thread-local request context for runtime host/platform resolution and current person tracking.
class Current < ActiveSupport::CurrentAttributes
  attribute :person, :robot, :governed_agent, :platform, :platform_domain, :platform_domain_hostnames
end
