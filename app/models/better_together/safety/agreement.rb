# frozen_string_literal: true

module BetterTogether
  module Safety
    # Restorative agreement tracked as part of a safety case.
    class Agreement < ApplicationRecord
      self.table_name = 'better_together_safety_agreements'

      enum :status, {
        proposed: 'proposed',
        active: 'active',
        completed: 'completed',
        breached: 'breached',
        withdrawn: 'withdrawn'
      }, prefix: true

      belongs_to :safety_case, class_name: 'BetterTogether::Safety::Case', inverse_of: :agreements
      belongs_to :created_by, class_name: 'BetterTogether::Person', inverse_of: :created_safety_agreements

      validates :summary, presence: true
      validates :commitments, presence: true
      validates :status, presence: true

      scope :recent_first, -> { order(created_at: :desc) }
    end
  end
end
