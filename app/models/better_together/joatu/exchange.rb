# frozen_string_literal: true

# app/models/better_together/joatu/exchange.rb
module BetterTogether
  module Joatu
    # Abstract base for offers and requests, encapsulating shared behavior
    class Exchange < ApplicationRecord
      self.abstract_class = true

      include Categorizable
      include Creatable
      include Translatable

      STATUS_VALUES = {
        open: 'open',
        matched: 'matched',
        fulfilled: 'fulfilled',
        closed: 'closed'
      }.freeze
      URGENCY_VALUES = {
        low: 'low',
        normal: 'normal',
        high: 'high',
        critical: 'critical'
      }.freeze

      enum status:  STATUS_VALUES,  _prefix: :status
      enum urgency: URGENCY_VALUES, _prefix: :urgency

      belongs_to :target, polymorphic: true, optional: true
      has_many :agreements,
               class_name: 'BetterTogether::Joatu::Agreement',
               dependent: :destroy

      translates :name, type: :string
      translates :description, backend: :action_text

      validates :name, :description, :creator, presence: true
      validates :categories, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validates :urgency, presence: true, inclusion: { in: URGENCY_VALUES.values }
      validates :target_type, presence: true, if: :target_id?

      belongs_to :address,
                 class_name: 'BetterTogether::Address',
                 optional: true,
                 autosave: true
      accepts_nested_attributes_for :address, allow_destroy: true

      after_commit :notify_matches, on: :create

      def self.permitted_attributes(id: false, destroy: false)
        super +
          %i[target_type target_id address_id] +
          [address_attributes: BetterTogether::Address.permitted_attributes(id: true, destroy: true)]
      end

      # Return matching counterpart records (requests for offers, offers for requests)
      def find_matches
        BetterTogether::Joatu::Matchmaker.match(self)
      end

      private

      def notify_matches
        find_matches.find_each do |other|
          # Assign offer/request for notification context
          offer_rec, request_rec =
            if is_a?(Offer)
              [self, other]
            else
              [other, self]
            end

          recipients = [creator, other&.creator].compact
          next if recipients.empty?

          notifier = BetterTogether::Joatu::MatchNotifier.with(offer: offer_rec, request: request_rec)
          notifier.deliver_later(recipients)
        end
      end
    end
  end
end
