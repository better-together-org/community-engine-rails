# app/models/better_together/wizard_step.rb
module BetterTogether
  class WizardStep < ApplicationRecord
    belongs_to :wizard
    belongs_to :wizard_step_definition, foreign_key: 'identifier', primary_key: 'identifier'
    belongs_to :creator, class_name: '::BetterTogether::Person', optional: true

    # Delegate success_message and success_path to the wizard_step_definition
    delegate :message, to: :wizard_step_definition

    scope :ordered, -> { order(:step_number) }

    validates :completed, inclusion: { in: [true, false] }
    validate :validate_step_completions, if: :completed?
    validate :unique_uncompleted_step_per_person

    # Additional logic and methods as needed

    # Method to mark the step as completed
    def mark_as_completed
      self.completed = true
      save
    end

    private

    def unique_uncompleted_step_per_person
      return if completed

      # Check if the wizard allows multiple completions
      if wizard.max_completions > 0
        completed_steps_count = WizardStep.where(
          wizard_id: wizard_id,
          identifier: identifier,
          creator_id: creator_id,
          completed: true
        ).size

        # If the number of completed steps is equal to or exceeds the max completions allowed, add an error
        if completed_steps_count >= wizard.max_completions
          errors.add(:base, "Maximum number of completions reached for this wizard and step definition.")
          return
        end
      end

      # Check for existing uncompleted step
      existing_step = WizardStep.where(
        wizard_id: wizard_id,
        identifier: identifier,
        creator_id: creator_id
      ).where.not(bt_id: bt_id).first

      if existing_step
        errors.add(:base, "Only one uncompleted step per person is allowed.")
      end
    end

    def validate_step_completions
      return unless wizard.limited_completions?

      completed_steps_count = WizardStep.where(wizard_id: wizard_id, identifier: identifier, completed: true).size

      if completed_steps_count >= wizard.max_completions
        errors.add(:base, "Number of completions for this step has reached the wizard's max completions limit.")
      end
    end
  end
end
