# frozen_string_literal: true

# app/models/better_together/wizard.rb
module BetterTogether
  # Ordered step defintions that the user must complete
  class Wizard < ApplicationRecord
    include Identifier
    include Protected

    has_many :wizard_step_definitions, -> { ordered }, dependent: :destroy
    has_many :wizard_steps, dependent: :destroy

    slugged :identifier, dependent: :delete_all

    translates :name
    translates :description, type: :text

    validates :name, presence: true
    validates :max_completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :current_completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # Additional logic and methods as needed

    def limited_completions?
      max_completions.positive?
    end

    def mark_completed
      return if current_completions == max_completions

      self.current_completions += 1
      self.last_completed_at = DateTime.now
      self.first_completed_at = DateTime.now if first_completed_at.nil?

      save
    end

    def completed?
      # TODO: Adjust for wizards with multiple possible completions
      completed = wizard_steps.size == wizard_step_definitions.size &&
                  wizard_steps.ordered.all?(&:completed)

      mark_completed
      completed
    end
  end
end
