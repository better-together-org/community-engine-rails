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

      categorizable class_name: '::BetterTogether::Joatu::Category'

      translates :name, type: :string
      translates :description, type: :text

      validates :name, :description, :creator, presence: true
      validates :categories, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }

      enum status: STATUS_VALUES, _prefix: :status

      def find_matches
        BetterTogether::Joatu::Matchmaker.match(self)
      end
    end
  end
end
