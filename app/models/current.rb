# frozen_string_literal: true

# Thread-local request context for runtime host/platform resolution and current person tracking.
class Current < ActiveSupport::CurrentAttributes
  attribute :person, :platform, :platform_domain
end
