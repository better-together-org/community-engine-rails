# frozen_string_literal: true

# Paid plans set quota limits: register the allowance provider the quota framework asks (see
# BetterTogether::Quotas::Allowances and BetterTogether::Billing::Entitlements::QuotaAllowances). to_prepare, so
# it is registered again whenever code reloads.
Rails.application.config.to_prepare do
  BetterTogether::Quotas::Allowances.register('billing_entitlements', BetterTogether::Billing::Entitlements::QuotaAllowances)
end
