# frozen_string_literal: true

# app/controllers/better_together/wizard_steps_controller.rb
module BetterTogether
  # Handles wizard step requests
  class WizardStepsController < ApplicationController
    include ::BetterTogether::WizardMethods

    # Explicit allow-list of form classes usable by the setup wizard
    WIZARD_FORM_CLASSES = %w[
      BetterTogether::HostPlatformDetailsForm
      BetterTogether::HostPlatformAdminForm
    ].freeze

    def show
      # Logic to display the step using the template path
      render wizard_step_definition.template
    end

    def update
      # Logic to mark the step as complete and redirect to the next step
      # ...
    end

    private

    def form(model: nil, model_class: nil, form_class: nil) # rubocop:todo Metrics/MethodLength
      return @form if @form.present?

      if wizard_step_definition.form_class.present?
        form_class = BetterTogether::SafeClassResolver.resolve!(
          wizard_step_definition.form_class,
          allowed: WIZARD_FORM_CLASSES,
          error_class: Pundit::NotAuthorizedError
        )
      end
      model_class ||= form_class::MODEL_CLASS

      model ||= model_class.new
      @form = form_class.new(model)
    end
  end
end
