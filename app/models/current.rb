# frozen_string_literal: true

# Thread-local request context for runtime host/platform resolution and current person tracking.
class Current < ActiveSupport::CurrentAttributes
  attribute :person, :robot, :governed_agent, :platform, :platform_domain, :platform_domain_hostnames,
            :host_platform

  # Lazy-loads and memoizes the host platform within a single request/job lifecycle.
  # Pre-warmed by ApplicationController#set_current_platform_context on web requests;
  # falls back to a single DB query in background-job or test contexts.
  def host_platform
    super || (self.host_platform = BetterTogether::Platform.find_by(host: true))
  end
end
