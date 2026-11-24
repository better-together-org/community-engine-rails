# frozen_string_literal: true

module BetterTogether
  # Route constraint for the background jobs screen and the /sidekiq mount. It asks HostJobsPolicy,
  # so the route and the screen always agree; a request that fails it matches no route (404).
  class HostJobsConstraint
    def matches?(request)
      user = request.env['warden']&.user(:user)
      return false unless user

      HostJobsPolicy.new(user, :host_jobs).show?
    end
  end
end
