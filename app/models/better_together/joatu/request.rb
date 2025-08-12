# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request represents a need someone wants fulfilled
    class Request < ApplicationRecord
      include Categorizable
      include Creatable
      include Translatable

      STATUS_VALUES = {
        open: 'open',
        closed: 'closed'
      }.freeze

      has_many :agreements, class_name: 'BetterTogether::Joatu::Agreement', dependent: :destroy
      has_many :offers, class_name: 'BetterTogether::Joatu::Offer', through: :agreements

      belongs_to :target, polymorphic: true, optional: true

      categorizable class_name: '::BetterTogether::Joatu::Category'

      translates :name, type: :string
      translates :description, type: :text

      validates :name, :description, :creator, presence: true
      validates :categories, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validates :target_type, presence: true, if: :target_id?

      enum status: STATUS_VALUES, _prefix: :status

      def self.extra_permitted_attributes
        super + %i[target_type target_id]
      end

      after_commit :notify_matches, on: :create

      def find_matches
        BetterTogether::Joatu::Matchmaker.match(self)
      end

      private

      def notify_matches
        BetterTogether::Joatu::Matchmaker.match(self).find_each do |offer|
          BetterTogether::Joatu::MatchNotifier.with(offer:, request: self)
                                              .deliver(offer.creator)
        end
      end
    end
  end
end
