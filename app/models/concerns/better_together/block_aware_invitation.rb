# frozen_string_literal: true

module BetterTogether
  # Refuses to create invitations between people who have blocked each other,
  # whether the invitee is a person record or only an email address.
  module BlockAwareInvitation
    extend ActiveSupport::Concern

    included do
      validate :no_block_between_inviter_and_invitee, on: :create
    end

    private

    def no_block_between_inviter_and_invitee
      return unless inviter.respond_to?(:block_between?)

      invitee_person = invitee_person_for_block_check
      errors.add(:base, I18n.t('better_together.invitations.invitee_unavailable')) if invitee_person && inviter.block_between?(invitee_person)
    end

    def invitee_person_for_block_check
      return invitee if invitee.is_a?(BetterTogether::Person)
      return if self[:invitee_email].blank?

      BetterTogether::User.find_by(email: self[:invitee_email].to_s.strip.downcase)&.person
    end
  end
end
