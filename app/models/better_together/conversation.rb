# frozen_string_literal: true

module BetterTogether
  # groups messages for participants
  class Conversation < ApplicationRecord
    belongs_to :creator, class_name: 'BetterTogether::Person'
    has_many :messages, dependent: :destroy
    has_many :conversation_participants, dependent: :destroy
    has_many :participants, through: :conversation_participants, source: :person

  end
end
