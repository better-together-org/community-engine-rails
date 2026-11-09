# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/tax_category', class: 'BetterTogether::Billing::TaxCategory',
                                                  aliases: %i[better_together_billing_tax_category] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    identifier { "category_#{SecureRandom.hex(4)}" }
    name { 'Standard' }
    taxable { true }
  end

  factory 'better_together/billing/tax_zone', class: 'BetterTogether::Billing::TaxZone',
                                              aliases: %i[better_together_billing_tax_zone] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    name { 'Canada' }
    # The place is a set of geography rows; these say which, by ISO code, and `settlement` makes a municipal zone.
    transient do
      country_iso { 'CA' }
      region_code { nil }
    end
    country { tax_geography_country(country_iso) }
    state { region_code && tax_geography_state(country_iso, region_code) }
  end

  factory 'better_together/billing/tax_rate', class: 'BetterTogether::Billing::TaxRate',
                                              aliases: %i[better_together_billing_tax_rate] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    tax_zone { association :better_together_billing_tax_zone, platform: }
    label { 'GST' }
    rate { 0.05 }
  end

  factory 'better_together/billing/tax_registration', class: 'BetterTogether::Billing::TaxRegistration',
                                                      aliases: %i[better_together_billing_tax_registration] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    country_iso { 'CA' }
    status { 'registered' }
    registration_number { '123456789RT0001' }
  end
end
