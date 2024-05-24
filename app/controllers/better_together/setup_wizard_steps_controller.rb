# frozen_string_literal: true

module BetterTogether
  # Handles the setup wizard steps and tracking
  class SetupWizardStepsController < WizardStepsController
    skip_before_action :determine_wizard_outcome, only: %i[create_host_platform create_admin]

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
      @form = ::BetterTogether::HostPlatformDetailsForm.new(::BetterTogether::Platform.new)

      if @form.validate(platform_params)
        ActiveRecord::Base.transaction do
          platform = base_platform
          platform.assign_attributes(platform_params)

          if platform.save!
            mark_current_step_as_completed
            wizard.reload
            determine_wizard_outcome
          else
            flash.now[:alert] = 'Please address the errors below.'
            render wizard_step_definition.template
          end
        end
      else
        flash.now[:alert] = 'Please address the errors below.'
        render wizard_step_definition.template
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render wizard_step_definition.template
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
          # byebug
          user = ::BetterTogether::User.new(user_params)
          user.build_person(person_params)

          if user.save!
            helpers.host_platform.person_platform_memberships.create!(
              member: user.person,
              role: ::BetterTogether::Role.find_by(identifier: 'platform_manager')
            )
            helpers.host_community.person_community_memberships.create!(
              member: user.person,
              role: ::BetterTogether::Role.find_by(identifier: 'community_governance_council')
            )
            # If Devise's :confirmable is enabled, this will send a confirmation email
            user.send_confirmation_instructions(confirmation_url: user_confirmation_path)
            mark_current_step_as_completed
            wizard.reload
            determine_wizard_outcome
          else
            # Handle the case where the user could not be saved
            flash.now[:alert] = user.errors.full_messages.to_sentence
            render wizard_step_definition.template
          end
        end
      else
        flash.now[:alert] = 'Please address the errors below.'
        render wizard_step_definition.template
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render wizard_step_definition.template
    end
    # rubocop:enable Metrics/MethodLength

    # More steps can be added here...

    private

    def base_platform
      ::BetterTogether::Platform.new(
        url: helpers.base_url,
        privacy: 'public',
        protected: false,
        time_zone: Time.zone.name,
        host: true
      )
    end

    def platform_params
      params.require(:platform).permit(:name, :description, :url, :time_zone, :privacy)
    end

    def person_params
      params.require(:user).permit(person_attributes: %i[identifier name description])[:person_attributes]
    end

    def user_params
      params.require(:user).permit(
        :email, :password, :password_confirmation
      )
    end

    def wizard_step_path(step_definition, _wizard = nil)
      "/bt/w/setup_wizard/#{step_definition.identifier}"
    end
  end
end
