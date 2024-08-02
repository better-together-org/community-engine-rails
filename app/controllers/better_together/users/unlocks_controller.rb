# frozen_string_literal: true

module BetterTogether
  module Users
    class UnlocksController < ::Devise::UnlocksController
      include DeviseLocales
    end
  end
end
