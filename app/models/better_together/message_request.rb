# frozen_string_literal: true

module BetterTogether
  # Allows a person to ask another person for permission to message them, with an
  # explanatory note. When accepted, creates a PersonMessagingGrant and an opening
  # Conversation containing the note as the first message.
  class MessageRequest < PlatformRecord
    STATUS_VALUES = {
      pending: 'pending',
      accepted: 'accepted',
      declined: 'declined'
    }.freeze

    enum :status, STATUS_VALUES, default: 'pending'

    belongs_to :sender,    class_name: 'BetterTogether::Person', inverse_of: :sent_message_requests
    belongs_to :recipient, class_name: 'BetterTogether::Person', inverse_of: :received_message_requests
    belongs_to :platform,  class_name: 'BetterTogether::Platform'

    validates :note, presence: true, length: { maximum: 1000 }
    validates :sender_id,
              uniqueness: {
                scope: %i[recipient_id platform_id status],
                conditions: -> { pending },
                message: :already_pending
              }
    validate :sender_and_recipient_differ

    scope :pending,  -> { where(status: 'pending') }
    scope :accepted, -> { where(status: 'accepted') }
    scope :declined, -> { where(status: 'declined') }

    def accept!
      transaction do
        update!(status: 'accepted', responded_at: Time.current)
        PersonMessagingGrant.find_or_create_by!(grantor: recipient, grantee: sender, platform: platform)
        create_opening_conversation
      end
    end

    def decline!
      update!(status: 'declined', responded_at: Time.current)
    end

    private

    def create_opening_conversation
      conversation = Conversation.new(
        creator: sender,
        platform: platform,
        participant_ids: [sender.id, recipient.id],
        title: ''
      )
      conversation.messages.build(sender: sender, content: note)
      conversation.save!
      conversation
    end

    def sender_and_recipient_differ
      return unless sender_id.present? && sender_id == recipient_id

      errors.add(:recipient_id, :cannot_request_self)
    end
  end
end
