# frozen_string_literal: true

module BetterTogether
  # Assigns memberships for a new user across the host platform and community
  class MembershipAssigner
    def self.call(person:, host_platform:, host_community:)
      new(person:, host_platform:, host_community:).call
    end

    def initialize(person:, host_platform:, host_community:)
      @person = person
      @host_platform = host_platform
      @host_community = host_community
    end

    def call
      ActiveRecord::Base.transaction do
        platform_role = BetterTogether::Role.find_by!(identifier: 'platform_manager')
        community_role = BetterTogether::Role.find_by!(identifier: 'community_governance_council')

        host_platform.person_platform_memberships.create!(member: person, role: platform_role)
        host_community.person_community_memberships.create!(member: person, role: community_role)
        host_community.creator = person
        host_community.save!
      end
    end

    private

    attr_reader :person, :host_platform, :host_community
  end
end
