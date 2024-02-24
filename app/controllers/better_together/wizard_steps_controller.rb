# app/controllers/better_together/wizard_steps_controller.rb
module BetterTogether
  class WizardStepsController < ApplicationController
    include BetterTogether::WizardMethods

    def show
      # Logic to display the step using the template path
      render wizard_step_definition.template
    end

    def update
      # Logic to mark the step as complete and redirect to the next step
      # ...
    end

    private

    def form(model: nil, model_class: nil, form_class: nil)
      return @form if @form.present?

      form_class = wizard_step_definition.form_class.constantize if wizard_step_definition.form_class.present?
      model_class ||= form_class::MODEL_CLASS

      model = model ||= model_class.new
      @form = form_class.new(model)
    end
  end
end
