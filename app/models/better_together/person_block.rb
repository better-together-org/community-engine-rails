# frozen_string_literal: true

module BetterTogether
  # Join model tracking which people block other people.
  # Blocking is per-platform: person A can block person B on Platform 1
  # without affecting their relationship on Platform 2.
  class PersonBlock < ApplicationRecord
    include PlatformScoped

    belongs_to :blocker, class_name: 'BetterTogether::Person'
    belongs_to :blocked, class_name: 'BetterTogether::Person'

    validates :blocked_id, uniqueness: { scope: %i[blocker_id platform_id] }
    validate :not_self
    validate :blocked_not_platform_manager

    private

    def not_self
      errors.add(:blocked_id, I18n.t('errors.person_block.cannot_block_self')) if blocker_id == blocked_id
    end

    def blocked_not_platform_manager
      return unless blocked&.permitted_to?('manage_platform')

      errors.add(:blocked, I18n.t('errors.person_block.cannot_block_manager'))
    end
  end
end
