module BetterTogether
  module Core
    class Engine < ::Rails::Engine
      isolate_namespace BetterTogether::Core
    end
  end
end
