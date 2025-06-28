# frozen_string_literal: true

module BetterTogether
  # Internal hub for logged-in users to see relevant platform & community information
  class HubController < ApplicationController
    def index
      authorize :'better_together/hub', :index?
      @activities = helpers.activities
    end
  end
end
