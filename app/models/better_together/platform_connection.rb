# frozen_string_literal: true

module BetterTogether
  # Durable directed edge between two platforms in the federated registry.
  class PlatformConnection < ApplicationRecord
    STATUS_VALUES = {
      pending: 'pending',
      active: 'active',
      suspended: 'suspended',
      blocked: 'blocked'
    }.freeze

    CONNECTION_KINDS = {
      peer: 'peer',
      member: 'member'
    }.freeze

    belongs_to :source_platform, class_name: '::BetterTogether::Platform'
    belongs_to :target_platform, class_name: '::BetterTogether::Platform'

    enum :status, STATUS_VALUES, default: :pending, validate: true
    enum :connection_kind, CONNECTION_KINDS, default: :peer, validate: true

    validates :source_platform_id, uniqueness: { scope: :target_platform_id }
    validates :content_sharing_enabled, :federation_auth_enabled, inclusion: { in: [true, false] }
    validate :source_and_target_must_differ

    scope :active, -> { where(status: STATUS_VALUES[:active]) }
    scope :for_platform, lambda { |platform|
      where(source_platform: platform).or(where(target_platform: platform))
    }

    def involves?(platform)
      source_platform_id == platform.id || target_platform_id == platform.id
    end

    def peer_for(platform)
      return target_platform if source_platform_id == platform.id
      return source_platform if target_platform_id == platform.id

      nil
    end

    private

    def source_and_target_must_differ
      return if source_platform_id.blank? || target_platform_id.blank?
      return unless source_platform_id == target_platform_id

      errors.add(:target_platform_id, 'must differ from source platform')
    end
  end
end
