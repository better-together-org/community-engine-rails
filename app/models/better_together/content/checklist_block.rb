# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a single BetterTogether::Checklist and its items
    class ChecklistBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      store_attributes :content_data do
        checklist_id String, default: ''
      end

      validates :checklist_id, presence: true

      def self.content_addable?
        false
      end

      def self.extra_permitted_attributes
        super + %i[checklist_id]
      end

      def checklist
        return nil if checklist_id.blank?

        BetterTogether::Checklist.find_by(id: checklist_id)
      end
    end
  end
end
