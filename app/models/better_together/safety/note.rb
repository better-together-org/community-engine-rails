# frozen_string_literal: true

module BetterTogether
  module Safety
    # Internal or participant-visible note attached to a safety case.
    class Note < ApplicationRecord
      self.table_name = 'better_together_safety_notes'

      enum :visibility, {
        internal_only: 'internal_only',
        participant_visible: 'participant_visible'
      }, prefix: true

      belongs_to :safety_case, class_name: 'BetterTogether::Safety::Case', inverse_of: :notes
      belongs_to :author, class_name: 'BetterTogether::Person'

      validates :body, presence: true
      validates :visibility, presence: true

      scope :chronological, -> { order(created_at: :asc) }
    end
  end
end
