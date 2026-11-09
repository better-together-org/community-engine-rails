# frozen_string_literal: true

module BetterTogether
  module Billing
    # A place a tax applies, tied to the geography records: a whole country, one state or province of it, or one
    # settlement (a city or town) in it. Tax in a settlement's zone is a municipal tax and adds to the state's and
    # the country's. Tax zones are data: a platform adds the ones it needs and none is built in.
    class TaxZone < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_tax_zones'

      belongs_to :country, class_name: 'BetterTogether::Geography::Country'
      belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true
      belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement', optional: true

      has_many :tax_rates, class_name: 'BetterTogether::Billing::TaxRate', dependent: :restrict_with_error

      # A settlement says which state and country it is in, so a municipal zone need only name the settlement.
      before_validation :take_place_from_settlement

      validates :name, presence: true
      validate :place_is_consistent

      # The zones that cover a place (see Tax::Place): the country's own, the state's if there is one, and the
      # settlement's if there is one.
      scope :covering, lambda { |place|
        where(country_id: place.country&.id).where(state_id: [nil, place.state&.id].uniq)
                                            .where(settlement_id: [nil, place.settlement&.id].uniq)
      }

      def level
        return :municipal if settlement_id
        return :state if state_id

        :country
      end

      private

      def take_place_from_settlement
        return unless settlement

        self.state_id ||= settlement.state_id
        self.country_id ||= settlement.country_id || settlement.state&.country_id
      end

      def place_is_consistent
        errors.add(:state, :invalid) if state && country && state.country_id != country_id
        errors.add(:settlement, :invalid) if settlement && !settlement_inside?
      end

      # A settlement that names its state or country must be in the state and country the zone names.
      def settlement_inside?
        [[state_id, settlement.state_id], [country_id, settlement.country_id]].all? { |zone, own| zone.nil? || own.nil? || zone == own }
      end
    end
  end
end
