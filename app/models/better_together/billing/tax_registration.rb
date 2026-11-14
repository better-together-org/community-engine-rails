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
    # (see Tax::Defaults). `effective_from` is required; an empty `effective_to` means the registration is ongoing.
    # The registration number is encrypted.
    class TaxRegistration < ApplicationRecord
      include PlatformBound
      include SellerScoped
      include EncryptedAttributes

      self.table_name = 'better_together_billing_tax_registrations'

      STATUSES = %w[registered small_supplier_exempt exempt not_collecting].freeze

      encrypts_billing_attribute :registration_number

      # The place, as the geography records tax zones use. country_iso and region_code are what tax is looked up by;
      # they follow the chosen records, and records are found from the codes when only codes are given.
      belongs_to :country, class_name: 'BetterTogether::Geography::Country', optional: true
      belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true

      before_validation :sync_place

      validates :status, inclusion: { in: STATUSES }
      validates :country_iso, format: { with: /\A[A-Z]{2}\z/ }
      validates :effective_from, presence: true
      validate :state_is_in_country
      validate :ends_after_it_starts

      scope :in_force_at, lambda { |time|
        where(arel_table[:effective_from].lteq(time))
          .where(arel_table[:effective_to].eq(nil).or(arel_table[:effective_to].gt(time)))
      }

      def collects? = status == 'registered'

      def prices_include_tax? = prices_include_tax.nil? ? Tax::Defaults.prices_include_tax?(country_iso) : prices_include_tax

      private

      # Chosen records win; when only the codes changed the records are found from them.
      def sync_place
        return take_codes_from_records if country_id_changed? || state_id_changed?

        self.country_iso = country_iso.to_s.upcase.presence
        self.region_code = region_code.to_s.upcase.presence
        link_records_from_codes
      end

      def take_codes_from_records
        self.country ||= state&.country
        self.country_iso = country&.iso_code.to_s.upcase.presence
        self.region_code = (state.iso_code.split('-', 2).last if state)
      end

      def link_records_from_codes
        self.country = (Geography::Country.find_by(iso_code: country_iso) if country_iso)
        self.state = (Geography::State.find_by(iso_code: "#{country_iso}-#{region_code}") if country_iso && region_code)
      end

      def state_is_in_country
        errors.add(:state_id, :inclusion) if state && country && state.country_id != country_id
      end

      def ends_after_it_starts
        errors.add(:effective_to, :invalid) if effective_from && effective_to && effective_to <= effective_from
      end
    end
  end
end
