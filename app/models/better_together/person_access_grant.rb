# frozen_string_literal: true

module BetterTogether
  # Recipient-scoped private access grant layered on top of a person link.
  class PersonAccessGrant < ApplicationRecord
    require 'storext'

    include ::Storext.model

    STATUS_VALUES = {
      pending: 'pending',
      active: 'active',
      revoked: 'revoked',
      expired: 'expired'
    }.freeze

    belongs_to :person_link, class_name: '::BetterTogether::PersonLink'
    belongs_to :grantor_person, class_name: '::BetterTogether::Person'
    belongs_to :grantee_person, class_name: '::BetterTogether::Person', optional: true

    # Encrypt PII fields that may contain email addresses or platform handles
    # belonging to people on remote federated platforms.
    encrypts :remote_grantee_identifier
    encrypts :remote_grantee_name

    store_attributes :settings do
      allow_profile_read Boolean, default: true
      allow_private_posts Boolean, default: false
      allow_private_pages Boolean, default: false
      allow_private_events Boolean, default: false
      allow_private_messages Boolean, default: false
      grant_origin String, default: 'joatu'
    end

    enum :status, STATUS_VALUES, default: :pending, validate: true

    validates :grantor_person_id, uniqueness: {
      scope: %i[person_link_id grantee_person_id],
      message: ->(_record, _data) { I18n.t('better_together.person_access_grants.errors.duplicate_grant') }
    }, if: :grantee_person_id?
    validates :remote_grantee_identifier, uniqueness: {
      scope: %i[person_link_id grantor_person_id],
      message: ->(_record, _data) { I18n.t('better_together.person_access_grants.errors.duplicate_grant') }
    }, if: -> { grantee_person_id.nil? && remote_grantee_identifier.present? }
    validate :grantor_must_match_person_link
    validate :grantee_must_match_person_link, if: :grantee_person_id?
    validate :grantee_or_remote_identifier_present

    scope :active, -> { where(status: STATUS_VALUES[:active]) }
    scope :current_active, lambda {
      active.where(revoked_at: nil)
            .where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }
    scope :for_connection, lambda { |connection|
      joins(:person_link).where(better_together_person_links: { platform_connection_id: connection.id })
    }
    scope :for_recipient, lambda { |person|
      where(grantee_person_id: person&.id)
    }

    def activate!(accepted_at: Time.current)
      update!(status: :active, accepted_at:, revoked_at: nil)
    end

    def revoke!(revoked_at: Time.current)
      update!(status: :revoked, revoked_at:)
    end

    def expire!(expired_at: Time.current)
      update!(status: :expired, revoked_at: expired_at)
    end

    def active_now?
      active? && revoked_at.blank? && !expired?
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def allows_scope?(scope)
      case scope.to_s
      when 'profile_read'
        allow_profile_read?
      when 'private_posts'
        allow_private_posts?
      when 'private_pages'
        allow_private_pages?
      when 'private_events'
        allow_private_events?
      when 'private_messages'
        allow_private_messages?
      else
        false
      end
    end

    def visible_to?(person)
      return false unless person

      active_now? && (grantor_person_id == person.id || grantee_person_id == person.id)
    end

    private

    def grantor_must_match_person_link
      return if person_link.blank? || grantor_person_id == person_link.source_person_id

      errors.add(:grantor_person, 'must match the person link source person')
    end

    def grantee_must_match_person_link
      return if person_link.blank? || grantee_person_id == person_link.target_person_id

      errors.add(:grantee_person, 'must match the person link target person')
    end

    def grantee_or_remote_identifier_present
      return if grantee_person_id.present? || remote_grantee_identifier.present?

      errors.add(:base, 'requires either a local grantee person or a remote grantee identifier')
    end
  end
end
