# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController
    before_action if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

    def index
      @events = @events
                  .includes(:categories, cover_image_attachment: :blob)

      @draft_events = @events.draft
                               .page(params[:draft_page]).per(params[:per])
      @upcoming_events = @events.upcoming
                                 .page(params[:upcoming_page]).per(params[:per])
      @past_events = @events.past
                              .page(params[:past_page]).per(params[:per])
    end

    protected

    def resource_class
      ::BetterTogether::Event
    end
  end
end
