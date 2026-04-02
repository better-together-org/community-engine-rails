# frozen_string_literal: true

module BetterTogether
  module InvitationParticipant
    extend ActiveSupport::Concern

    included do
      has_many :sent_platform_invitations,
               foreign_key: :inviter_id,
               class_name: 'BetterTogether::PlatformInvitation',
               inverse_of: :inviter
      has_many :received_platform_invitations,
               foreign_key: :invitee_id,
               class_name: 'BetterTogether::PlatformInvitation',
               inverse_of: :invitee
      has_many :sent_guest_accesses,
               foreign_key: :inviter_id,
               class_name: 'BetterTogether::GuestAccess',
               inverse_of: :inviter
      has_many :received_guest_accesses,
               foreign_key: :invitee_id,
               class_name: 'BetterTogether::GuestAccess',
               inverse_of: :invitee
    end
  end
end
