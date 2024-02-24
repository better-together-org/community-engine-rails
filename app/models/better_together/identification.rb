# frozen_string_literal: true

module BetterTogether
  # Represents the connection betwen an identity (eg: user) with an agent (eg: person)
  class Identification < ApplicationRecord
    belongs_to :identity,
               polymorphic: true,
               autosave: true
    belongs_to :agent,
               polymorphic: true,
               autosave: true

    validates :identity,
              presence: true
    validates :agent,
              presence: true
    validates :active,
              inclusion: { in: [true, false] },
              uniqueness: {
                scope: %i[agent_type agent_id]
              }
    validates :identity_id,
              uniqueness: {
                scope: %i[identity_type agent_type agent_id]
              }
  end
end
