# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController # rubocop:todo Metrics/ClassLength
    include InvitationTokenAuthorization
    include NotificationReadable

    # Prepend resource instance setting for privacy check
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Lint/CopDirectiveSyntax
    prepend_before_action :set_resource_instance, only: %i[show edit update destroy ics]
    # rubocop:enable Lint/CopDirectiveSyntax
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity
    prepend_before_action :set_event_for_privacy_check, only: [:show]

    before_action if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

    before_action :build_event_hosts, only: :new
    before_action :process_recurrence_attributes, only: %i[create update]

    def index
      @draft_events = @events.draft
      @upcoming_events = @events.upcoming
      @ongoing_events = @events.ongoing
      @past_events = @events.past
    end

    def show
      return render_event_card if card_request?

      load_invitations
      mark_match_notifications_read_for(resource_instance)

      respond_to do |format|
        format.html { super }
        format.ics do
          authorize @event, :ics?
          render_event_ics
        end
      end
    end

    def ics
      authorize @event, :ics?
      send_data @event.to_ics,
                filename: "#{@event.slug}.ics",
                type: 'text/calendar; charset=UTF-8'
    end

    # Returns available hosts for a given host type (Person, Community, etc.)
    # Used by the event hosts form to populate dropdown options
    def available_hosts # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      authorize BetterTogether::Event, :available_hosts?

      host_type = params[:host_type]

      # Validate host type is allowed
      valid_host_types = BetterTogether::HostsEvents.included_in_models
      host_class = valid_host_types.find { |klass| klass.to_s == host_type }

      unless host_class
        render json: { error: 'Invalid host type' }, status: :unprocessable_entity
        return
      end

      # Get policy-scoped hosts
      policy_scope = Pundit.policy_scope!(current_user, host_class)

      # Filter by valid event host IDs for the current person
      valid_ids = helpers.current_person.valid_event_host_ids
      available = policy_scope.where(id: valid_ids)

      # Format for SlimSelect with slug or identifier included
      options = available.map do |host|
        text = host.to_s
        if host.respond_to?(:slug) && host.slug.present?
          text = "#{text} (#{host.slug})"
        elsif host.respond_to?(:identifier) && host.identifier.present?
          text = "#{text} (#{host.identifier})"
        end
        { value: host.id, text: text }
      end

      render json: options
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

    def card_request?
      request.xhr? && (request.headers['X-Card-Request'] == 'true' || request.headers['HTTP_X_CARD_REQUEST'] == 'true')
    end

    def render_event_card
      render partial: 'better_together/events/event', locals: { event: @event }, layout: false
    end

    def render_event_ics
      send_data @event.to_ics,
                filename: "#{@event.slug}.ics",
                type: 'text/calendar; charset=UTF-8',
                disposition: 'attachment'
    end

    def load_invitations
      @current_invitation = find_invitation_by_token
      @invitation = @current_invitation || BetterTogether::EventInvitation.new(invitable: @event, inviter: helpers.current_person)
      @invitations = BetterTogether::EventInvitation.where(invitable: @event).order(:status, :created_at)
    end

    def build_event_hosts # rubocop:disable Metrics/AbcSize
      # Build from params if host_id and host_type are provided (e.g., from community/partner/venue)
      if params[:host_id].present? && params[:host_type].present? && event_host_class
        policy_scope = Pundit.policy_scope!(current_user, event_host_class)
        host_record = policy_scope.find_by(id: params[:host_id])
        if host_record
          # Reload to avoid stale object errors in case the record was modified elsewhere
          host_record.reload if host_record.persisted?
          resource_instance.event_hosts.build(host: host_record)
        end
      end

      # Ensure at least one host exists (current_person as default)
      return unless resource_instance.event_hosts.empty?

      # Reload current_person to avoid stale object errors
      person = helpers.current_person
      person.reload if person&.persisted?
      resource_instance.event_hosts.build(host: person)
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

    # Template method implementations for InvitationTokenAuthorization
    def invitation_resource_name
      'event'
    end

    def invitation_class_for_resource
      BetterTogether::EventInvitation
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

    def invitation_invalid_or_expired?(invitation_any)
      expired = invitation_any.valid_until.present? && Time.current > invitation_any.valid_until
      !invitation_any.status_pending? || expired
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

      # Preload cover image attachment to avoid attachment queries
      @event.cover_image_attachment&.blob&.load if @event.cover_image.attached?

      # Preload location if present
      @event.location&.reload

      self
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    # Process recurrence_attributes from form and convert to IceCube rule
    def process_recurrence_attributes # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return unless params.dig(:event, :recurrence_attributes)

      recurrence_attrs = params[:event][:recurrence_attributes]

      # If destroy is requested, skip processing
      return if recurrence_attrs[:_destroy].present?

      # Skip if no frequency provided (form submitted empty)
      if recurrence_attrs[:frequency].blank?
        # Remove recurrence_attributes entirely if no frequency selected
        # This prevents validation errors when editing non-recurring events
        params[:event].delete(:recurrence_attributes)
        return
      end

      # Build IceCube schedule from form parameters
      schedule = build_schedule_from_params(recurrence_attrs)

      # Convert schedule to YAML and update params
      params[:event][:recurrence_attributes][:rule] = schedule.to_yaml

      # Log the generated rule in test environment
      Rails.logger.debug "[RECURRENCE] Generated rule YAML: #{schedule.to_yaml}" if Rails.env.test?

      # Process exception_dates from comma-separated string to array
      if recurrence_attrs[:exception_dates].present?
        dates = recurrence_attrs[:exception_dates]
                .split(',')
                .map(&:strip)
                .reject(&:blank?)
                .map do |d|
                  Date.parse(d)
        rescue StandardError
          nil
        end
                .compact

        params[:event][:recurrence_attributes][:exception_dates] = dates
      end

      # Clean up form-specific params that aren't database columns
      %i[frequency interval end_type count weekdays].each do |key|
        params[:event][:recurrence_attributes].delete(key)
      end
    end

    # Build an IceCube schedule from form parameters
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/PerceivedComplexity
    def build_schedule_from_params(attrs)
      # Get the event start time (use existing event or param)
      start_time = if @resource&.starts_at
                     @resource.starts_at
                   elsif params.dig(:event, :starts_at)
                     param_time = params[:event][:starts_at]
                     param_time.is_a?(String) ? Time.zone.parse(param_time) : param_time
                   else
                     Time.current
                   end

      schedule = IceCube::Schedule.new(start_time)

      # Build the recurrence rule based on frequency
      rule = case attrs[:frequency]
             when 'daily'
               IceCube::Rule.daily(attrs[:interval].to_i)
             when 'weekly'
               build_weekly_rule(attrs)
             when 'monthly'
               IceCube::Rule.monthly(attrs[:interval].to_i)
             when 'yearly'
               IceCube::Rule.yearly(attrs[:interval].to_i)
             end

      # Add end condition
      case attrs[:end_type]
      when 'until'
        rule = rule.until(Date.parse(attrs[:ends_on])) if attrs[:ends_on].present?
      when 'count'
        rule = rule.count(attrs[:count].to_i) if attrs[:count].present?
        # 'never' doesn't add any end condition
      end

      schedule.add_recurrence_rule(rule)
      schedule
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    # Build a weekly recurrence rule with weekday restrictions
    def build_weekly_rule(attrs)
      rule = IceCube::Rule.weekly(attrs[:interval].to_i)

      # Add weekday restrictions if provided
      if attrs[:weekdays].present?
        weekdays = attrs[:weekdays].is_a?(Array) ? attrs[:weekdays] : [attrs[:weekdays]]
        weekdays.each do |day|
          rule = rule.day(day.to_sym) if day.present?
        end
      end

      rule
    end
  end
end
