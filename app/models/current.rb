# frozen_string_literal: true

# Thread-local request context for runtime host/platform resolution.
class Current < ActiveSupport::CurrentAttributes
  attribute :platform, :platform_domain
end
