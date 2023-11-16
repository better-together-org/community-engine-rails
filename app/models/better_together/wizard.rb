# app/models/better_together/wizard.rb
module BetterTogether
  class Wizard < ApplicationRecord
    include FriendlySlug

    slugged :identifier

    has_many :wizard_step_definitions, -> { ordered }, dependent: :destroy
    has_many :wizard_steps, dependent: :destroy

    validates :name, presence: true
    validates :identifier, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
    validates :max_completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :current_completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :host, inclusion: { in: [true, false] }

    # Additional logic and methods as needed

    def limited_completions?
      max_completions.positive?
    end

    def completed?
      # TODO: Adjust for wizards with multiple possible completions
      wizard_steps.size == wizard_step_definitions.size &&
        wizard_steps.ordered.all?(&:completed)
    end
  end
end
