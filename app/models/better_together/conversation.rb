# frozen_string_literal: true

module BetterTogether
  # groups messages for participants
  class Conversation < ApplicationRecord
    encrypts :title, deterministic: true
    belongs_to :creator, class_name: 'BetterTogether::Person'
    has_many :messages, dependent: :destroy
    has_many :conversation_participants, dependent: :destroy
    has_many :participants, through: :conversation_participants, source: :person
    validate :at_least_one_participant

    def to_s
      title
    end

    private

    def at_least_one_participant
      nil unless participants.empty?
    end
  end
end
