# frozen_string_literal: true

module BetterTogether
  # groups messages for participants
  class Conversation < ApplicationRecord
    include Creatable

    encrypts :title, deterministic: true
    has_many :messages, dependent: :destroy
    accepts_nested_attributes_for :messages, allow_destroy: false
    has_many :conversation_participants, dependent: :destroy
    has_many :participants, through: :conversation_participants, source: :person
    validate :at_least_one_participant

    # Define permitted attributes for controller strong parameters
    def self.permitted_attributes
      [
        :title,
        { participant_ids: [] },
        { messages_attributes: BetterTogether::Message.permitted_attributes }
      ]
    end

    # Require participants on creation so the form helper `required_label`
    # can detect required fields and the form-validation Stimulus controller
    # will flag them client-side. Do NOT require a nested message on every
    # conversation create: nested messages are optional unless a nested
    # message was provided by the form. If a nested message is present, we
    # validate its content below.
    validates :participant_ids, presence: true, on: :create

    # Provide a helper for the first message content so views/tests can
    # access it easily and a custom validator can assert its presence
    # (useful for nested attributes where Message validations may not yet
    # surface on the parent object in some flows).
    def first_message_content
      first_msg = messages.first
      return nil unless first_msg

      if first_msg.respond_to?(:content) && first_msg.content.respond_to?(:to_plain_text)
        first_msg.content.to_plain_text
      else
        first_msg.content
      end
    end

    # Only validate the first nested message's content when a nested
    # message actually exists (i.e., was provided via nested attributes or
    # built in the controller). This avoids blocking conversation creation
    # when no message is intended.
    validate :first_message_content_present, on: :create

    def first_message_content_present
      return if messages.blank?

      content = first_message_content
      return unless content.nil? || content.to_s.strip.empty?

      errors.add(:messages, :blank)
    end

    def to_s
      title
    end

    # Safely add a person as a participant, retrying once if the person record
    # raises an ActiveRecord::StaleObjectError due to an outdated lock_version.
    # This centralizes optimistic-lock retry logic for participant additions.
    def add_participant_safe(person)
      return if person.nil?

      attempts = 0
      begin
        participants << person unless participants.exists?(person.id)
      rescue ActiveRecord::StaleObjectError
        attempts += 1
        raise unless attempts <= 1

        person.reload
        retry
      end
    end

    private

    def at_least_one_participant
      return unless participants.empty?

      errors.add(:conversation_participants, I18n.t('pundit.errors.leave_conversation'))
    end
  end
end
