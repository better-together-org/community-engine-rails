# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController
    before_action if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

    before_action :build_event_hosts, only: :new

    def index
      @draft_events = @events.draft
      @upcoming_events = @events.upcoming
      @past_events = @events.past
    end

    def show
      # Handle AJAX requests for card format - only our specific hover card requests
      card_request = request.headers['X-Card-Request'] == 'true' || request.headers['HTTP_X_CARD_REQUEST'] == 'true'

      if request.xhr? && card_request
        render partial: 'better_together/events/event', locals: { event: @event }, layout: false
        return
      end

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

    def build_event_hosts # rubocop:disable Metrics/AbcSize
      return unless params[:host_id].present? && params[:host_type].present?

      return unless event_host_class

      policy_scope = Pundit.policy_scope!(current_user, event_host_class)
      host_record = policy_scope.find_by(id: params[:host_id])
      return unless host_record

      resource_instance.event_hosts.build(
        host_id: params[:host_id],
        host_type: params[:host_type]
      )
    end

    def event_host_class
      param_type = params[:host_type]

      # Allow-list only specific classes to be set as host for an event
      valid_host_types = BetterTogether::HostsEvents.included_in_models
      valid_host_types.find { |klass| klass.to_s == param_type }
    end

    def resource_class
      ::BetterTogether::Event
    end

    private

    # rubocop:todo Metrics/MethodLength
    def rsvp_update(status) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @event = set_resource_instance
      authorize @event, :show?

      # Check if event allows RSVP
      unless @event.scheduled?
        redirect_to @event,
                    alert: t('better_together.events.rsvp_not_available',
                             default: 'RSVP is not available for this event.')
        return
      end

      attendance = BetterTogether::EventAttendance.find_or_initialize_by(event: @event,
                                                                         person: helpers.current_person)
      attendance.status = status
      authorize attendance
      if attendance.save
        redirect_to @event, notice: t('better_together.events.rsvp_saved', default: 'RSVP saved')
      else
        redirect_to @event, alert: attendance.errors.full_messages.to_sentence
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
