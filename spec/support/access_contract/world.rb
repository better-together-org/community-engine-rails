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

    attr_reader :host, :users, :other_platform, :hosted_platform

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

    # Billing is switched on for the host only: one enabled offline method. A second platform stands for
    # tenant isolation, and a hosted platform where the manager and steward personas hold the same role.
    def prepare_billing
      return if @other_platform

      BetterTogether::Billing.register_builtin_processors!
      host.billing_processor_settings.find_or_create_by!(processor: 'cash') do |setting|
        setting.assign_attributes(enabled: true, acknowledge: true, settings: { 'instructions' => 'At the hall' })
      end
      @other_platform = create(:better_together_platform)
      @hosted_platform = create(:better_together_platform)
      %w[platform_manager platform_steward].each do |persona|
        role = BetterTogether::Role.find_default(persona, platform: host)
        hosted_platform.person_platform_memberships.create!(member: users.fetch(persona).person, role:, status: 'active')
      end
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
