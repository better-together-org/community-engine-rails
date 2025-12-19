# frozen_string_literal: true

module BetterTogether
  class CommunitiesController < FriendlyResourceController # rubocop:todo Style/Documentation, Metrics/ClassLength
    include InvitationTokenAuthorization
    include NotificationReadable

    # Prepend resource instance setting for privacy check
    # rubocop:todo Metrics/ClassLength
    # rubocop:todo Lint/CopDirectiveSyntax
    prepend_before_action :set_resource_instance, only: %i[show edit update destroy]
    # rubocop:enable Lint/CopDirectiveSyntax
    # rubocop:enable Metrics/ClassLength
    prepend_before_action :set_community_for_privacy_check, only: [:show]
    prepend_before_action :process_community_invitation_token, only: %i[show]

    before_action :set_model_instance, only: %i[show edit update destroy]
    before_action :authorize_community, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /communities
    def index
      authorize resource_class
      @communities = policy_scope(resource_collection)
    end

    # GET /communities/1
    def show
      # Check for valid invitation if accessing via invitation token
      @current_invitation = find_invitation_by_token
      @invitations = BetterTogether::CommunityInvitation.where(invitable: @community)
                                                        .order(:status, :created_at)

      # Categorize events for display
      categorize_community_events

      mark_match_notifications_read_for(resource_instance)
    end

    # GET /communities/new
    def new
      @community = resource_class.new
      authorize_community
    end

    # GET /communities/1/edit
    def edit; end

    # POST /communities
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @community = resource_class.new(community_params)
      @community.creator = helpers.current_person if helpers.current_person
      authorize_community

      respond_to do |format|
        if @community.save
          flash[:notice] = t('community.created')
          format.html { redirect_to @community, notice: t('community.created') }
          format.turbo_stream do
            redirect_to @community, only_path: true
          end
        else
          flash.now[:alert] = t('community.create_failed')
          format.html { render :new, status: :unprocessable_content }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors',
                                                 locals: { object: @community }),
              turbo_stream.update('community_form', partial: 'better_together/communities/form',
                                                    locals: { community: @community })
            ]
          end
        end
      end
    end

    # PATCH/PUT /communities/1
    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      respond_to do |format|
        if @community.update(community_params)
          flash[:notice] = t('community.updated')
          format.html { redirect_to edit_community_path(@community), notice: t('community.updated') }
          format.turbo_stream do
            redirect_to edit_community_path(@community), only_path: true
          end
        else
          flash.now[:alert] = t('community.update_failed')
          format.html { render :new, status: :unprocessable_content }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors',
                                                 locals: { object: @community }),
              turbo_stream.update('community_form', partial: 'communities/form',
                                                    locals: { community: @community })
            ]
          end
        end
      end
    end

    # DELETE /communities/1
    def destroy
      @community.destroy
      redirect_to communities_url, notice: t('flash.generic.destroyed', resource: t('resources.community')),
                                   status: :see_other
    end

    private

    def set_model_instance
      @community = set_resource_instance
    end

    def community_params
      params.require(resource_class.name.demodulize.underscore.to_sym).permit(permitted_attributes)
    end

    # Adds a policy check for the community
    def authorize_community
      authorize @community
    end

    def permitted_attributes
      %i[
        privacy
      ].concat(BetterTogether::Community.localized_attribute_list)
        .concat(resource_class.extra_permitted_attributes)
    end

    def resource_class
      ::BetterTogether::Community
    end

    def resource_collection
      # Set invitation token for policy scope
      invitation_token = params[:invitation_token] || session[:community_invitation_token]
      self.current_invitation_token = invitation_token

      resource_class.with_translations
    end

    # Override the parent's authorize_resource method to include invitation token context
    def authorize_resource
      # Set invitation token for authorization
      invitation_token = params[:invitation_token] || session[:community_invitation_token]
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

    def process_community_invitation_token
      invitation_token = params[:invitation_token] || session[:community_invitation_token]
      return unless invitation_token.present?

      # Find and validate the invitation
      invitation = BetterTogether::CommunityInvitation.pending.not_expired.find_by(token: invitation_token)

      if invitation
        # Set invitation token for authorization
        self.current_invitation_token = invitation_token

        # Store invitation token in session for platform privacy bypass
        session[:community_invitation_token] = invitation_token
        session[:community_invitation_expires_at] = invitation.valid_until if invitation.valid_until.present?

        # Set locale from invitation if available
        I18n.locale = invitation.locale if invitation.locale.present?
      else
        # Clear invalid token from session
        session.delete(:community_invitation_token)
        session.delete(:community_invitation_expires_at)
      end
    end

    # Template method implementations for InvitationTokenAuthorization
    def invitation_resource_name
      'community'
    end

    def invitation_class_for_resource
      BetterTogether::CommunityInvitation
    end

    # Override privacy check to handle community-specific invitation tokens.
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
      invitation = ::BetterTogether::CommunityInvitation.pending.not_expired.find_by(token: token)
      unless invitation&.invitable.present?
        render_not_found
        return true # Return true to stop further processing
      end

      community = load_community_safely
      return false unless community # Return false to fall back to super in check_platform_privacy

      unless invitation_matches_community?(invitation, community)
        render_not_found
        return true # Return true to stop further processing
      end

      store_invitation_and_grant_access(invitation)
    end

    def load_community_safely
      @community || resource_class.friendly.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def invitation_matches_community?(invitation, community)
      invitation.invitable.id == community.id
    end

    def store_invitation_and_grant_access(invitation) # rubocop:todo Naming/PredicateMethod
      session[:community_invitation_token] = invitation.token
      session[:community_invitation_expires_at] = 24.hours.from_now
      I18n.locale = invitation.locale if invitation.locale.present?
      session[:locale] = I18n.locale
      self.current_invitation_token = invitation.token
      true # Return true to indicate successful processing
    end

    def set_community_for_privacy_check
      @community = @resource if @resource.is_a?(BetterTogether::Community)
    end

    def categorize_community_events
      @draft_events = policy_scope(@community.hosted_events).draft
      @upcoming_events = policy_scope(@community.hosted_events).upcoming
      @ongoing_events = policy_scope(@community.hosted_events).ongoing
      @past_events = policy_scope(@community.hosted_events).past
    end
  end
end
