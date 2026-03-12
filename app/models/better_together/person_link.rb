# frozen_string_literal: true

module BetterTogether
  # Durable cross-platform person-to-person linkage created through accepted Joatu flows.
  class PersonLink < ApplicationRecord
    require 'storext'

    include ::Storext.model

    STATUS_VALUES = {
      pending: 'pending',
      active: 'active',
      revoked: 'revoked'
    }.freeze

    belongs_to :platform_connection, class_name: '::BetterTogether::PlatformConnection'
    belongs_to :source_person, class_name: '::BetterTogether::Person'
    belongs_to :target_person, class_name: '::BetterTogether::Person', optional: true

    has_many :person_access_grants, class_name: '::BetterTogether::PersonAccessGrant', dependent: :destroy

    store_attributes :settings do
      reciprocal Boolean, default: false
      link_origin String, default: 'joatu'
    end

    enum :status, STATUS_VALUES, default: :pending, validate: true

    validates :source_person_id, uniqueness: {
      scope: %i[platform_connection_id target_person_id],
      message: 'already has a link for this platform connection and target'
    }
    validate :target_or_remote_identifier_present
    validate :source_person_must_belong_to_source_platform
    validate :target_person_must_belong_to_target_platform, if: :target_person_id?

    scope :active, -> { where(status: STATUS_VALUES[:active]) }

    def activate!(verified_at: Time.current)
      update!(status: :active, verified_at:, revoked_at: nil)
    end

    def revoke!(revoked_at: Time.current)
      transaction do
        update!(status: :revoked, revoked_at:)
        person_access_grants.find_each do |grant|
          next if grant.revoked?

          grant.revoke!(revoked_at:)
        end
      end
    end

    def local_target?
      target_person_id.present?
    end

    def remote_target?
      !local_target?
    end

    private

    def target_or_remote_identifier_present
      return if target_person_id.present? || remote_target_identifier.present?

      errors.add(:base, 'requires either a local target person or a remote target identifier')
    end

    def source_person_must_belong_to_source_platform
      return if member_of_platform?(source_person, platform_connection&.source_platform)

      errors.add(:source_person, 'must belong to the source platform')
    end

    def target_person_must_belong_to_target_platform
      return if member_of_platform?(target_person, platform_connection&.target_platform)

      errors.add(:target_person, 'must belong to the target platform')
    end

    def member_of_platform?(person, platform)
      return false unless person && platform

      person.person_platform_memberships.active.exists?(joinable: platform)
    end
  end
end
