# frozen_string_literal: true

module BetterTogether
  module Billing
    # A person's own store credit: what they can spend, each amount with when it expires, and what has
    # happened to it. Only their own accounts on this platform are ever loaded, whatever is sent.
    class CreditsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def show
        authorize BetterTogether::Billing::CreditAccount, :own?
        @accounts = billing_owner.billing_credit_accounts.where(holder: current_user.person).includes(:lots).order(:currency)
        @history = history_for(@accounts)
      end

      private

      # The newest entries of each account, by account id.
      def history_for(accounts)
        accounts.index_with { |account| account.entries.includes(:lot).newest_first.limit(50) }
      end
    end
  end
end
