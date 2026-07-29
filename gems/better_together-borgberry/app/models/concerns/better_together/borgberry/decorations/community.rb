# frozen_string_literal: true

module BetterTogether
  module Borgberry
    module Decorations
      # Applied to BetterTogether::Community by Borgberry::Engine's model registry
      # (config.to_prepare) when this extension is bundled. Moved out of core
      # Community as part of the C3/Fleet extraction, alongside the equivalent
      # Person decoration — see docs/borgberry-ce-integration.md.
      module Community
        extend ActiveSupport::Concern

        # `prepended do`, not `included do` — ModelRegistry applies decorations via
        # `prepend`; ActiveSupport::Concern only fires `included do` blocks for `include`.
        prepended do
          has_many :fleet_node_ownerships,
                   as: :owner,
                   class_name: 'BetterTogether::Fleet::NodeOwnership',
                   dependent: :destroy,
                   inverse_of: :owner
          has_many :fleet_nodes,
                   through: :fleet_node_ownerships,
                   source: :node
        end
      end
    end
  end
end
