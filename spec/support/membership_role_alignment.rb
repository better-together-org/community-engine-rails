# frozen_string_literal: true

# Roles belong to one platform each, and memberships may only hold a role from their own platform.
# Specs frequently build a role on the current platform and attach it to another one; unless an example
# is tagged :strict_role_platform, align the role with the membership's platform before validation:
# use that platform's seeded copy when there is one, otherwise move the ad hoc role there.
module MembershipRoleAlignment
  def self.call(membership, owner_id)
    role = membership.role
    return if role.blank? || owner_id.blank? || role.platform_id.blank? || role.platform_id == owner_id

    own_copy = BetterTogether::Role.find_by(platform_id: owner_id, identifier: role.identifier,
                                            resource_type: role.resource_type)
    if own_copy
      membership.role = own_copy
    else
      move(role, owner_id)
    end
  end

  def self.move(role, owner_id)
    role.platform_id = owner_id
    role.position = BetterTogether::Role.where(platform_id: owner_id, resource_type: role.resource_type)
                                        .maximum(:position).to_i + 1
    role.save!(validate: false) if role.persisted?
  end

  module Callbacks
    def self.included(base)
      base.before_validation do
        next if Thread.current[:strict_role_platform]

        owner_id = joinable.is_a?(BetterTogether::Platform) ? joinable.id : joinable.try(:platform_id)
        MembershipRoleAlignment.call(self, owner_id)
      end
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    [BetterTogether::PersonPlatformMembership, BetterTogether::PersonCommunityMembership].each do |klass|
      klass.include MembershipRoleAlignment::Callbacks
    end
  end
  config.around(:each, :strict_role_platform) do |example|
    Thread.current[:strict_role_platform] = true
    example.run
  ensure
    Thread.current[:strict_role_platform] = false
  end
end
