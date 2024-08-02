# frozen_string_literal: true

module BetterTogether
  module Users
    class ConfirmationsController < ::Devise::ConfirmationsController
      include DeviseLocales
    end
  end
end
