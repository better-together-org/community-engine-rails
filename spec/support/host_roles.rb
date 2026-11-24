# frozen_string_literal: true

# Roles are per platform. Spec setup that wants "the" default role means the host platform's copy.
module HostRoles
  def self.find(identifier)
    host = BetterTogether::Platform.find_by(host: true)
    scope = host ? BetterTogether::Role.where(platform_id: host.id) : BetterTogether::Role.all
    scope.find_by(identifier:)
  end

  def self.find!(identifier)
    find(identifier) || raise(ActiveRecord::RecordNotFound, "host role #{identifier} not found")
  end
end
