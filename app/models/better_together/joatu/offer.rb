# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Offer represents a service or item someone is willing to provide
    class Offer < ApplicationRecord
      include Categorizable
      include Creatable
      include Translatable

      STATUS_VALUES = {
        open: 'open',
        closed: 'closed'
      }.freeze

      has_many :agreements, class_name: 'BetterTogether::Joatu::Agreement', dependent: :destroy
      has_many :requests, class_name: 'BetterTogether::Joatu::Request', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'

      translates :name, type: :string
      translates :description, type: :text

      validates :name, :description, :creator, presence: true
      validates :categories, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }

      enum status: STATUS_VALUES, _prefix: :status

      after_commit :notify_matches, on: :create

      private

      def notify_matches
        BetterTogether::Joatu::Matchmaker.match(self).find_each do |request|
          BetterTogether::Joatu::MatchNotifier.with(offer: self, request:)
                                              .deliver(request.creator)
        end
      end
    end
  end
end
