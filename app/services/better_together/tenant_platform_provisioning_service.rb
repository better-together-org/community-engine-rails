# frozen_string_literal: true

module BetterTogether
  # Provisions a platform registry record and its shared-schema bootstrap data.
  # Model callbacks handle primary domain/community creation and registry defaults.
  # This service adds admin bootstrap, transactional rollback, and internal-first
  # semantics while keeping the legacy external column.
  # Idempotent: uses find_or_initialize_by(host_url:) — safe to re-run.
  class TenantPlatformProvisioningService
    Result = Struct.new(:platform, :community, :domain, :admin_user, :errors) do
      def success?
        errors.blank?
      end
    end

    def self.call(**)
      new(**).call
    end

    def initialize(name:, host_url:, **platform_options)
      @name      = name
      @host_url  = host_url
      @time_zone = platform_options.fetch(:time_zone, 'UTC')
      @host      = platform_options.fetch(:host, false)
      @admin     = platform_options[:admin]
      @internal = resolved_internal_flag(platform_options)
      @tenant_schema = platform_options[:tenant_schema]
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
        external: !@internal,
        host: @host,
        privacy: 'public',
        tenant_schema: @internal ? @tenant_schema : nil
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

    def resolved_internal_flag(platform_options)
      return ActiveModel::Type::Boolean.new.cast(platform_options.fetch(:internal, true)) unless platform_options.key?(:external)

      !ActiveModel::Type::Boolean.new.cast(platform_options[:external])
    end
  end
end
