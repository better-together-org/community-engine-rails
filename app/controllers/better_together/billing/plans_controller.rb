# frozen_string_literal: true

module BetterTogether
  module Billing
    # Host-only CRUD controller for managing Billing::Plan records.
    class PlansController < ApplicationController # rubocop:disable Metrics/ClassLength
      before_action :authenticate_user!
      before_action :set_plan, only: %i[show edit update]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Plan
        @plans = policy_scope(BetterTogether::Billing::Plan).order(:identifier)
      end

      def show
        authorize @plan
        @subscription_health = subscription_health_for(@plan)
        @recent_subscribers = recent_active_subscribers_for(@plan)
      end

      def new
        @plan = BetterTogether::Billing::Plan.new
        authorize @plan
      end

      def create
        @plan = BetterTogether::Billing::Plan.new(plan_params)
        authorize @plan

        if @plan.save
          redirect_to billing_plan_path(@plan),
                      notice: t('better_together.billing.plans.created')
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit
        authorize @plan
      end

      def update
        authorize @plan

        if @plan.update(plan_params)
          redirect_to billing_plan_path(@plan),
                      notice: t('better_together.billing.plans.updated')
        else
          render :edit, status: :unprocessable_content
        end
      end

      private

      def set_plan
        @plan = BetterTogether::Billing::Plan.find(params[:id])
      end

      def subscription_health_for(plan)
        plan.subscriptions
            .joins(:pay_subscription)
            .group(Pay::Subscription.arel_table[:status])
            .count
            .transform_keys { |k| k.presence || 'unknown' }
      end

      def recent_active_subscribers_for(plan)
        plan.subscriptions
            .joins(:pay_subscription)
            .where(pay_subscriptions: { status: 'active' })
            .includes(pay_subscription: :customer)
            .order(Pay::Subscription.arel_table[:created_at].desc)
            .limit(20)
      end

      def plan_params # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        permitted = params.require(:billing_plan).permit(
          :identifier,
          :name,
          :description,
          :billing_interval,
          :amount_cents,
          :currency,
          :stripe_price_id,
          :active,
          metadata: [
            :participant_summary,
            :beneficiary_label,
            :hosted_access_level,
            :support_tier,
            :community_capacity_tier,
            { participant_benefits: [], eligible_billable_owner_types: [] }
          ]
        )

        # Normalize blank arrays to empty arrays so metadata stays clean
        if permitted[:metadata].present?
          permitted[:metadata][:participant_benefits] =
            Array(permitted[:metadata][:participant_benefits]).filter_map(&:presence)
          permitted[:metadata][:eligible_billable_owner_types] =
            Array(permitted[:metadata][:eligible_billable_owner_types]).filter_map(&:presence)
        end

        permitted
      end
    end
  end
end
