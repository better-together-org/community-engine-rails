# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_person, class: Person, aliases: %i[person inviter invitee creator author] do
      id { Faker::Internet.uuid }
      name { Faker::Name.name }
      description { Faker::Lorem.paragraph(sentence_count: 3) }
      identifier { Faker::Internet.unique.username(specifier: 10..20) }

      community

      # Add email address after creation since Person model likely requires it for mailer
      after(:create) do |person|
        # Ensure person has contact_detail
        person.contact_detail ||= create(:better_together_contact_detail, contactable: person)
        # Reload to avoid optimistic locking issues when touch callbacks run
        person.contact_detail.reload

        # Pass contact_detail_id explicitly so AR loads a fresh instance when touching
        create(
          :better_together_email_address,
          contact_detail_id: person.contact_detail.id,
          email: Faker::Internet.unique.email,
          primary_flag: true
        )
      end
    end
  end
end
