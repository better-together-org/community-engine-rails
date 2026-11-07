# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards see the platform's subscribers (the subscriptions Community Engine renews) and can cover a
    # period without payment, give more time before a lapse, cancel, or move one to the plan's current price.
    # Reached only through the platform, so another platform's subscription is a 404.
    class SubscribersController < ApplicationController
      include OwnerScoped

      FILTERS = { 'overdue' => 'past_due', 'lapsed' => 'unpaid', 'active' => 'active', 'ended' => 'canceled' }.freeze

      before_action :set_term, except: :index
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::SubscriptionTerm, :index?
        @filter = FILTERS.key?(params[:filter]) ? params[:filter] : nil
        @terms = filtered(terms).includes(:plan, pay_subscription: { customer: :owner })
                                .order(created_at: :desc).limit(200).load
        preload_payer_names(@terms)
      end

      def show
        authorize @term, :subscriber?
      end

      def waive
        authorize @term
        Subscriptions::Waive.call(term: @term, by: current_user.person)
        back(:notice, 'waived')
      rescue Subscriptions::Waive::Refused
        back(:alert, 'refused')
      end

      def extend_grace
        authorize @term
        Subscriptions::ExtendGrace.call(term: @term, days: params[:days])
        back(:notice, 'grace_extended')
      rescue Subscriptions::ExtendGrace::Refused
        back(:alert, 'refused')
      end

      def cancel
        authorize @term, :steward_cancel?
        Subscriptions::Cancel.call(term: @term, now: params[:now] == '1', by: current_user.person)
        back(:notice, 'cancelled')
      end

      def move_to_current_price
        authorize @term
        Subscriptions::MoveToCurrentPrice.call(term: @term)
        back(:notice, 'price_moved')
      end

      private

      # Payers can be of more than one type, so their names are preloaded only where the type has them.
      def preload_payer_names(records)
        owners = records.map(&:payer).compact.select { |owner| owner.respond_to?(:string_translations) }
        ActiveRecord::Associations::Preloader.new(records: owners, associations: :string_translations).call
      end

      def terms = billing_owner.billing_subscription_terms.local.joins(pay_subscription: :customer)

      def filtered(scope) = @filter ? scope.where(pay_subscriptions: { status: FILTERS.fetch(@filter) }) : scope

      def set_term
        @term = terms.find(params[:id])
      end

      def back(kind, key)
        redirect_to billing_subscriber_path(@term, locale: I18n.locale), kind => t("better_together.billing.subscribers.#{key}")
      end
    end
  end
end
