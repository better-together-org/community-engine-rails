# frozen_string_literal: true

module BetterTogether
  class PersonDeletionAnonymizer
    class << self
      def call(person:)
        new(person:).call
      end
    end

    attr_reader :person

    def initialize(person:)
      @person = person
    end

    def call
      purge_attachments!
      destroy_contact_detail!

      person.update!(
        name: deleted_name,
        description: nil,
        identifier: deleted_identifier,
        privacy: 'private',
        preferences: default_preferences,
        notification_preferences: default_notification_preferences,
        identity_key_public: nil,
        signed_prekey_id: nil,
        signed_prekey_public: nil,
        signed_prekey_sig: nil,
        registration_id: nil,
        key_backup_blob: nil,
        key_backup_salt: nil,
        key_backup_updated_at: nil,
        deleted_at: Time.current,
        anonymized_at: Time.current
      )
    end

    private

    def purge_attachments!
      person.profile_image.purge if person.profile_image.attached?
      person.cover_image.purge if person.cover_image.attached?
    end

    def destroy_contact_detail!
      BetterTogether::ContactDetail.find_by(contactable: person)&.destroy!
    end

    def deleted_name
      I18n.t('better_together.people.deleted_name', default: 'Deleted person')
    end

    def deleted_identifier
      "deleted-person-#{person.id.delete('-').first(12)}"
    end

    def default_preferences
      {
        'locale' => I18n.default_locale.to_s,
        'time_zone' => ENV.fetch('APP_TIME_ZONE', 'America/St_Johns'),
        'receive_messages_from_members' => false,
        'federate_content' => false
      }
    end

    def default_notification_preferences
      {
        'notify_by_email' => false,
        'show_conversation_details' => false
      }
    end
  end
end
