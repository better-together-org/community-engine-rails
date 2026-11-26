# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/purchase_requirement',
          class: 'BetterTogether::Billing::PurchaseRequirement',
          aliases: %i[better_together_billing_purchase_requirement] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    association :dependent, factory: :better_together_billing_product
    association :prerequisite, factory: :better_together_billing_plan
    met_by { 'either' }
    required { false }
    on_prerequisite_end { 'keep' }

    trait :for_any_plan do
      prerequisite { nil }
      prerequisite_kind { 'plan' }
    end
  end
end
