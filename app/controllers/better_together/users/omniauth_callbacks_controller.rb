# frozen_string_literal: true

module BetterTogether
  module Users
    class OmniauthCallbacksController < ::Devise::OmniauthCallbacksController
      include DeviseLocales
    end
  end
end
