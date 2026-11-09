# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward picks a person (a search over this platform's members, see #people), sees their credit, every
    # lot and entry, and can give credit from there (see CreditGrantsController).
    class CreditAccountsController < ApplicationController
      include OwnerScoped
      include PersonLookup

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::CreditAccount, :index?
        @person_id = params[:person_id].to_s.strip
        @holder = find_platform_person(@person_id) if @person_id.present?
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
    end
  end
end
