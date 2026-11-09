# frozen_string_literal: true

module BetterTogether
  module Billing
    # Finding a person of this platform for a billing screen: the members a steward may pick from, and the
    # search behind the person select (see CreditAccountsController#people). One rule for who can be reached.
    module PersonLookup
      extend ActiveSupport::Concern

      PEOPLE_LIMIT = 20

      private

      # Only people who belong to this platform (or, on the host platform, its community), so a steward cannot
      # reach anyone outside it. Same membership rule as the invitation search.
      def platform_people
        ids = BetterTogether::PersonPlatformMembership.active.where(joinable: billing_owner).pluck(:member_id)
        community = billing_owner.community
        if billing_owner.host? && community.present?
          ids |= BetterTogether::PersonCommunityMembership.active.where(joinable: community).pluck(:member_id)
        end
        BetterTogether::Person.where(id: ids)
      end

      def find_platform_person(person_id) = platform_people.find_by(id: person_id)

      # A search term is needed, so the endpoint does not list everyone.
      def matching_people(term)
        return BetterTogether::Person.none if term.length < 2

        like = BetterTogether::Person.sanitize_sql_like(term)
        matches = platform_people.where(id: named_like(like)).or(platform_people.where(id: handled_like(like)))
        matches.includes(:string_translations).order(:identifier)
      end

      def named_like(like)
        values = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.arel_table
        BetterTogether::Person.joins(:string_translations).where(values[:key].eq('name'))
                              .where(values[:value].matches("%#{like}%")).select(:id)
      end

      def handled_like(like)
        BetterTogether::Person.where(BetterTogether::Person.arel_table[:identifier].matches("#{like}%")).select(:id)
      end
    end
  end
end
