# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController
    before_action if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

    def index
      @draft_events = @events.draft
      @upcoming_events = @events.upcoming
      @past_events = @events.past
    end

    def show
      super
    end

    def ics
      send_data @event.to_ics,
                filename: "#{@event.slug}.ics",
                type: 'text/calendar; charset=UTF-8'
    end

    # RSVP actions
    def rsvp_interested
      rsvp_update('interested')
    end

    def rsvp_going
      rsvp_update('going')
    end

    def rsvp_cancel
      @event = set_resource_instance
      authorize @event, :show?
      attendance = BetterTogether::EventAttendance.find_by(event: @event, person: helpers.current_person)
      attendance&.destroy
      redirect_to @event, notice: t('better_together.events.rsvp_cancelled', default: 'RSVP cancelled')
    end

    protected

    def resource_class
      ::BetterTogether::Event
    end

    private

    def rsvp_update(status)
      @event = set_resource_instance
      authorize @event, :show?
      attendance = BetterTogether::EventAttendance.find_or_initialize_by(event: @event, person: helpers.current_person)
      attendance.status = status
      authorize attendance
      if attendance.save
        redirect_to @event, notice: t('better_together.events.rsvp_saved', default: 'RSVP saved')
      else
        redirect_to @event, alert: attendance.errors.full_messages.to_sentence
      end
    end
  end
end
