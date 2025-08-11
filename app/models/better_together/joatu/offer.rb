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

      belongs_to :target, polymorphic: true, optional: true

      categorizable class_name: '::BetterTogether::Joatu::Category'

      translates :name, type: :string
      translates :description, type: :text

      validates :name, :description, :creator, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validates :target_type, presence: true, if: :target_id?

      enum status: STATUS_VALUES, _prefix: :status
    end
  end
end
