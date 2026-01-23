# frozen_string_literal: true

# app/models/better_together/wizard.rb
module BetterTogether
  # Ordered step definitions that the user must complete
  class Wizard < ApplicationRecord
    include Identifier
    include Protected

    has_many :wizard_step_definitions, -> { ordered }, dependent: :destroy
    has_many :wizard_steps, dependent: :destroy

    slugged :identifier, dependent: :delete_all

    translates :name, type: :string
    translates :description, type: :text

    validates :name, presence: true
    validates :max_completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :current_completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    def completed?
      completed = wizard_steps.size == wizard_step_definitions.size &&
                  wizard_steps.ordered.all?(&:completed)
      mark_completed if completed
      current_completions.positive?
    end

    def limited_completions?
      max_completions.positive?
    end

    def mark_completed
      return if current_completions == max_completions

      self.current_completions += 1
      self.last_completed_at = DateTime.now
      self.first_completed_at ||= DateTime.now
      save
    end

    # -------------------------------------
    # Overriding #plant for the Seedable concern
    # -------------------------------------
    def plant
      # Pull in the default fields from the base Seedable (model_class, record_id, etc.)
      super.merge(
        name: name,
        identifier: identifier,
        description: description,
        max_completions: max_completions,
        current_completions: current_completions,
        last_completed_at: last_completed_at,
        first_completed_at: first_completed_at,
        # Optionally embed your wizard_step_definitions so they're all in one seed
        step_definitions: wizard_step_definitions.map(&:plant)
      )
    end
  end
end
