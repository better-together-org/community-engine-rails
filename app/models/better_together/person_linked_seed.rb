# frozen_string_literal: true

module BetterTogether
  # Recipient-scoped cached private seed content imported through a person access grant.
  class PersonLinkedSeed < ApplicationRecord
    belongs_to :person_access_grant, class_name: '::BetterTogether::PersonAccessGrant'
    belongs_to :recipient_person, class_name: '::BetterTogether::Person'
    belongs_to :source_platform, class_name: '::BetterTogether::Platform'

    encrypts :payload

    validates :identifier, :source_record_type, :source_record_id, :seed_type, :version, :payload, presence: true
    validate :recipient_must_match_access_grant

    scope :visible_to, lambda { |person|
      return none unless person

      joins(:person_access_grant)
        .where(recipient_person: person)
        .merge(::BetterTogether::PersonAccessGrant.current_active)
    }

    def self.global_searchable?
      false
    end

    def payload_data
      JSON.parse(payload)
    rescue JSON::ParserError
      {}
    end

    def viewable_by?(person)
      return false unless person
      return false unless person_access_grant.active_now?

      recipient_person_id == person.id
    end

    def soft_hidden?
      !person_access_grant.active_now?
    end

    private

    def recipient_must_match_access_grant
      return if person_access_grant.blank? || recipient_person_id == person_access_grant.grantee_person_id

      errors.add(:recipient_person, 'must match the access grant grantee person')
    end
  end
end
