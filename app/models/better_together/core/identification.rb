
module BetterTogether
  module Core
    class Identification < ApplicationRecord
      belongs_to :identity,
                 polymorphic: true
      belongs_to :agent,
                 polymorphic: true

      validates :identity,
                presence: true
      validates :agent,
                presence: true
      validates :active,
                presence: true,
                uniqueness: {
                  scope: %i(agent_type agent_id)
                }
      validates :identity_id,
                uniqueness: {
                  scope: %i(identity_type agent_type agent_id)
                }
    end
  end
end
