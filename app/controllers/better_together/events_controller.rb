# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController # rubocop:todo Metrics/ClassLength
    include InvitationTokenAuthorization
    include NotificationReadable

    # Prepend resource instance setting for privacy check
    prepend_before_action :set_resource_instance, only: %i[show ics]
    prepend_before_action :set_event_for_privacy_check, only: [:show]

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

      # Check for valid invitation if accessing via invitation token
      @current_invitation = find_invitation_by_token

      mark_match_notifications_read_for(resource_instance)

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
      self.current_invitation_token = invitation_token

      super
    end

    # Override the parent's authorize_resource method to include invitation token context
    def authorize_resource
      # Set invitation token for authorization
      invitation_token = params[:invitation_token] || session[:event_invitation_token]
      self.current_invitation_token = invitation_token

      authorize resource_instance
    end

    # Helper method to find invitation by token
    def find_invitation_by_token
      token = extract_invitation_token
      return nil unless token.present?

      invitation = find_valid_invitation(token)
      persist_invitation_to_session(invitation, token) if invitation
      invitation
    end

    private

    def extract_invitation_token
      params[:invitation_token].presence || params[:token].presence || current_invitation_token
    end

    def find_valid_invitation(token)
      if @event
        BetterTogether::EventInvitation.pending.not_expired.find_by(token: token, invitable: @event)
      else
        BetterTogether::EventInvitation.pending.not_expired.find_by(token: token)
      end
    end

    def persist_invitation_to_session(invitation, _token)
      return unless token_came_from_params?

      store_invitation_in_session(invitation)
      locale_from_invitation(invitation)
      self.current_invitation_token = invitation.token
    end

    def token_came_from_params?
      params[:invitation_token].present? || params[:token].present?
    end

    def store_invitation_in_session(invitation)
      session[:event_invitation_token] = invitation.token
      session[:event_invitation_expires_at] = platform_invitation_expiry_time.from_now
    end

    def locale_from_invitation(invitation)
      return unless invitation.locale.present?

      I18n.locale = invitation.locale
      session[:locale] = I18n.locale
    end

    # Process event invitation tokens before inherited (ApplicationController) callbacks
    # so we can bypass platform privacy checks for valid event invitations and
    # return 404 for invalid tokens when the platform is private.
    # prepend_before_action :process_event_invitation_for_privacy, only: %i[show]

    # Override privacy check to handle event-specific invitation tokens.
    # This keeps event lookup logic inside the events controller and avoids
    # embedding event knowledge in ApplicationController.
    def check_platform_privacy
      return super if platform_public_or_user_authenticated?

      token = extract_invitation_token_for_privacy
      return super unless token_and_params_present?(token)

      invitation_any = find_any_invitation_by_token(token)
      return render_not_found unless invitation_any.present?

      return redirect_to_sign_in if invitation_invalid_or_expired?(invitation_any)

      result = handle_valid_invitation_token(token)
      return result if result # Return true if invitation processed successfully

      # Fall back to ApplicationController implementation for other cases
      super
    end

    def platform_public_or_user_authenticated?
      helpers.host_platform.privacy_public? || current_user.present?
    end

    def extract_invitation_token_for_privacy
      params[:invitation_token].presence || params[:token].presence || session[:event_invitation_token].presence
    end

    def token_and_params_present?(token)
      token.present? && params[:id].present?
    end

    def find_any_invitation_by_token(token)
      ::BetterTogether::EventInvitation.find_by(token: token)
    end

    def invitation_invalid_or_expired?(invitation_any)
      expired = invitation_any.valid_until.present? && Time.current > invitation_any.valid_until
      !invitation_any.pending? || expired
    end

    def redirect_to_sign_in
      redirect_to new_user_session_path(locale: I18n.locale)
    end

    def handle_valid_invitation_token(token)
      invitation = ::BetterTogether::EventInvitation.pending.not_expired.find_by(token: token)
      return render_not_found_for_mismatched_invitation unless invitation&.invitable.present?

      event = load_event_safely
      return false unless event # Return false to fall back to super in check_platform_privacy
      return render_not_found unless invitation_matches_event?(invitation, event)

      store_invitation_and_grant_access(invitation)
    end

    def render_not_found_for_mismatched_invitation
      render_not_found
    end

    def load_event_safely
      @event || resource_class.friendly.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def invitation_matches_event?(invitation, event)
      invitation.invitable.id == event.id
    end

    def store_invitation_and_grant_access(invitation)
      session[:event_invitation_token] = invitation.token
      session[:event_invitation_expires_at] = 24.hours.from_now
      I18n.locale = invitation.locale if invitation.locale.present?
      session[:locale] = I18n.locale
      self.current_invitation_token = invitation.token
    end

    def set_event_for_privacy_check
      @event = @resource if @resource.is_a?(BetterTogether::Event)
    end

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
      super

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
      if current_person
        @current_attendance = @event.event_attendances.find do |a|
          a.person_id == current_person.id
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
