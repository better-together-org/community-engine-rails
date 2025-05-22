# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController
    def index
      @draft_events = @events.draft
      @upcoming_events = @events.upcoming
      @past_events = @events.past
    end

    protected

    def resource_class
      ::BetterTogether::Event
    end
  end
end
