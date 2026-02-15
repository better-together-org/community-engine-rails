# frozen_string_literal: true

module BetterTogether
  module Api
    module Doorkeeper
      # Wrapper for Doorkeeper's TokensController within the engine + API namespace
      # Required because use_doorkeeper inside `namespace :api` in engine routes
      # looks for BetterTogether::Api::Doorkeeper::TokensController
      class TokensController < ::Doorkeeper::TokensController
      end
    end
  end
end
