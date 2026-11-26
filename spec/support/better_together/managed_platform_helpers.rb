# frozen_string_literal: true

module BetterTogether
  # Spec setup for the operator and managed platform model: an operator platform, a managed (hosted)
  # platform, the active PlatformAssociation that makes the first the operator of the second, and a steward
  # on each side. Use it instead of wiring platforms and memberships by hand, so every spec exercises the
  # same, correct authority chain.
  #
  #   setup = managed_platform_setup                      # host platform operates a hosted platform
  #   setup = managed_platform_setup(scopes: %w[read])    # narrower association
  #   setup = managed_platform_setup(remote_operator: true) # a remote operator governs it
  #   setup = managed_platform_setup(associate: false)    # a hosted platform nobody operates
  module ManagedPlatformHelpers
    DEFAULT_SCOPES = %w[read support manage_settings billing].freeze

    ManagedSetup = Struct.new(:operator_platform, :managed_platform, :association,
                              :operator_steward, :managed_steward, keyword_init: true)

    # rubocop:disable-next Metrics/ParameterLists
    def managed_platform_setup(operator: nil, remote_operator: false, associate: true,
                               scopes: DEFAULT_SCOPES, managed_attributes: {})
      operator_platform = operator || (remote_operator ? create_remote_operator_platform : operator_host_platform)
      managed_platform = create(:better_together_platform, type: 'BetterTogether::HostedPlatform', **managed_attributes)
      association = associate ? associate_operator(operator_platform, managed_platform, scopes, remote_operator) : nil

      ManagedSetup.new(
        operator_platform:, managed_platform:, association:,
        operator_steward: steward_of_platform(operator_platform),
        managed_steward: steward_of_platform(managed_platform)
      )
    end

    # A confirmed user holding the platform_steward role on exactly this platform. Accounts are per
    # platform, so the user also belongs to it and can sign in on its domain.
    def steward_of_platform(platform)
      user = create(:better_together_user, :confirmed, platform_id: platform.id)
      BetterTogether::PersonPlatformMembership.create!(
        joinable: platform, member: user.person, role: steward_role_for(platform), status: 'active'
      )
      user
    end

    # Make requests in the example arrive on the platform's own primary domain.
    def host_on(platform)
      host! platform.platform_domains.find_by!(primary: true).hostname
    end

    # Sign a user in on the next request (request specs).
    def sign_in_steward(user)
      login_as(user, scope: :user)
    end

    private

    def operator_host_platform
      configure_host_platform
      platform = BetterTogether::Platform.find_by!(host: true)
      ensure_primary_domain(platform)
      platform
    end

    # Specs must not depend on whatever domain rows earlier runs left behind.
    def ensure_primary_domain(platform)
      return if platform.platform_domains.exists?(primary: true)

      create(:better_together_platform_domain, platform:, hostname: URI.parse(platform.host_url).host,
                                               primary: true, active: true)
    end

    def create_remote_operator_platform
      create(:better_together_platform, :remote, type: 'BetterTogether::OperatorPlatform')
    end

    def associate_operator(operator_platform, managed_platform, scopes, remote)
      create(:better_together_platform_association, :active,
             operator_platform:, managed_platform:, granted_scopes: scopes,
             transport: remote ? 'http' : 'direct')
    end

    def steward_role_for(platform)
      BetterTogether::AccessControlBuilder.seed_data if BetterTogether::Role.where(identifier: 'platform_steward').none?
      roles = BetterTogether::Role.where(identifier: 'platform_steward')
      roles.find_by(platform_id: platform.id) || roles.first!
    end
  end
end

RSpec.configure { |config| config.include BetterTogether::ManagedPlatformHelpers }
