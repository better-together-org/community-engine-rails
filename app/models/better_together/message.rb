# frozen_string_literal: true

module BetterTogether
  # allows for communication between people
  class Message < PlatformRecord
    include Reportable
    include Broadcastable

    belongs_to :conversation, touch: true
    belongs_to :sender, class_name: 'BetterTogether::Person', inverse_of: :sent_messages

    has_rich_text :content, encrypted: true

    validates :content, presence: true

    before_validation :normalize_e2e_encryption_flags

    broadcasts_async_to :conversation, target: 'conversation_messages'

    # Attributes permitted for strong parameters
    def self.permitted_attributes
      # include id and _destroy for nested attributes handling
      %i[id content e2e_encrypted e2e_version e2e_protocol _destroy]
    end

    # True when this message was encrypted client-side with Signal Protocol.
    # The server stores the ciphertext but cannot decrypt it.
    def e2e?
      e2e_encrypted?
    end

    private

    # Server-side trust boundary for E2EE: the UI hides its "encrypted" affordances behind
    # e2ee_messaging_enabled?, but a direct API/param write could otherwise set e2e_encrypted
    # regardless of that gate. Force these flags off unless the feature is actually enabled
    # for the current sender/platform context.
    def normalize_e2e_encryption_flags
      return if e2e_encrypted_flags_blank? || e2e_messaging_available?

      self.e2e_encrypted = false
      self.e2e_version = nil
      self.e2e_protocol = nil
    end

    def e2e_encrypted_flags_blank?
      !e2e_encrypted && e2e_version.nil? && e2e_protocol.nil?
    end

    def e2e_messaging_available?
      BetterTogether.e2ee_messaging_enabled? ||
        BetterTogether::FeatureGate.enabled?('e2ee_messaging', actor: Current.person, platform: Current.platform)
    end
  end
end
