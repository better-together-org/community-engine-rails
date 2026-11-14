# frozen_string_literal: true

# Open sign-up puts a person in the platform's community; account linking by email
# requires that membership (P0-5). Specs that link an existing user use this helper.
module PlatformCommunityMembershipHelpers
  def join_platform_community(user, platform = BetterTogether::Platform.find_by(host: true))
    platform.community.person_community_memberships.find_or_create_by!(member: user.person) do |membership|
      membership.role = BetterTogether::Role.find_by(resource_type: 'BetterTogether::Community') ||
                        BetterTogether::Role.first
      membership.status = 'active'
    end
    user
  end
end

RSpec.configure { |config| config.include PlatformCommunityMembershipHelpers }
