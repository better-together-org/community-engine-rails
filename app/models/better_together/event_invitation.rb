# frozen_string_literal: true

module BetterTogether
  # Invitation for Events using the polymorphic invitations table
  class EventInvitation < Invitation
    STATUS_VALUES = {
      pending: 'pending',
      accepted: 'accepted',
      declined: 'declined'
    }.freeze

    enum status: STATUS_VALUES, _prefix: :status

    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    validate :invitee_presence

    # Ensure token is generated before validation
    before_validation :ensure_token_present

    # Convenience helpers (invitable is the event)
    def event
      invitable
    end

    def after_accept!(invitee_person: nil)
      person = invitee_person || resolve_invitee_person
      return unless person && event

      attendance = BetterTogether::EventAttendance.find_or_initialize_by(event:, person:)
      attendance.status = 'going'
      attendance.save!
    end

    def accept!(invitee_person: nil)
      self.status = STATUS_VALUES[:accepted]
      save!
      after_accept!(invitee_person:)
    end

    def decline!
      self.status = STATUS_VALUES[:declined]
      save!
    end

    def url_for_review
      BetterTogether::Engine.routes.url_helpers.invitation_url(token, locale: I18n.locale)
    end

    private

    def ensure_token_present
      return if token.present?

      self.token = self.class.generate_unique_secure_token
    end

    def resolve_invitee_person
      return invitee if invitee.is_a?(BetterTogether::Person)

      nil
    end

    def invitee_presence
      return unless invitee.blank? && self[:invitee_email].to_s.strip.blank?

      errors.add(:invitee_email, :blank)
    end
  end
end
