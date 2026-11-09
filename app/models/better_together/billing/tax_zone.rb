# frozen_string_literal: true

module BetterTogether
  module Billing
    # A place a tax applies: a whole country, or one region of it (a province or state).
    class TaxZone < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_tax_zones'

      has_many :tax_rates, class_name: 'BetterTogether::Billing::TaxRate', dependent: :restrict_with_error

      before_validation { self.country_iso = country_iso.to_s.upcase.presence }
      before_validation { self.region_code = region_code.to_s.upcase.presence }

      validates :name, presence: true
      validates :country_iso, format: { with: /\A[A-Z]{2}\z/ }

      # The zones that cover a place: the country's own, and the region's if there is one.
      scope :covering, lambda { |country_iso, region_code|
        where(country_iso: country_iso.to_s.upcase).where(region_code: [nil, region_code.to_s.upcase.presence].uniq)
      }
    end
  end
end
