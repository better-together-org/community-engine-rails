# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Offer represents a service or item someone is willing to provide
    class Offer < ApplicationRecord
      include Categorizable
      include Creatable
      include FriendlySlug

      STATUS_VALUES = {
        open: 'open',
        closed: 'closed'
      }.freeze

      has_many :agreements, class_name: 'BetterTogether::Joatu::Agreement', dependent: :destroy
      has_many :requests, class_name: 'BetterTogether::Joatu::Request', through: :agreements

      belongs_to :target, polymorphic: true, optional: true

      categorizable class_name: '::BetterTogether::Joatu::Category'

      slugged :name, dependent: :delete_all

      translates :name, type: :string
      translates :description, backend: :action_text

      validates :name, :description, :creator, presence: true
      validates :categories, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validates :target_type, presence: true, if: :target_id?

      enum status: STATUS_VALUES, _prefix: :status

      def self.permitted_attributes
        super + %i[target_type target_id]
      end

      after_commit :notify_matches, on: :create

      private

      def notify_matches
        BetterTogether::Joatu::Matchmaker.match(self).find_each do |request|
          notifier = BetterTogether::Joatu::MatchNotifier.with(offer: self, request:)
          notifier.deliver(request.creator) if request&.creator
          notifier.deliver(creator) if creator
        end
      end
    end
  end
end
