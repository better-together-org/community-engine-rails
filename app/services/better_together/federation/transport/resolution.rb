# frozen_string_literal: true

module BetterTogether
  module Federation
    module Transport
      # Immutable transport selection result used by the pull-service orchestrator.
      Resolution = Struct.new(:tier, :adapter_class)
    end
  end
end
