# frozen_string_literal: true

module BetterTogether
  class Checklist < ApplicationRecord # rubocop:todo Style/Documentation
    include Identifier
    include Creatable
    include FriendlySlug
    include Protected
    include Privacy

    has_many :checklist_items, class_name: '::BetterTogether::ChecklistItem', dependent: :destroy
    has_many :person_checklist_items, class_name: '::BetterTogether::PersonChecklistItem', dependent: :destroy

    translates :title, type: :string

    slugged :title

    validates :title, presence: true

    # Returns checklist items along with per-person completions for a given person
    def items_with_progress_for(person)
      checklist_items.includes(:translations).map do |item|
        {
          item: item,
          done: item.done_for?(person),
          completion_record: BetterTogether::PersonChecklistItem.find_by(person:, checklist: self,
                                                                         checklist_item: item)
        }
      end
    end

    # Percentage of items completed for a given person (0..100)
    def completion_percentage_for(person)
      total = checklist_items.count
      return 0 if total.zero?

      completed = person_checklist_items.where(person:, done: true).count
      ((completed.to_f / total) * 100).round
    end

    def to_param
      slug
    end
  end
end
