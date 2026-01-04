# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module InvitationTestHelpers
  # Create a community invitation with the correct STI type
  # Use this instead of create(:better_together_invitation, invitable: community)
  # @param community [BetterTogether::Community] The community being invited to
  # @param attributes [Hash] Additional attributes for the invitation
  # @return [BetterTogether::CommunityInvitation]
  def create_community_invitation(community, **attributes)
    FactoryBot.create(:better_together_community_invitation, invitable: community, **attributes)
  end

  # Ensures a community coordinator role exists with proper permissions for invitation management
  def ensure_community_coordinator_role_with_permissions
    find_or_create_role('community_coordinator', coordinator_role_attributes).tap do |role|
      role.assign_resource_permissions(coordinator_permissions)
    end
  end

  # Creates a community membership with coordinator role for a user
  #  For Capybara/system tests, pass refresh_session: true to force a page reload
  def make_community_coordinator(user, community, refresh_session: false)
    create_membership_with_role(user, community, ensure_community_coordinator_role_with_permissions)
    refresh_session_if_needed(refresh_session)
  end

  # Ensures a community facilitator role exists with proper permissions
  def ensure_community_facilitator_role_with_permissions
    find_or_create_role('community_facilitator', facilitator_role_attributes).tap do |role|
      role.assign_resource_permissions(facilitator_permissions)
    end
  end

  private

  def find_or_create_role(identifier, attributes)
    BetterTogether::Role.find_by(
      identifier: identifier,
      resource_type: 'BetterTogether::Community'
    ) || BetterTogether::Role.create!(attributes.merge(identifier: identifier))
  end

  def coordinator_role_attributes
    {
      resource_type: 'BetterTogether::Community',
      name: 'Community Coordinator',
      position: 3,
      protected: true,
      description: 'Manages community engagement and events, enhancing interaction and supporting ' \
                   'sub-community initiatives.'
    }
  end

  def coordinator_permissions
    %w[
      read_community list_community create_community update_community delete_community
      manage_community_settings manage_community_content manage_community_roles
      manage_community_notifications invite_community_members
    ]
  end

  def facilitator_role_attributes
    {
      resource_type: 'BetterTogether::Community',
      name: 'Community Facilitator',
      position: 2,
      protected: true,
      description: 'Guides discussions and ensures inclusivity, acting as a mediator to foster a positive ' \
                   'community environment.'
    }
  end

  def facilitator_permissions
    %w[read_community list_community create_community update_community delete_community invite_community_members]
  end

  def create_membership_with_role(user, community, role)
    membership = BetterTogether::PersonCommunityMembership.find_or_initialize_by(
      member: user.person,
      joinable: community
    )
    membership.role = role
    membership.save!
    clear_permissions_cache(user)
    reload_user_associations(user)
    membership
  end

  def clear_permissions_cache(user)
    Rails.cache.delete_matched("better_together/member/#{user.person.class.name}/#{user.person.id}/*")
  end

  def reload_user_associations(user)
    user.reload
    user.person.reload
  end

  def refresh_session_if_needed(refresh_session)
    return unless refresh_session && respond_to?(:visit) && respond_to?(:current_path)

    visit current_path
  end
end
# rubocop:enable Metrics/ModuleLength

RSpec.configure do |config|
  config.include InvitationTestHelpers, type: :system
  config.include InvitationTestHelpers, type: :request
  config.include InvitationTestHelpers, type: :feature
end
