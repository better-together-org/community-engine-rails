# frozen_string_literal: true

module BetterTogether
  module Users
    class RegistrationsController < ::Devise::RegistrationsController
      include DeviseLocales
    end
  end
end
