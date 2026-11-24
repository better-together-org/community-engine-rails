# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

module AccessContractProbe
  # The persona users shared by every pilot resource. Community personas are
  # attached to each fixture community by the resource probes.
  class World
    include FactoryBot::Syntax::Methods

    COMMUNITY_ROLES = {
      'community_member' => 'community_member',
      'community_contributor' => 'community_contributor',
      'community_organizer' => 'community_organizer'
    }.freeze

    attr_reader :host, :users

    def initialize
      @host = BetterTogether::Platform.find_by!(host: true)
      Current.platform = @host
      @users = build_users
    end

    def user_for(persona)
      users[persona]
    end

    def new_user
      create(:better_together_user, :confirmed)
    end

    def join(community, person, role_identifier, status: 'active')
      role = BetterTogether::Role.find_default(role_identifier, platform: host)
      BetterTogether::PersonCommunityMembership.create!(joinable: community, member: person, role:, status:)
    end

    def join_personas(community)
      COMMUNITY_ROLES.each { |persona, role| join(community, users.fetch(persona).person, role) }
    end

    private

    def build_users
      users = { 'anonymous' => nil, 'signed_in_non_member' => new_user, 'blocked_user' => new_user }
      COMMUNITY_ROLES.each_key { |persona| users[persona] = new_user }
      %w[platform_manager platform_steward].each { |role| users[role] = platform_role_user(role) }
      users
    end

    def platform_role_user(role_identifier)
      user = new_user
      role = BetterTogether::Role.find_default(role_identifier, platform: host)
      host.person_platform_memberships.create!(member: user.person, role:, status: 'active')
      user
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
