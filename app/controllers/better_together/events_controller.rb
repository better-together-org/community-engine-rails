# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController
    protected

    def resource_class
      ::BetterTogether::Event
    end
  end
end
