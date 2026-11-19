# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Re-applies a local platform's default quota limits to the quotas that already
    # exist for it, after an admin changes the platform's quota defaults (Platform
    # settings 'quota_default_limits'). New quotas pick the default up at creation;
    # this brings existing ones in line. Per-owner QuotaGrant overrides are separate
    # records and are never touched, and usage/balances are never modified.
    class ApplyPlatformDefaultsJob < ApplicationJob
      queue_as :maintenance

      OWNER_CLASSES = {
        'person' => 'BetterTogether::Person',
        'community' => 'BetterTogether::Community'
      }.freeze

      def perform(platform_id)
        platform = BetterTogether::Platform.find_by(id: platform_id)
        return unless platform&.local_hosted?

        updated = 0
        BetterTogether::Quotas::Type.registry.each_key do |type|
          BetterTogether::Quotas::Defaults::OWNER_KINDS.each do |kind|
            limit = BetterTogether::Quotas::Defaults.platform_value(platform, type, kind) ||
                    BetterTogether::Quotas::Defaults.yaml_value(type, kind)
            next if limit.nil?

            updated += scope_for(platform, type, kind).update_all(limit:, updated_at: Time.current)
          end
        end

        Rails.logger.info "[ApplyPlatformDefaultsJob] platform=#{platform.id} updated #{updated} quota(s)"
      end

      private

      def scope_for(platform, type, kind)
        quotas = BetterTogether::Quota.where(quota_type: type)
        owner_class = OWNER_CLASSES[kind]
        return quotas.where(owner_type: 'BetterTogether::Platform', owner_id: platform.id) unless owner_class

        quotas.where(owner_type: owner_class,
                     owner_id: owner_class.constantize.where(platform_id: platform.id).select(:id))
      end
    end
  end
end
