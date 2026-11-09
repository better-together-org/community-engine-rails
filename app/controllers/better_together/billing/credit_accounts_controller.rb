# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward picks a person (a search over this platform's members, see #people), sees their credit, every
    # lot and entry, and can give credit from there (see CreditGrantsController).
    class CreditAccountsController < ApplicationController
      include OwnerScoped

      PEOPLE_LIMIT = 20

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::CreditAccount, :index?
        @person_id = params[:person_id].to_s.strip
        @holder = find_holder(@person_id) if @person_id.present?
        @lookup_failed = @person_id.present? && @holder.nil?
        @accounts = listed_accounts
      end

      # Options for the person select: [{ value:, text: }], at most 20, matching a name or the start of a handle.
      def people
        authorize BetterTogether::Billing::CreditAccount, :index?
        render json: matching_people(params[:search].to_s.strip).limit(PEOPLE_LIMIT).map { |person|
          { value: person.id, text: person.select_option_title }
        }
      end

      def show
        @account = accounts.find(params[:id])
        authorize @account
        @lots = @account.lots.order(:created_at)
        @entries = @account.entries.includes(:lot, :actor).newest_first.limit(200)
      end

      private

      def accounts = billing_owner.billing_credit_accounts

      def listed_with_holders = accounts.includes(holder: :string_translations)

      # The found person's accounts, else the accounts that hold a balance.
      def listed_accounts
        return listed_with_holders.where(holder: @holder).order(:currency) if @holder

        listed_with_holders.where.not(balance_cents: 0).order(updated_at: :desc).limit(50)
      end

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

      def find_holder(person_id) = platform_people.find_by(id: person_id)

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
