# app/controllers/better_together/wizard_steps_controller.rb
module BetterTogether
  class WizardStepsController < ApplicationController
    before_action :form
    before_action :wizard
    before_action :wizard_step_definition

    def show
      # Logic to display the step using the template path
      render @wizard_step_definition.template
    end

    def update
      # Logic to mark the step as complete and redirect to the next step
      # ...
    end

    private

    def form
      return @form if @form.present?
      
      form_class = wizard_step_definition.form_class.constantize if wizard_step_definition.form_class.present?
      # byebug
      @form = form_class.new(form_class::MODEL_CLASS.new)
    end

    def wizard
      @wizard ||= BetterTogether::Wizard.friendly.find(params[:wizard_id])
    end

    def wizard_step_definition
      @wizard_step_definition ||= wizard.wizard_step_definitions.friendly.find(params[:wizard_step_definition_id])
    end
  end
end
