# frozen_string_literal: true

module BetterTogether
  # Handles the setup wizard steps and tracking
  class SetupWizardStepsController < WizardStepsController # rubocop:todo Metrics/ClassLength
    skip_before_action :determine_wizard_outcome, only: %i[create_host_platform create_admin]

    # Guard all actions: once the host setup wizard is completed it cannot be
    # re-entered or re-submitted, regardless of authentication state.
    # This covers POST actions that skip :determine_wizard_outcome above.
    before_action :ensure_setup_wizard_incomplete

    def redirect
      public_send permitted_path(params[:path])
    end

    def platform_details
      # Find or create the wizard step
      find_or_create_wizard_step

      # Build platform instance for the form
      @platform = base_platform

      # Initialize the form object
      @form = ::BetterTogether::HostPlatformDetailsForm.new(@platform)

      # Render the template from the step definition
      render wizard_step_definition.template
    end

    # rubocop:todo Metrics/MethodLength
    def create_host_platform # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @form = ::BetterTogether::HostPlatformDetailsForm.new(base_platform)

      if @form.validate(platform_params)
        ActiveRecord::Base.transaction do
          platform = base_platform
          platform.assign_attributes(platform_params)
          platform.set_as_host

          if platform.save!
            mark_current_step_as_completed
            wizard.reload
            determine_wizard_outcome
            return
          end
        end
      end

      # If we get here, validation or save failed
      @platform = base_platform
      @platform.assign_attributes(platform_params) if platform_params.present?
      flash.now[:alert] = t('.flash.please_address_errors')
      render wizard_step_definition.template, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      @platform = e.record
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render wizard_step_definition.template, status: :unprocessable_entity
    end
    # rubocop:enable Metrics/MethodLength

    def admin_creation
      # Find or create the wizard step
      find_or_create_wizard_step

      # Build a new user instance for the form
      @user = ::BetterTogether::User.new
      @user.build_person

      # Initialize the form object with nested person attributes
      @form = ::BetterTogether::HostPlatformAdminForm.new(@user)

      # Render the template from the step definition
      render wizard_step_definition.template
    end

    # rubocop:todo Metrics/MethodLength
    def create_admin # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @form = ::BetterTogether::HostPlatformAdminForm.new(::BetterTogether::User.new)

      if @form.validate(user_params)
        ActiveRecord::Base.transaction do
          user = ::BetterTogether::User.new(user_params)

          if user.save!
            # Prefer the canonical stewardship role, but allow fallback while
            # transitional legacy seeds are still present.
            helpers.host_platform.person_platform_memberships.create!(
              member: user.person,
              role: ::BetterTogether::Role.find_by(identifier: 'platform_steward') ||
                    ::BetterTogether::Role.find_by(identifier: 'platform_manager')
            )

            # TODO: This should be moved into a separate method somewhere
            helpers.host_community.person_community_memberships.create!(
              member: user.person,
              role: ::BetterTogether::Role.find_by(identifier: 'community_governance_council')
            )
            helpers.host_community.creator = user.person
            helpers.host_community.save!

            mark_current_step_as_completed
            wizard.reload
            determine_wizard_outcome
            return
          end
        end
      end

      # If we get here, validation or save failed
      @user = ::BetterTogether::User.new(user_params)
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

    # More steps can be added here...

    private

    def permitted_path(path)
      path if %w[platform_details create_host_platform admin_creation create_admin].include?(path)
    end

    def base_platform
      ::BetterTogether::Platform.find_or_initialize_by(host: true) do |platform|
        platform.url        = helpers.base_url
        platform.privacy    = 'private'
        platform.time_zone  = Time.zone.name
        platform.protected  = true
      end
    end

    def platform_params
      params.require(:platform).permit(:name, :description, :host_url, :time_zone, :privacy)
    end

    def user_params
      params.require(:user).permit(
        :email, :password, :password_confirmation,
        person_attributes: %i[identifier name description]
      )
    end

    def wizard_step_path(step_definition, _wizard = nil)
      # Possible helper names should include
      # setup_wizard_step_platform_details and setup_wizard_step_admin_creation
      setup_wizard_step_path(step_definition.identifier)
    end

    # Redirect away if the host setup wizard has already been completed.
    # Applied to every action — including the POST actions that skip
    # :determine_wizard_outcome — so the wizard cannot be re-submitted or
    # replayed once the first platform manager has finished onboarding.
    # Authenticated platform managers are sent to root; all others to the
    # sign-in page (the wizard is no longer a public surface once done).
    def ensure_setup_wizard_incomplete
      return unless helpers.host_setup_wizard&.completed?

      if user_signed_in?
        redirect_to root_path, alert: t('better_together.setup_wizard_steps.already_completed')
      else
        redirect_to new_user_session_path(locale: I18n.locale),
                    alert: t('better_together.setup_wizard_steps.already_completed')
      end
    end
  end
end
