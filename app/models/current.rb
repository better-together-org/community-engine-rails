# frozen_string_literal: true

# Thread-local request context for runtime host/platform resolution and current person tracking.
class Current < ActiveSupport::CurrentAttributes
  attribute :person, :governed_agent, :platform, :platform_domain, :tenant_schema
end
