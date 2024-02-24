# frozen_string_literal: true

# app/controllers/concerns/better_together/wizard_methods.rb
module BetterTogether
  module WizardMethods
    extend ActiveSupport::Concern

    included do
      skip_before_action :check_platform_setup
      before_action :determine_wizard_outcome
    end

    def determine_wizard_outcome
      raise StandardError, "Wizard #{wizard_identifier} was not found. Have you run the seeds?" unless wizard

      if wizard.completed?
        flash[:notice] = wizard.success_message
        redirect_to wizard.success_path
      else
        next_step_path, flash_key, message = wizard_next_step_info
        flash[flash_key] = message if message

        # Check if the next step path is different from the current request path
        redirect_to next_step_path unless request.path == next_step_path
      end
    end

    def find_or_create_wizard_step
      # Identify the next uncompleted step definition
      step_definition = wizard.wizard_step_definitions.ordered.detect do |sd|
        !wizard.wizard_steps.exists?(identifier: sd.identifier, completed: true)
      end

      # If no uncompleted step definition is found, use the first step definition
      step_definition ||= wizard.wizard_step_definitions.ordered.first
      return nil unless step_definition

      # Find or create a wizard step for the current person
      @wizard_step = wizard.wizard_steps.find_or_create_by(
        identifier: step_definition.identifier,
        step_number: step_definition.step_number
      ) do |wizard_step|
        wizard_step.creator = helpers.current_person
      end
    end

    def mark_current_step_as_completed
      wizard_step = find_or_create_wizard_step
      wizard_step.mark_as_completed if wizard_step.present?

      wizard_step
    end

    def wizard
      @wizard ||= BetterTogether::Wizard.find_by(identifier: wizard_identifier)
    end

    def wizard_identifier
      @wizard_identifier ||= params[:wizard_id]
    end

    def wizard_step_definition_identifier
      @wizard_step_definition_identifier ||= params[:wizard_step_definition_id]
    end

    def wizard_step_definition
      @wizard_step_definition ||= wizard.wizard_step_definitions.find_by(identifier: wizard_step_definition_identifier)
    end

    def wizard_next_step_info
      wizard_step = find_or_create_wizard_step
      # byebug

      if wizard_step.nil?
        [root_path, :error, 'Wizard steps are not defined.']
      else
        step_definition = wizard_step.wizard_step_definition
        [wizard_step_path(wizard, step_definition), :notice, step_definition.message]
      end
    end
  end
end
