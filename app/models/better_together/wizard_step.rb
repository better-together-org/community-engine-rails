# app/models/better_together/wizard_step.rb
module BetterTogether
  class WizardStep < ApplicationRecord
    belongs_to :wizard
    belongs_to :wizard_step_definition, foreign_key: 'identifier', primary_key: 'identifier'

    scope :ordered, -> { order(:step_number) }

    validates :completed, inclusion: { in: [true, false] }
    validate :validate_step_completions, if: :completed?

    # Additional logic and methods as needed

    private

    def validate_step_completions
      return unless wizard.limited_completions?

      completed_steps_count = WizardStep.where(wizard_id: wizard_id, identifier: identifier, completed: true).size

      if completed_steps_count >= wizard.max_completions
        errors.add(:base, "Number of completions for this step has reached the wizard's max completions limit.")
      end
    end
  end
end
