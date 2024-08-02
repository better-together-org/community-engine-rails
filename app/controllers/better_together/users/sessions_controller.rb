# frozen_string_literal: true

module BetterTogether
  module Users
    class SessionsController < ::Devise::SessionsController
      include DeviseLocales
    end
  end
end
