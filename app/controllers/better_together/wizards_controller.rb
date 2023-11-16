# app/controllers/better_together/wizards_controller.rb
module BetterTogether
  class WizardsController < ApplicationController
    def show
      @wizard = BetterTogether::Wizard.friendly.find(params[:id])
      determine_wizard_outcome(@wizard)
    end

    private

    def determine_wizard_outcome(wizard)
      if wizard_completed?(wizard)
        flash[:notice] = wizard.success_message
        redirect_to wizard.success_path
      else
        path, flash_key, message = wizard_next_step_info(wizard)
        flash[flash_key] = message if message
        redirect_to path
      end
    end

    def wizard_completed?(wizard)
      wizard.completed?
    end

    def wizard_next_step_info(wizard)
      step = wizard.wizard_steps.ordered.detect { |s| !s.completed }

      if step.nil?
        first_step_definition = wizard.wizard_step_definitions.ordered.first
        return [wizard_step_path(wizard, first_step_definition), :alert, "Please start the wizard."] if first_step_definition
        [root_path, :error, "Wizard steps are not defined."]
      else
        step_definition = step.wizard_step_definition
        [wizard_step_path(wizard, step_definition), nil, nil]
      end
    end
  end
end
