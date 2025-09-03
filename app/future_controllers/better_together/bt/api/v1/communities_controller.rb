# frozen_string_literal: true

module BetterTogether
  module Bt
    module Api
      module V1
        # JSONAPI resource for communities
        class CommunitiesController < ApiController
          before_action :authenticate_user!, except: %i[index]
        end
      end
    end
  end
end
