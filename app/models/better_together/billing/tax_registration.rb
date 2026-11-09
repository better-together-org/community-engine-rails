# frozen_string_literal: true

module BetterTogether
  module Billing
    # Who collects tax on a sale, and on what terms. The platform's own registration is the default
    # registrant; a seller may have one of their own. Its `status` says whether tax is collected at all:
    #
    # * registered: tax is collected on this registrant's sales.
    # * small_supplier_exempt: registered as under the small-supplier threshold, so none is collected.
    # * exempt: not required to collect.
    # * not_collecting: tax collection is switched off.
    #
    # `prices_include_tax` says whether prices already contain the tax; empty means the country's usual way
    # (see Tax::Defaults). The registration number is encrypted.
    class TaxRegistration < ApplicationRecord
      include PlatformBound
      include SellerScoped
      include EncryptedAttributes

      self.table_name = 'better_together_billing_tax_registrations'

      STATUSES = %w[registered small_supplier_exempt exempt not_collecting].freeze

      encrypts_billing_attribute :registration_number

      before_validation { self.country_iso = country_iso.to_s.upcase.presence }
      before_validation { self.region_code = region_code.to_s.upcase.presence }

      validates :status, inclusion: { in: STATUSES }
      validates :country_iso, format: { with: /\A[A-Z]{2}\z/ }
      validate :ends_after_it_starts

      scope :in_force_at, lambda { |time|
        where(arel_table[:effective_from].eq(nil).or(arel_table[:effective_from].lteq(time)))
          .where(arel_table[:effective_to].eq(nil).or(arel_table[:effective_to].gt(time)))
      }

      def collects? = status == 'registered'

      def prices_include_tax? = prices_include_tax.nil? ? Tax::Defaults.prices_include_tax?(country_iso) : prices_include_tax

      private

      def ends_after_it_starts
        errors.add(:effective_to, :invalid) if effective_from && effective_to && effective_to <= effective_from
      end
    end
  end
end
