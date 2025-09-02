# frozen_string_literal: true

module BetterTogether
  # An item belonging to a Checklist. Translated label and description.
  class ChecklistItem < ApplicationRecord
    include Identifier
    include Creatable
    include FriendlySlug
    include Translatable
    include Positioned
    include Protected
    include Privacy

    belongs_to :checklist, class_name: '::BetterTogether::Checklist', inverse_of: :checklist_items
    belongs_to :parent, class_name: '::BetterTogether::ChecklistItem', optional: true, inverse_of: :children,
                        counter_cache: :children_count
    has_many :children, class_name: '::BetterTogether::ChecklistItem', foreign_key: :parent_id, dependent: :destroy,
                        inverse_of: :parent

    translates :label, type: :string
    translates :description, backend: :action_text

    slugged :label

    validates :label, presence: true

    # Per-person completion helpers
    def done_for?(person)
      return false unless person

      BetterTogether::PersonChecklistItem.completed.exists?(person:, checklist: checklist, checklist_item: self)
    end

    def completion_record_for(person)
      BetterTogether::PersonChecklistItem.find_by(person:, checklist: checklist, checklist_item: self)
    end

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[checklist_id parent_id]
    end

    # Scope positions per-parent so items are ordered among siblings
    def position_scope
      :parent_id
    end

    def to_s
      label
    end
  end
end
