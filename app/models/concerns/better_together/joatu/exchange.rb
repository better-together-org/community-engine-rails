# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Concern for shared Offer/Request behavior
    module Exchange
      extend ActiveSupport::Concern

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

      included do
        include BetterTogether::Categorizable
        include BetterTogether::Translatable
        include BetterTogether::FriendlySlug

        enum :status, STATUS_VALUES, prefix: :status
        enum :urgency, URGENCY_VALUES, prefix: :urgency

        belongs_to :address,
                   class_name: 'BetterTogether::Address',
                   optional: true,
                   autosave: true
        belongs_to :target, polymorphic: true, optional: true
        has_many :agreements,
                 class_name: 'BetterTogether::Joatu::Agreement',
                 dependent: :destroy

        translates :name, type: :string
        translates :description, backend: :action_text

        slugged :name, dependent: :delete_all

        validates :name, :description, :creator, presence: true
        validates :categories, presence: true
        validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
        validates :urgency, presence: true, inclusion: { in: URGENCY_VALUES.values }
        validates :target_type, presence: true, if: :target_id?

        accepts_nested_attributes_for :address, allow_destroy: true

        after_commit :notify_matches, on: :create
      end

      class_methods do
        def permitted_attributes(id: false, destroy: false)
          super +
            %i[target_type target_id address_id status urgency] +
            [address_attributes: BetterTogether::Address.permitted_attributes(id: true, destroy: true)]
        end
      end

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
        ActiveRecord::Base.descendants.select { |model| model.included_modules.include?(included_module) }
      end

      # Return matching counterpart records (requests for offers, offers for requests)
      def find_matches
        BetterTogether::Joatu::Matchmaker.match(self)
      end

      private

      def notify_matches # rubocop:todo Metrics/MethodLength
        find_matches.find_each do |other|
          offer_rec, request_rec =
            if is_a?(BetterTogether::Joatu::Offer)
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
