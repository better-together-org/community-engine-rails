# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # Someone buying in person who is not on the platform yet. A seller gives a name and an email address and
      # this makes the person, with that email as their primary one, a member of the platform, and invites them
      # to the community so that signing up later reuses this person (and their order) instead of making a second.
      #
      # A person who already has an account or contact email with that address is found, never duplicated.
      # The invitation email is queued by the caller after the sale is saved, so a refused sale sends nothing.
      class NewBuyer
        class Invalid < StandardError; end

        Result = Struct.new(:person, :invitation, keyword_init: true)

        def self.call(...) = new(...).call

        def initialize(platform:, inviter:, name:, email:, locale: I18n.locale)
          @platform = platform
          @inviter = inviter
          @name = name.to_s.strip
          @email = email.to_s.strip.downcase
          @locale = locale.to_s
        end

        def call
          check!
          existing = existing_person
          return Result.new(person: existing, invitation: nil) if existing

          Person.transaction do
            person = create_person
            Result.new(person:, invitation: invite(person))
          end
        rescue ActiveRecord::RecordInvalid => e
          raise Invalid, e.record.errors.full_messages.to_sentence
        end

        private

        def check!
          raise Invalid, 'a name is needed' if name.blank?
          raise Invalid, 'a valid email address is needed' unless email.match?(URI::MailTo::EMAIL_REGEXP)
        end

        attr_reader :platform, :inviter, :name, :email, :locale

        def existing_person
          BetterTogether::User.find_by(email:)&.person ||
            BetterTogether::EmailAddress.find_by(email:)&.contact_detail&.contactable.then { |owner| owner if owner.is_a?(BetterTogether::Person) }
        end

        def create_person
          person = Person.create!(name:, locale: I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale.to_s)
          person.create_contact_detail!.email_addresses.create!(email:, primary_flag: true, label: 'personal')
          member_of_platform(person)
          person
        end

        def member_of_platform(person)
          role = Role.find_by(identifier: 'platform_member')
          return unless role # same as registration: without the basic role there is no membership to make

          platform.person_platform_memberships.find_or_create_by!(member: person, role:) { |membership| membership.status = 'active' }
        end

        def invite(person)
          community = platform.community
          return unless community

          CommunityInvitation.create!(invitable: community, inviter:, invitee: person, invitee_email: email, locale:,
                                      role: Role.find_by(identifier: 'community_member'), status: 'pending',
                                      valid_from: Time.current)
        end
      end
    end
  end
end
