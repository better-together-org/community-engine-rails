# frozen_string_literal: true

module BetterTogether
  # Provisions a new tenant Platform end-to-end in a single transaction.
  #
  # Model callbacks on Platform handle:
  #   - primary PlatformDomain (sync_primary_platform_domain! after_commit)
  #   - primary Community (create_primary_community before_validation)
  #   - federation registry defaults (apply_platform_registry_defaults before_validation)
  #
  # This service adds:
  #   - Optional admin User + PersonPlatformMembership (platform_steward)
  #   - Optional admin PersonCommunityMembership (community_governance_council)
  #   - Transactional wrapper so partial failures roll back completely
  #
  # Idempotent: uses find_or_initialize_by(host_url:) — safe to re-run.
  #
  # Usage:
  #   result = BetterTogether::TenantPlatformProvisioningService.call(
  #     name: 'My Tenant',
  #     host_url: 'https://tenant.example.com',
  #     time_zone: 'America/Toronto',
  #     admin: { email: 'admin@example.com', password: 'SecurePass1!' }
  #   )
  #   result.success? # => true
  #   result.platform # => BetterTogether::Platform instance
  class TenantPlatformProvisioningService
    Result = Struct.new(
      :platform,
      :community,
      :domain,
      :admin_user,
      :errors,
      keyword_init: true
    ) do
      def success?
        errors.blank?
      end
    end

    def self.call(**)
      new(**).call
    end

    def initialize(name:, host_url:, time_zone: 'UTC', host: false, admin: nil)
      @name      = name
      @host_url  = host_url
      @time_zone = time_zone
      @host      = host
      @admin     = admin
    end

    def call # rubocop:disable Metrics/AbcSize
      result = nil
      ActiveRecord::Base.transaction { result = build_result! }
      # after_commit has now fired (sync_primary_platform_domain!); reload to pick up the domain
      result.platform&.reload
      Result.new(
        platform: result.platform,
        community: result.platform&.primary_community,
        domain: result.platform&.primary_platform_domain,
        admin_user: result.admin_user,
        errors: []
      )
    rescue ActiveRecord::RecordInvalid => e
      failure_result(e.record.errors.full_messages)
    rescue StandardError => e
      failure_result([e.message])
    end

    private

    def build_result!
      platform   = provision_platform!
      admin_user = provision_admin!(platform) if @admin.present?

      Result.new(
        platform:,
        community: platform.primary_community,
        domain: platform.primary_platform_domain,
        admin_user:,
        errors: []
      )
    end

    def failure_result(errors)
      Result.new(platform: nil, community: nil, domain: nil, admin_user: nil, errors:)
    end

    def provision_platform!
      platform = ::BetterTogether::Platform.find_or_initialize_by(host_url: @host_url)

      platform.assign_attributes(
        name: @name,
        time_zone: @time_zone,
        external: false,
        host: @host,
        privacy: 'public'
      )

      platform.save!
      platform
    end

    def provision_admin!(platform)
      user = ::BetterTogether::User.find_or_initialize_by(email: @admin[:email])
      user.build_person unless user.person

      user.assign_attributes(@admin.except(:name))
      user.person.name = @admin[:name] if @admin[:name].present?
      user.save!

      assign_platform_role!(platform, user.person)
      assign_community_role!(platform, user.person)

      user
    end

    def assign_platform_role!(platform, person)
      role = platform_steward_role
      return unless role

      platform.person_platform_memberships.find_or_create_by!(
        member: person,
        role:
      )
    end

    def assign_community_role!(platform, person)
      community = platform.primary_community
      role = community_governance_role
      return unless community && role

      community.person_community_memberships.find_or_create_by!(
        member: person,
        role:
      )
    end

    def platform_steward_role
      ::BetterTogether::Role.find_by(identifier: 'platform_steward') ||
        ::BetterTogether::Role.find_by(identifier: 'platform_manager')
    end

    def community_governance_role
      ::BetterTogether::Role.find_by(identifier: 'community_governance_council')
    end
  end
end
