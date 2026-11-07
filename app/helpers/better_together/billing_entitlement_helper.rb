# frozen_string_literal: true

module BetterTogether
  # View helpers for what a plan includes and what people have because of it.
  module BillingEntitlementHelper
    ENTITLEMENT_BADGES = { 'active' => 'bg-success', 'grace' => 'bg-warning text-dark', 'lapsed' => 'bg-secondary',
                           'revoked' => 'bg-dark' }.freeze

    def billing_entitlement_status_badge(entitlement)
      tag.span(t("better_together.billing.entitlements.status_#{entitlement.status}"),
               class: "badge #{ENTITLEMENT_BADGES.fetch(entitlement.status, 'bg-secondary')} entitlement-status-badge")
    end

    # Roles a plan may give: those that hold no `manage_*` permission, for the platform or for a community.
    def billing_grantable_roles(resource_type)
      BetterTogether::Role.where(resource_type:).positioned.reject do |role|
        role.resource_permissions.pluck(:identifier).any? { |identifier| identifier.match?(Billing::Entitlements::Handlers::MembershipRole::PRIVILEGED) }
      end
    end

    # The platform's own communities, for a plan that gives a role in one.
    def billing_grantable_communities
      BetterTogether::Community.where(platform_id: billing_owner.id).order(:identifier).limit(200)
    end

    # One line saying what a plan grant gives, in words.
    def billing_plan_grant_summary(grant)
      parameters = grant.parameters
      case grant.kind
      when 'membership_role' then t('better_together.billing.plan_grants.summary_role', role: parameters['role'],
                                                                                        where: billing_grant_place(parameters))
      when 'feature_access' then t('better_together.billing.plan_grants.summary_feature', feature: BetterTogether::FeatureRegistry.name_for(parameters['feature_key']),
                                                                                          level: parameters['access_level'])
      when 'quota_allowance' then billing_quota_summary(parameters)
      else grant.kind
      end
    end

    def billing_quota_summary(parameters)
      type = BetterTogether::Quotas::Type.find(parameters['quota_type'])
      t('better_together.billing.plan_grants.summary_quota', amount: number_with_delimiter(parameters['amount']), unit: type.unit,
                                                             quota: type.key.humanize)
    rescue KeyError
      parameters['quota_type'].to_s
    end

    def billing_grant_place(parameters)
      return t('better_together.billing.plan_grants.place_platform') unless parameters['joinable'] == 'community'

      community = BetterTogether::Community.find_by(id: parameters['community_id'])
      if community
        t('better_together.billing.plan_grants.place_community',
          name: community.name)
      else
        t('better_together.billing.plan_grants.place_unknown')
      end
    end

    # A meter's bar as a percentage with a label for people who cannot see the bar.
    def billing_meter_label(reading)
      return t('better_together.billing.entitlements.meter_unlimited') if reading.unlimited?

      t('better_together.billing.entitlements.meter', used: number_with_delimiter(reading.used), limit: number_with_delimiter(reading.limit),
                                                      percent: reading.percent)
    end
  end
end
