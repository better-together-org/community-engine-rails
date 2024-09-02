module BetterTogether
  class ConversationParticipant < ApplicationRecord
    belongs_to :conversation
    belongs_to :person
  end
end
