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

  # Ensures a community organizer role exists with proper permissions for invitation management
  def ensure_community_organizer_role_with_permissions
    find_or_create_role('community_organizer', organizer_role_attributes).tap do |role|
      role.assign_resource_permissions(organizer_permissions)
    end
  end

  # Creates a community membership with organizer role for a user
  def make_community_organizer(user, community, refresh_session: false)
    create_membership_with_role(user, community, ensure_community_organizer_role_with_permissions)
    refresh_session_if_needed(refresh_session)
  end

  # Transitional helper: coordinator now aliases to community organizer.
  def ensure_community_coordinator_role_with_permissions
    ensure_community_organizer_role_with_permissions
  end

  # Transitional helper: coordinator now aliases to community organizer.
  #  For Capybara/system tests, pass refresh_session: true to force a page reload
  def make_community_coordinator(user, community, refresh_session: false)
    make_community_organizer(user, community, refresh_session: refresh_session)
  end

  # Transitional helper: facilitator now aliases to community organizer.
  def ensure_community_facilitator_role_with_permissions
    ensure_community_organizer_role_with_permissions
  end

  private

  def find_or_create_role(identifier, attributes)
    BetterTogether::Role.find_by(
      identifier: identifier,
      resource_type: 'BetterTogether::Community'
    ) || BetterTogether::Role.create!(attributes.merge(identifier: identifier))
  end

  def organizer_role_attributes
    {
      resource_type: 'BetterTogether::Community',
      name: 'Community Organizer',
      position: 3,
      protected: true,
      description: 'Coordinates community engagement, events, content, and participation workflows.'
    }
  end

  def organizer_permissions
    %w[
      read_community list_community create_community update_community delete_community
      manage_community_settings manage_community_content manage_community_roles
      manage_community_notifications invite_community_members
    ]
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
