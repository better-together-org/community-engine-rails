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

    def wizard_step_path(_wizard = nil, step_definition)
      "/bt/setup_wizard/#{step_definition.identifier}"
    end
  end
end
