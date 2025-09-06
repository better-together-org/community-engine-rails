# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController # rubocop:todo Metrics/ClassLength
  include InvitationTokenAuthorization

  # Process event invitation tokens before inherited (ApplicationController) callbacks
  # so we can bypass platform privacy checks for valid event invitations and
  # return 404 for invalid tokens when the platform is private.
  prepend_before_action :process_event_invitation_for_privacy, only: %i[show]

    # Override privacy check to handle event-specific invitation tokens.
    # This keeps event lookup logic inside the events controller and avoids
    # embedding event knowledge in ApplicationController.
    def check_platform_privacy
      # If host platform is public or user is signed in, let ApplicationController handle it
      return super if helpers.host_platform.privacy_public? || current_user.present?

      token = params[:invitation_token].presence || params[:token].presence
      if token.present? && params[:id].present?
        # Attempt to find the event and a matching pending, not-expired invitation
  event = ::BetterTogether::Event.friendly.find_by(slug: params[:id]) || ::BetterTogether::Event.find_by(id: params[:id])

        if event
          invitation = ::BetterTogether::EventInvitation.pending.not_expired.find_by(token: token, invitable: event)
          if invitation
            # Valid invitation: set locale and allow access
            I18n.locale = invitation.locale if invitation.locale.present?
            session[:locale] = I18n.locale
            return true
          else
            # Invalid token for this event on a private platform: render 404
            render_not_found
            return
          end
        end
      end

      # Fall back to ApplicationController implementation for other cases
      super
    end

    # Override parent controller's before_actions to include RSVP actions
    before_action :set_resource_instance, only: %i[show edit update destroy ics rsvp_interested rsvp_going rsvp_cancel]
    before_action :authorize_resource, only: %i[new show edit update destroy ics rsvp_interested rsvp_going rsvp_cancel]

    before_action if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

  # Ensure event invitation is processed before ApplicationController privacy checks
  prepend_before_action :set_event_invitation, if: -> { params[:invitation_token].present? }
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

      # Check for valid invitation if accessing via invitation token
      @current_invitation = find_invitation_by_token if params[:invitation_token].present?

      super
    end

    def ics
      authorize @event, :ics?
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

    def rsvp_cancel # rubocop:disable Metrics/MethodLength
      set_resource_instance
      return if performed? # Exit early if 404 was already rendered

      @event = @resource
      authorize @event, :show?

      # Ensure current_person exists
      current_person = helpers.current_person
      unless current_person
        redirect_to @event, alert: t('better_together.events.login_required', default: 'Please log in to manage RSVPs.')
        return
      end

      attendance = BetterTogether::EventAttendance.find_by(event: @event, person: current_person)
      attendance&.destroy
      redirect_to @event, notice: t('better_together.events.rsvp_cancelled', default: 'RSVP cancelled')
    end

    protected

    # Called early (prepended) to handle invitation tokens for privacy decisions.
    def process_event_invitation_for_privacy
      token = params[:invitation_token] || params[:token]
      return unless token.present?

      # Attempt to set the event invitation (this sets @event_invitation when valid)
      set_event_invitation

      if @event_invitation.present?
        # Mark that the privacy check should be bypassed for this request
        @skip_platform_privacy = true
        # Ensure the application's locale honors the invitation's locale immediately
        if @event_invitation.locale.present?
          I18n.locale = @event_invitation.locale
          params[:locale] = @event_invitation.locale
          session[:locale] = @event_invitation.locale
        end
      else
        # Token was present but invalid for this event - mark so caller can render 404
        @invalid_event_invitation_present = true
      end
    end

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

    def resource_collection
      # Set invitation token for policy scope
      invitation_token = params[:invitation_token] || session[:event_invitation_token]
      set_current_invitation_token(invitation_token)

      policy_scope(resource_class)
    end

    # Override the parent's authorize_resource method to include invitation token context
    def authorize_resource
      # Set invitation token for authorization
      invitation_token = params[:invitation_token] || session[:event_invitation_token]
      set_current_invitation_token(invitation_token)

      authorize resource_instance
    end

    # Helper method to find invitation by token
    def find_invitation_by_token
      return nil unless params[:invitation_token].present?

      BetterTogether::EventInvitation.find_by(
        token: params[:invitation_token],
        invitable: @event
      )
    end

    private

    # rubocop:todo Metrics/MethodLength
    def rsvp_update(status) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      set_resource_instance
      return if performed? # Exit early if 404 was already rendered

      @event = @resource
      authorize @event, :show?

      # Check if event allows RSVP
      unless @event.scheduled?
        redirect_to @event,
                    alert: t('better_together.events.rsvp_not_available',
                             default: 'RSVP is not available for this event.')
        return
      end

      # Ensure current_person exists before creating attendance
      current_person = helpers.current_person
      unless current_person
        redirect_to @event, alert: t('better_together.events.login_required', default: 'Please log in to RSVP.')
        return
      end

      attendance = BetterTogether::EventAttendance.find_or_initialize_by(event: @event, person: current_person)
      attendance.status = status
      authorize attendance
      if attendance.save
        redirect_to @event, notice: t('better_together.events.rsvp_saved', default: 'RSVP saved')
      else
        redirect_to @event, alert: attendance.errors.full_messages.to_sentence
      end
    end
    # rubocop:enable Metrics/MethodLength

    # Override base controller method to add performance optimizations
    def set_resource_instance
      # Fix the resource finding logic - try friendly lookup first
      slug_event = BetterTogether::Event.friendly.find_by(slug: params[:id])
      direct_event = BetterTogether::Event.find_by(id: params[:id])

      @resource = slug_event if slug_event.present?
      @resource ||= direct_event if direct_event.present?

      if @resource.nil?
        # Fall back to parent logic only if we can't find it
        super
      else
        # Set the instance variable like the parent does
        instance_variable_set("@#{resource_name}", @resource)
      end

      # Preload associations needed for event show page to avoid N+1 queries
      preload_event_associations! unless json_request?
    end

    def json_request?
      request.format.json?
    end

    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/MethodLength
    def preload_event_associations! # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize
      return unless @event

      # Preload categories and their translations to avoid N+1 queries
      @event.categories.includes(:string_translations).load

      # Preload event hosts and their associated models
      @event.event_hosts.includes(:host).load

      # Preload event attendances to avoid count queries in view
      @event.event_attendances.includes(:person).load

      # Preload current person's attendance for RSVP buttons
      if current_user&.person
        @current_attendance = @event.event_attendances.find do |a|
          a.person_id == current_user.person.id
        end
      end

      # Preload translations for the event itself
      @event.string_translations.load
      @event.text_translations.load

      # Preload cover image attachment to avoid attachment queries
      @event.cover_image_attachment&.blob&.load if @event.cover_image.attached?

      # Preload location if present
      @event.location&.reload

      self
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
  end
end
