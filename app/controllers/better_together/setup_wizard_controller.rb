# frozen_string_literal: true

# app/controllers/better_together/setup_wizard_controller.rb
module BetterTogether
  # Handles the setup wizard process
  class SetupWizardController < WizardsController
    def show; end

    private

    def wizard
      helpers.host_setup_wizard
    end

    def wizard_step_path(step_definition, _wizard = nil)
      "/bt/setup_wizard/#{step_definition.identifier}"
    end
  end
end
