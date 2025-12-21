# frozen_string_literal: true

module BetterTogether
  # Preview at /rails/mailers/better_together/membership_mailer
  class MembershipMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods
    include BetterTogether::ApplicationHelper

    # Preview at /rails/mailers/better_together/membership_mailer/platform_analytics_viewer_membership
    def platform_analytics_viewer_membership
      platform = ensure_host_platform
      role = find_or_create_role(
        identifier: 'platform_analytics_viewer',
        name: 'Platform Analytics Viewer',
        resource_type: 'BetterTogether::Platform'
      )
      ensure_role_permissions(role, 'BetterTogether::Platform')
      member = create(:person)
      membership = create(:better_together_person_platform_membership, joinable: platform, member: member, role: role)

      BetterTogether::MembershipMailer.with(membership:, recipient: member).created
    end

    # Preview at /rails/mailers/better_together/membership_mailer/community_governance_council_membership
    def community_governance_council_membership
      community = ensure_host_community
      role = find_or_create_role(
        identifier: 'community_governance_council',
        name: 'Community Governance Council',
        resource_type: 'BetterTogether::Community'
      )
      ensure_role_permissions(role, 'BetterTogether::Community')
      member = create(:person)
      membership = create(:better_together_person_community_membership, joinable: community, member: member, role: role)

      BetterTogether::MembershipMailer.with(membership:, recipient: member).created
    end

    # Preview at /rails/mailers/better_together/membership_mailer/community_member_membership
    def community_member_membership
      community = ensure_host_community
      role = find_or_create_role(
        identifier: 'community_member',
        name: 'Community Member',
        resource_type: 'BetterTogether::Community'
      )
      ensure_role_permissions(role, 'BetterTogether::Community')
      member = create(:person)
      membership = create(:better_together_person_community_membership, joinable: community, member: member, role: role)

      BetterTogether::MembershipMailer.with(membership:, recipient: member).created
    end

    private

    def find_or_create_role(identifier:, name:, resource_type:)
      BetterTogether::Role.find_by(identifier: identifier, resource_type: resource_type) ||
        create(:better_together_role, identifier: identifier, name: name, resource_type: resource_type)
    end

    def ensure_role_permissions(role, resource_type)
      return if role.resource_permissions.exists?

      permissions = create_list(:better_together_resource_permission, 6, resource_type: resource_type)
      role.resource_permissions << permissions
    end

    def ensure_host_platform
      platform = BetterTogether::Platform.find_by(host: true)
      return platform if platform&.time_zone.present?

      platform.update!(time_zone: platform.time_zone.presence || 'UTC')
      platform
    end

    def ensure_host_community
      BetterTogether::Community.find_by(host: true) || create(:community, :host)
    end
  end
end
