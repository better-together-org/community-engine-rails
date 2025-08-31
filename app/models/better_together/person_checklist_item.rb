# frozen_string_literal: true

module BetterTogether
  class PersonChecklistItem < ApplicationRecord # rubocop:todo Style/Documentation
    include Creatable
    include Protected

    belongs_to :person, class_name: 'BetterTogether::Person'
    belongs_to :checklist, class_name: 'BetterTogether::Checklist'
    belongs_to :checklist_item, class_name: 'BetterTogether::ChecklistItem'

    validates :person, :checklist, :checklist_item, presence: true

    before_save :enforce_directional_progression, if: :setting_completed_at?

    def mark_done!(completed_at: Time.zone.now)
      update!(completed_at: completed_at)
    end

    def mark_undone!
      update!(completed_at: nil)
    end

    def done?
      completed_at.present?
    end

    scope :completed, -> { where.not(completed_at: nil) }
    scope :pending, -> { where(completed_at: nil) }

    private

    def setting_completed_at?
      completed_at_changed? && completed_at.present?
    end

    def enforce_directional_progression # rubocop:todo Metrics/AbcSize
      return unless checklist&.directional

      # Find any items with position less than this item that are not completed for this person
      earlier_items = checklist.checklist_items.where('position < ?', checklist_item.position)

      return if earlier_items.none?

      incomplete = earlier_items.any? do |item|
        !BetterTogether::PersonChecklistItem.where.not(completed_at: nil).exists?(person:, checklist:,
                                                                                  checklist_item: item)
      end

      return unless incomplete

      errors.add(:completed_at, I18n.t('errors.models.person_checklist_item.directional_incomplete'))
      throw(:abort)
    end
  end
end
