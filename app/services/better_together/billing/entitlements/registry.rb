# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # The kinds of thing a plan can include, each with the handler that knows how to apply and take it away. An
      # allow-list of constants: a plan stores only the kind's NAME, and nothing is ever resolved from a string,
      # so a plan cannot make Community Engine instantiate a class it did not provide for.
      module Registry
        module_function

        def handlers
          { 'membership_role' => Handlers::MembershipRole, 'feature_access' => Handlers::FeatureAccess,
            'quota_allowance' => Handlers::QuotaAllowance }
        end

        def kinds = handlers.keys

        def handler_class(kind) = handlers.fetch(kind.to_s)

        # A handler ready to act for a grant (a plan's, or one already applied).
        def handler_for(grant) = handler_class(grant.kind).new(grant.parameters, platform: grant.platform)
      end
    end
  end
end
