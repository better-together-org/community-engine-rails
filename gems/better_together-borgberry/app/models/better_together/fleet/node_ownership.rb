# frozen_string_literal: true

module BetterTogether
  module Fleet
    # Tracks the single current owner of a fleet node.
    class NodeOwnership < ApplicationRecord
      self.table_name = 'better_together_fleet_node_ownerships'

      belongs_to :node,
                 class_name: 'BetterTogether::Fleet::Node',
                 inverse_of: :node_ownership
      belongs_to :owner, polymorphic: true

      validates :node_id, uniqueness: true
    end
  end
end
