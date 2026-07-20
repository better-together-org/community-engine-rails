# frozen_string_literal: true

module BetterTogether
  # Handles the new_platform_setup wizard steps for a single provisioning run,
  # identified by params[:platform_id] (the draft Platform created by
  # NewPlatformSetupController#start). Mirrors SetupWizardStepsController's
  # hand-written per-step pattern — WizardStepsController#update is an
  # unimplemented stub in the generic framework, so each step needs its own
  # actions here, same as the existing host_setup wizard.
  class NewPlatformSetupStepsController < WizardStepsController # rubocop:todo Metrics/ClassLength
    # NOTE: form classes are hardcoded per action below (NewPlatformIdentityForm,
    # NewPlatformStewardForm) rather than resolved dynamically via
    # WizardStepDefinition#form_class + SafeClassResolver — mirrors
    # SetupWizardStepsController's exact precedent; the generic
    # WizardStepsController#form/#update path is not exercised here either.

    skip_before_action :determine_wizard_outcome, only: %i[
      update_welcome create_platform_identity create_domain create_steward_account
      create_invite_members launch_platform
    ]
    before_action :authorize_target_platform
    before_action :ensure_wizard_incomplete

    # --- Step 1: welcome -------------------------------------------------

    def welcome
      find_or_create_wizard_step
      render wizard_step_definition.template
    end

    def update_welcome
      if params[:locale].present? && I18n.available_locales.map(&:to_s).include?(params[:locale])
        I18n.locale = params[:locale].to_sym
      end
      mark_current_step_as_completed
      wizard.reload
      determine_wizard_outcome
    end

    # --- Step 2: platform_identity ----------------------------------------

    def platform_identity
      find_or_create_wizard_step
      @platform = target_platform
      @form = ::BetterTogether::NewPlatformIdentityForm.new(@platform)
      render wizard_step_definition.template
    end

    def create_platform_identity # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @platform = target_platform
      @form = ::BetterTogether::NewPlatformIdentityForm.new(@platform)

      if @form.validate(platform_identity_params)
        ActiveRecord::Base.transaction do
          @platform.assign_attributes(platform_identity_params)

          if @platform.save!
            mark_current_step_as_completed
            wizard.reload
            determine_wizard_outcome
            return
          end
        end
      end

      @platform.assign_attributes(platform_identity_params) if platform_identity_params.present?
      flash.now[:alert] = t('.flash.please_address_errors')
      render wizard_step_definition.template, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      @platform = e.record
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render wizard_step_definition.template, status: :unprocessable_entity
    end

    # --- Step 3: domain (optional — reuses PlatformDomain from PR #1677) ---

    def domain
      find_or_create_wizard_step
      @platform = target_platform
      @host_apex = host_apex_hostname
      @platform_domain = @platform.platform_domains.build
      render wizard_step_definition.template
    end

    def create_domain # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @platform = target_platform

      # An explicit "Skip" click, or a blank hostname, both mean the steward
      # is skipping this optional step — the platform already has a primary
      # domain synced from its host_url (Platform#sync_primary_platform_domain!);
      # an extra domain is opt-in.
      if params[:skip_step].present? || domain_params[:hostname].blank?
        mark_current_step_as_completed
        wizard.reload
        determine_wizard_outcome
        return
      end

      @platform_domain = @platform.platform_domains.build(domain_params)

      if @platform_domain.save
        mark_current_step_as_completed
        wizard.reload
        determine_wizard_outcome
      else
        @host_apex = host_apex_hostname
        flash.now[:alert] = t('.flash.please_address_errors')
        render wizard_step_definition.template, status: :unprocessable_entity
      end
    end

    # --- Step 4: steward_account -------------------------------------------

    def steward_account
      find_or_create_wizard_step
      @user = ::BetterTogether::User.new
      @user.build_person
      @form = ::BetterTogether::NewPlatformStewardForm.new(@user)
      render wizard_step_definition.template
    end

    # rubocop:todo Metrics/MethodLength
    def create_steward_account # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @form = ::BetterTogether::NewPlatformStewardForm.new(::BetterTogether::User.new)

      if @form.validate(steward_params)
        ActiveRecord::Base.transaction do
          user = ::BetterTogether::User.new(steward_params)

          if user.save!
            target_platform.person_platform_memberships.create!(
              member: user.person,
              role: ::BetterTogether::Role.find_by(identifier: 'platform_steward') ||
                    ::BetterTogether::Role.find_by(identifier: 'platform_manager')
            )

            primary_community = target_platform.primary_community
            primary_community.person_community_memberships.create!(
              member: user.person,
              role: ::BetterTogether::Role.find_by(identifier: 'community_governance_council')
            )
            primary_community.creator = user.person
            primary_community.save!

            mark_current_step_as_completed
            wizard.reload
            determine_wizard_outcome
            return
          end
        end
      end

      @user = ::BetterTogether::User.new(steward_params)
      @user.build_person unless @user.person
      flash.now[:alert] = t('.flash.please_address_errors')
      render wizard_step_definition.template, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      @user = e.record
      @user.build_person unless @user.person
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render wizard_step_definition.template, status: :unprocessable_entity
    end
    # rubocop:enable Metrics/MethodLength

    # --- Step 5: invite_members (optional — reuses PlatformInvitation) ----

    def invite_members
      find_or_create_wizard_step
      @platform = target_platform
      @invitation = @platform.invitations.new
      @sent_invitations = @platform.invitations.order(:created_at)
      render wizard_step_definition.template
    end

    # Authorization note: PlatformInvitationPolicy#can_manage_platform_members?
    # gates on a manage_platform_members/manage_platform_roles
    # RoleResourcePermission grant reachable through a PersonPlatformMembership
    # (see PlatformInvitationPolicy#can_manage_platform_members?). For a
    # brand-new draft platform's just-created steward (the person created a
    # step ago, in create_steward_account above), that grant is not guaranteed
    # to exist yet — unlike PlatformPolicy#update?'s can_manage_platform_settings?,
    # which has a global manage_platform fallback. This mirrors create_domain's
    # exact reasoning above: reuse authorize_target_platform (already run as a
    # before_action for every action in this controller, PlatformPolicy#update?)
    # instead of a second Pundit check tied to a different policy class, and
    # build/save PlatformInvitation records directly.
    def create_invite_members # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @platform = target_platform

      # An explicit "Skip"/"Continue" click, or a blank invitee_email, both
      # mean the steward is done inviting members for now — mirrors
      # create_domain's identical skip_step/blank-field pattern.
      if params[:skip_step].present? || invite_member_params[:invitee_email].blank?
        mark_current_step_as_completed
        wizard.reload
        determine_wizard_outcome
        return
      end

      @invitation = @platform.invitations.new(invite_member_params) do |invitation|
        invitation.invitable = @platform
        invitation.inviter = invitation_inviter
        invitation.status = 'pending'
        invitation.valid_from = Time.zone.now
        invitation.locale = I18n.locale
        invitation.community_role_id ||= default_community_role&.id
      end

      if @invitation.save
        # Redisplay the same step (rather than advancing) so the steward can
        # send additional invitations, or click "Continue" (skip_step) once done.
        redirect_to new_platform_setup_step_invite_members_path(platform_id: @platform.to_param),
                    notice: t('.flash.invitation_sent', email: @invitation.invitee_email)
      else
        @sent_invitations = @platform.invitations.order(:created_at)
        flash.now[:alert] = t('.flash.please_address_errors')
        render wizard_step_definition.template, status: :unprocessable_entity
      end
    end

    # --- Step 6: review_and_launch (read-only recap + final confirmation) -

    # A genuinely new pattern (no prior "review and confirm" step exists
    # elsewhere) — read-only recap of everything collected so far, built by
    # querying the already-persisted draft target_platform directly rather
    # than any in-memory hand-off between steps.
    def review_and_launch
      find_or_create_wizard_step
      @platform = target_platform
      @additional_platform_domains = @platform.platform_domains.where(primary_flag: false)
      @steward = @platform.primary_community&.creator
      @invitations = @platform.invitations
      render wizard_step_definition.template
    end

    # The final action of the wizard. No fields are collected here — it's a
    # confirmation, not data entry — so this simply completes the step and
    # lets the inherited determine_wizard_outcome (called manually, same as
    # every other step's POST action) discover that all step definitions are
    # now complete and redirect to wizard.success_path with wizard.success_message,
    # exactly as Wizard#completed?/WizardMethods#determine_wizard_outcome
    # already implement generically — nothing about that shared path needed
    # to change for this step to be "the last one."
    def launch_platform
      mark_current_step_as_completed
      wizard.reload
      determine_wizard_outcome
    end

    private

    def target_platform
      @target_platform ||= ::BetterTogether::Platform.friendly.find(params[:platform_id])
    end

    def wizard
      @wizard ||= ::BetterTogether::Wizard.for_platform(target_platform)
                                          .find_by(identifier: ::BetterTogether::NewPlatformSetupWizardBuilder::IDENTIFIER)
    end

    def wizard_step_path(step_definition, _wizard = nil)
      public_send("new_platform_setup_step_#{step_definition.identifier}_path", platform_id: target_platform.to_param)
    end

    def platform_identity_params
      params.require(:platform).permit(:name, :description, :host_url, :time_zone, :privacy)
    end

    # primary_flag is deliberately not permitted here — the platform's primary
    # domain is already synced from host_url (Platform#sync_primary_platform_domain!);
    # this step only ever adds a non-primary alias. active isn't exposed either —
    # it defaults true at the DB level, which is correct for a newly-added alias.
    def domain_params
      params.fetch(:platform_domain, {}).permit(:hostname, :share_domain)
    end

    def host_apex_hostname
      ::BetterTogether::Platform.find_by(host: true)&.primary_platform_domain&.hostname
    end

    def steward_params
      params.require(:user).permit(
        :email, :password, :password_confirmation,
        person_attributes: %i[identifier name description]
      )
    end

    def invite_member_params
      params.fetch(:platform_invitation, {}).permit(:invitee_email)
    end

    # Prefer the steward's Person created a step ago in create_steward_account
    # (Platform#primary_community's creator is set there) so invitations sent
    # from this step are attributed to whoever will actually manage this new
    # platform day-to-day. Falls back to the acting host-platform manager
    # driving this wizard run (current_person) in case steward_account was
    # ever reachable without a completed creator assignment.
    def invitation_inviter
      target_platform.primary_community.creator || helpers.current_person
    end

    def default_community_role
      ::BetterTogether::Role.find_by(identifier: 'community_member')
    end

    # Same authorization as the platform's own manage_platform_settings/
    # manage_platform check (PlatformPolicy) — provisioning must be
    # continuable only by the same class of person who could have kicked it
    # off via NewPlatformSetupController#start.
    def authorize_target_platform
      authorize target_platform, :update?, policy_class: ::BetterTogether::PlatformPolicy
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    # A completed new_platform_setup run cannot be re-entered or re-submitted
    # for the same platform — mirrors SetupWizardStepsController's
    # ensure_setup_wizard_incomplete guard, scoped per-platform instead of
    # globally, since each platform has its own Wizard row.
    def ensure_wizard_incomplete
      return unless wizard&.completed?

      redirect_to platform_path(target_platform, locale: I18n.locale),
                  alert: t('better_together.new_platform_setup_steps.already_completed')
    end
  end
end
