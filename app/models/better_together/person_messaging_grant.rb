# frozen_string_literal: true

module BetterTogether
  # Records that Person B (grantor) has explicitly allowed Person A (grantee) to initiate
  # conversations with them. Created automatically when an invitation is accepted, or
  # when a MessageRequest is accepted by the recipient.
  class PersonMessagingGrant < PlatformRecord
    belongs_to :grantor, class_name: 'BetterTogether::Person', inverse_of: :messaging_grants_given
    belongs_to :grantee, class_name: 'BetterTogether::Person', inverse_of: :messaging_grants_received

    validates :grantor_id, uniqueness: { scope: %i[grantee_id platform_id], message: :taken }
    validates :grantee_id, presence: true
    validate :grantor_and_grantee_differ

    private

    def grantor_and_grantee_differ
      return unless grantor_id.present? && grantor_id == grantee_id

      errors.add(:grantee_id, :cannot_grant_self)
    end
  end
end
