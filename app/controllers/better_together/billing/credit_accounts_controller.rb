# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward finds a person's store credit by their exact handle (there is no search and no list of
    # everyone), sees every lot and entry, and can give credit from there (see CreditGrantsController).
    class CreditAccountsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::CreditAccount, :index?
        @handle = params[:handle].to_s.strip
        @holder = find_holder(@handle) if @handle.present?
        @lookup_failed = @handle.present? && @holder.nil?
        @accounts = listed_accounts
      end

      def show
        @account = accounts.find(params[:id])
        authorize @account
        @lots = @account.lots.order(:created_at)
        @entries = @account.entries.includes(:lot, :actor).newest_first.limit(200)
      end

      private

      def accounts = billing_owner.billing_credit_accounts

      # The found person's accounts, else the accounts that hold a balance.
      def listed_accounts
        return accounts.where(holder: @holder).order(:currency) if @holder

        accounts.where.not(balance_cents: 0).order(updated_at: :desc).limit(50)
      end

      # Exactly the handle, never a partial match, so this cannot be used to browse people.
      def find_holder(handle) = BetterTogether::Person.find_by(identifier: handle.downcase)
    end
  end
end
