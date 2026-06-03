# frozen_string_literal: true

# app/controllers/better_together/setup_wizard_controller.rb
module BetterTogether
  # Handles the setup wizard process
  class SetupWizardController < WizardsController
    before_action :ensure_setup_wizard_incomplete

    def show
      # Always land on the first step of the host setup wizard
      redirect_to setup_wizard_step_platform_details_path
    end

    private

    def wizard
      helpers.host_setup_wizard
    end

    def wizard_step_path(step_definition, _wizard = nil)
      setup_wizard_step_path(step_definition.identifier)
    end

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
