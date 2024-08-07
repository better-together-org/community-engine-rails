# frozen_string_literal: true

module BetterTogether
  module Users
    class PasswordsController < ::Devise::PasswordsController
      include DeviseLocales
    end
  end
end
