module BetterTogether
  module Users
    class UnlocksController < ::Devise::UnlocksController
      include DeviseLocales
    end
  end
end
