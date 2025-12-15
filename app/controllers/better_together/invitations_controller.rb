# frozen_string_literal: true

module BetterTogether
  # Unified polymorphic controller for managing invitations across all invitable types
  # Handles both authenticated invitation management and token-based invitation acceptance
  class InvitationsController < ApplicationController # rubocop:todo Style/Documentation, Metrics/ClassLength
    # Token-based invitation handling (public access)
    # rubocop:todo Metrics/ClassLength
    # rubocop:todo Lint/CopDirectiveSyntax
    prepend_before_action :find_invitation_by_token, only: %i[show accept decline]
    # rubocop:enable Lint/CopDirectiveSyntax
    # rubocop:enable Metrics/ClassLength
    skip_before_action :check_platform_privacy, if: -> { @invitation.present? }, only: %i[show accept decline]

    # Authenticated invitation management
    before_action :set_invitable_resource, only: %i[create destroy resend available_people]
    before_action :set_invitation_config, only: %i[create destroy resend available_people]
    before_action :set_invitation, only: %i[destroy resend]
    after_action :verify_authorized, except: %i[show accept decline available_people]
    after_action :verify_policy_scoped, only: %i[available_people]

    # === Authenticated Invitation Management ===

    def create
      @invitation = build_invitation
      authorize @invitation

      # Check for existing declined invitations and handle resend scenario
      if @invitation.valid?
        existing_invitation = find_existing_invitation
        if existing_invitation&.declined? && force_resend?
          handle_declined_invitation_resend(existing_invitation)
        end
      end

      if @invitation.save
        notify_invitee(@invitation)
        respond_success(@invitation, :created)
      else
        respond_error(@invitation)
      end
    end

    def destroy
      authorize @invitation
      invitation_dom_id = helpers.dom_id(@invitation)
      @invitation.destroy

      respond_to do |format|
        format.html { redirect_to @invitable_resource, notice: t('flash.generic.destroyed', resource: t('resources.invitation')) }
        format.turbo_stream { render_destroy_turbo_stream(invitation_dom_id) }
        format.json { render json: { id: @invitation.id }, status: :ok }
      end
    end

    def resend
      authorize @invitation

      # Mark declined invitations as pending when resent
      if @invitation.status_declined?
        @invitation.update!(status: 'pending')
      end

      notify_invitee(@invitation)
      respond_success(@invitation, :ok)
    end

    def available_people
      invited_ids = invited_person_ids
      people = build_available_people_query(invited_ids)
      people = apply_search_filter(people) if params[:search].present?

      formatted_people = people.limit(20).map do |person|
        { value: person.id, text: person.name }
      end

      render json: formatted_people
    end

    # === Token-based Invitation Access (Public) ===

    def show
      @event = @invitation.invitable if @invitation.is_a?(BetterTogether::EventInvitation)
      @community = @invitation.invitable if @invitation.is_a?(BetterTogether::CommunityInvitation)
      render :show
    end

    def accept
      ensure_authenticated!
      return if performed?

      person = helpers.current_person
      return unless invitee_authorized?(person)

      process_invitation_acceptance(person)
      redirect_to polymorphic_path(@invitation.invitable),
                  notice: t('flash.generic.updated', resource: t('resources.invitation'))
    end

    def decline
      # ensure_authenticated!
      return if performed?

      process_invitation_decline
      redirect_to determine_decline_redirect_path,
                  notice: t('flash.generic.updated', resource: t('resources.invitation'))
    end

    private

    def find_existing_invitation
      return nil unless params[:invitation]&.[](:invitee_email)

      BetterTogether::Invitation.find_by(
        invitable: @invitation.invitable,
        invitee_email: params[:invitation][:invitee_email]
      )
    end

    def force_resend?
      params[:force_resend].present?
    end

    # === Authenticated Invitation Management Helpers ===

    def set_invitable_resource
      # Determine invitable type from route parameters
      invitable_param = determine_invitable_param
      invitable_id = params[invitable_param]

      # Get the invitable class from the parameter name
      invitable_type = invitable_param.to_s.gsub('_id', '').classify
      invitable_class = "BetterTogether::#{invitable_type}".constantize

      @invitable_resource = if invitable_class.respond_to?(:friendly)
                              invitable_class.friendly.find(invitable_id)
                            else
                              invitable_class.find(invitable_id)
                            end
    rescue StandardError => e
      Rails.logger.error "Failed to find invitable resource: #{e.message}"
      render_not_found
    end

    def set_invitation_config
      @invitation_config = BetterTogether::InvitationRegistry.config_for(@invitable_resource.class)
    end

    def set_invitation
      @invitation = @invitation_config.invitation_class.find(params[:id])
    rescue StandardError
      render_not_found
    end

    def determine_invitable_param
      # Look for parameters ending with '_id' that aren't 'id' itself
      invitable_params = params.keys.select { |key| key.end_with?('_id') && key != 'id' }

      if invitable_params.empty?
        raise ArgumentError, "No invitable parameter found in #{params.keys}"
      elsif invitable_params.size > 1
        raise ArgumentError, "Multiple invitable parameters found: #{invitable_params}"
      end

      invitable_params.first
    end

    def build_invitation
      invitation_params_hash = build_invitation_params
      handle_invitee_assignment(invitation_params_hash)
      @invitation_config.invitation_class.new(invitation_params_hash)
    end

    def build_invitation_params
      invitation_params_hash = invitation_params.to_h

      # Set the invitable resource and required fields
      invitation_params_hash[:invitable] = @invitable_resource
      invitation_params_hash[:inviter] = current_user.person
      invitation_params_hash[:status] = 'pending'
      invitation_params_hash[:locale] = params[:locale] || I18n.default_locale.to_s
      invitation_params_hash[:valid_from] = Time.current

      invitation_params_hash
    end

    def handle_invitee_assignment(invitation_params_hash)
      return unless invitation_params_hash[:invitee_id].present?

      person = BetterTogether::Person.find(invitation_params_hash[:invitee_id])
      invitation_params_hash[:invitee] = person
      invitation_params_hash[:invitee_email] = person.email if person
      invitation_params_hash[:locale] = person.locale || invitation_params_hash[:locale]
      invitation_params_hash.delete(:invitee_id)
    end

    def invitation_params
      params.require(:invitation).permit(:invitee_email, :invitee_id, :message, :role_id, :force_resend)
    end

    def notify_invitee(invitation)
      # Simple throttling: skip if sent in last 15 minutes
      return if recently_sent?(invitation)

      if invitation.for_existing_user?
        # Use notifier for existing users
        @invitation_config.notifier_class.with(invitation:).deliver_later(invitation.invitee)
        invitation.update_column(:last_sent, Time.zone.now)
      else
        # Send email directly to external email address
        send_email_invitation(invitation)
      end
    end

    def recently_sent?(invitation)
      return false unless invitation.last_sent

      time_since_last_sent = Time.zone.now - invitation.last_sent
      if time_since_last_sent < 15.minutes
        Rails.logger.info("Invitation #{invitation.id} recently sent; skipping resend")
        true
      else
        false
      end
    end

    def send_email_invitation(invitation)
      @invitation_config.mailer_class.with(invitation:).invite.deliver_later
      invitation.update_column(:last_sent, Time.zone.now)
    end

    def respond_success(invitation, status)
      respond_to do |format|
        format.html { redirect_to @invitable_resource, notice: success_message(invitation) }
        format.turbo_stream { render_success_turbo_stream(status) }
        format.json { render json: invitation, status: }
      end
    end

    def respond_error(invitation)
      error_message = invitation.errors.full_messages.to_sentence

      respond_to do |format|
        format.html do
          redirect_to @invitable_resource, alert: error_message, status: :see_other
        end
        format.turbo_stream do
          flash.now[:alert] = error_message
          render_error_turbo_stream
        end
        format.json { render json: invitation.errors, status: :unprocessable_entity }
      end
    end

    def success_message(invitation)
      if invitation.for_existing_user?
        t('flash.generic.created', resource: t('resources.invitation'))
      else
        t('flash.generic.queued', resource: t('resources.invitation'))
      end
    end

    def render_destroy_turbo_stream(invitation_dom_id)
      render turbo_stream: turbo_stream.remove(invitation_dom_id)
    end

    def render_error_turbo_stream
      render turbo_stream: turbo_stream.replace(
        'flash_messages',
        partial: 'layouts/better_together/flash_messages',
        locals: { flash: }
      ), status: :unprocessable_entity
    end

    def render_success_turbo_stream(status)
      flash.now[:notice] = t('flash.generic.queued', resource: t('resources.invitation'))
      invitation_rows_html = build_invitation_rows_html

      render turbo_stream: [
        flash_messages_stream,
        invitation_table_update_stream(invitation_rows_html)
      ], status:
    end

    def build_invitation_rows_html
      @invitable_resource.invitations.order(:status, :created_at).map do |invitation|
        render_invitation_row(invitation)
      end.join
    end

    def render_invitation_row(invitation)
      render_to_string(
        partial: @invitation_config.partial_path,
        formats: [:html],
        locals: invitation_row_locals(invitation)
      )
    end

    def invitation_row_locals(invitation)
      {
        invitation_row: invitation,
        resend_path: generate_resend_path(invitation),
        destroy_path: generate_destroy_path(invitation)
      }
    end

    def flash_messages_stream
      turbo_stream.replace('flash_messages',
                           partial: 'layouts/better_together/flash_messages',
                           locals: { flash: })
    end

    def invitation_table_update_stream(invitation_rows_html)
      turbo_stream.update(@invitation_config.table_body_id, invitation_rows_html)
    end

    def generate_resend_path(invitation)
      case @invitable_resource
      when BetterTogether::Community
        resend_community_invitation_path(@invitable_resource, invitation)
      when BetterTogether::Event
        resend_event_invitation_path(@invitable_resource, invitation)
      when BetterTogether::Platform
        resend_platform_platform_invitation_path(@invitable_resource, invitation)
      else
        raise "Unsupported invitable resource type: #{@invitable_resource.class}"
      end
    end

    def generate_destroy_path(invitation)
      case @invitable_resource
      when BetterTogether::Community
        community_invitation_path(@invitable_resource, invitation)
      when BetterTogether::Event
        event_invitation_path(@invitable_resource, invitation)
      when BetterTogether::Platform
        platform_platform_invitation_path(@invitable_resource, invitation)
      else
        raise "Unsupported invitable resource type: #{@invitable_resource.class}"
      end
    end

    def invited_person_ids
      @invitation_config.invitation_class
                        .where(invitable: @invitable_resource, invitee_type: 'BetterTogether::Person')
                        .where.not(invitee_id: nil)
                        .pluck(:invitee_id)
    end

    def build_available_people_query(invited_ids)
      excluded_ids = @invitation_config.additional_exclusions(@invitable_resource, invited_ids)

      policy_scope(BetterTogether::Person)
        .where.not(id: excluded_ids)
        .i18n
        .order(:name)
    end

    def apply_search_filter(people)
      search_term = params[:search].strip
      return people if search_term.blank?

      people.joins(:string_translations)
            .where(
              'mobility_string_translations.value ILIKE ? AND mobility_string_translations.key IN (?)',
              "%#{search_term}%",
              %w[name]
            )
    end

    # === Token-based Invitation Access Helpers ===

    def find_invitation_by_token
      token = params[:invitation_token].presence || params[:token].presence
      @invitation = BetterTogether::Invitation.pending.not_expired.find_by(token: token)
      render_not_found unless @invitation
    end

    def ensure_authenticated!
      return if current_user

      store_invitation_in_session
      redirect_to determine_auth_redirect_path, notice: determine_auth_notice
    end

    def store_invitation_in_session
      # Store invitation token in session for after authentication
      if @invitation.is_a?(BetterTogether::EventInvitation)
        session[:event_invitation_token] = @invitation.token
        session[:event_invitation_expires_at] = 24.hours.from_now
      elsif @invitation.is_a?(BetterTogether::CommunityInvitation)
        session[:community_invitation_token] = @invitation.token
        session[:community_invitation_expires_at] = 24.hours.from_now
      end
    end

    def determine_auth_redirect_path
      if BetterTogether::User.find_by(email: @invitation.invitee_email).present?
        new_user_session_path(locale: I18n.locale)
      else
        new_user_registration_path(locale: I18n.locale)
      end
    end

    def determine_auth_notice
      if BetterTogether::User.find_by(email: @invitation.invitee_email).present?
        t('better_together.invitations.login_to_respond',
          default: 'Please log in to respond to your invitation.')
      else
        t('better_together.invitations.register_to_respond',
          default: 'Please register to respond to your invitation.')
      end
    end

    def invitee_authorized?(person)
      if @invitation.invitee.present? && @invitation.invitee != person
        redirect_to new_user_session_path(locale: I18n.locale), alert: t('flash.generic.unauthorized')
        false
      else
        true
      end
    end

    def process_invitation_acceptance(person)
      @invitation.update!(invitee: person) if @invitation.invitee.blank?
      if @invitation.respond_to?(:accept!)
        # EventInvitation implements accept!(invitee_person:)
        @invitation.accept!(invitee_person: person)
      else
        @invitation.update!(status: 'accepted')
      end
    end

    def process_invitation_decline
      if @invitation.respond_to?(:decline!)
        @invitation.decline!
      else
        @invitation.update!(status: 'declined')
      end
    end

    def determine_decline_redirect_path
      # For event invitations, redirect to the event. Otherwise use root path.
      if @invitation.respond_to?(:event) && @invitation.event
        polymorphic_path(@invitation.invitable)
      else
        main_app.root_path(locale: I18n.locale)
      end
    end

    # Override authorization to use invitation-type-specific policies
    def authorize(record, query = nil)
      return super unless @invitation_config

      policy_class = @invitation_config.policy_class
      super(record, query, policy_class:)
    rescue Pundit::NotDefinedError
      # Fall back to base invitation policy if specific policy doesn't exist
      super(record, query, policy_class: BetterTogether::InvitationPolicy)
    end

    def handle_declined_invitation_resend(existing_invitation)
      # Delete the old declined invitation to avoid unique constraint violation
      existing_invitation.destroy!

      # Set the force_resend flag on the new invitation to bypass validation
      @invitation.force_resend = true
    end
  end
end
