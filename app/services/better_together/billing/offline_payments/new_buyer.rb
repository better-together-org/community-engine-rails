# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # Someone buying in person who was not picked from the member list, from a name and an email address.
      #
      # An email nobody has: a new person with that email, a member of the platform, invited to the community so
      # that signing up later reuses them. An email of a member of this platform is refused (pick them from the
      # list). An email of an account that is not a member here makes a guest for this sale only: a person on this
      # platform with no login and no email, so the existing account is never touched or bound to the sale.
      # Invitations are capped per steward per day; the cap applies to both cases so a refusal reveals nothing.
      # The invitation email is queued by the caller after the sale is saved, so a refused sale sends nothing.
      class NewBuyer
        class Invalid < StandardError; end

        # The email belongs to a member of this platform, who has to be picked from the member list.
        class MemberEmail < Invalid; end

        # This steward has already caused the day's most invitations.
        class OverCap < Invalid; end

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
          raise MemberEmail, 'that person is a member: choose them from the member list' if existing && member?(existing)

          check_cap!
          return Result.new(person: create_guest, invitation: nil) if existing

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

        # Same rule as the member list a steward picks from (see PersonLookup).
        def member?(person)
          return true if PersonPlatformMembership.active.exists?(joinable: platform, member: person)

          community = platform.community
          platform.host? && community.present? && PersonCommunityMembership.active.exists?(joinable: community, member: person)
        end

        def check_cap!
          sent = CommunityInvitation.where(inviter:).where(created_at: 1.day.ago..).count
          raise OverCap, 'too many invitations today' if sent >= Configuration.walk_up_invitation_cap
        end

        # Not a member, no login and no email address, so it cannot collide with the account the email belongs to.
        def create_guest
          Person.create!(name:, platform:, privacy: 'private', locale: person_locale)
        end

        def person_locale = I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale.to_s

        def create_person
          person = Person.create!(name:, locale: person_locale)
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
