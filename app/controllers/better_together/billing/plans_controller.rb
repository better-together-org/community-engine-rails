# frozen_string_literal: true

module BetterTogether
  module Billing
    # Host-only CRUD controller for managing Billing::Plan records.
    class PlansController < ApplicationController
      before_action :authenticate_user!
      before_action :set_plan, only: %i[show edit update]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Plan
        @plans = policy_scope(BetterTogether::Billing::Plan).order(:identifier)
      end

      def show
        authorize @plan
      end

      def new
        @plan = BetterTogether::Billing::Plan.new
        authorize @plan
      end

      def create
        @plan = BetterTogether::Billing::Plan.new(plan_params_for_create)
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

      def plan_params_for_create
        raw = params.require(:billing_plan).permit(Plan.permitted_attributes_for_create)
        normalize_metadata_arrays!(raw)
        raw
      end

      def plan_params
        raw = params.require(:billing_plan).permit(Plan.permitted_attributes)
        normalize_metadata_arrays!(raw)
        raw
      end

      def normalize_metadata_arrays!(permitted)
        return unless permitted[:metadata].present?

        permitted[:metadata][:participant_benefits] =
          Array(permitted[:metadata][:participant_benefits]).filter_map(&:presence)
        permitted[:metadata][:eligible_billable_owner_types] =
          Array(permitted[:metadata][:eligible_billable_owner_types]).filter_map(&:presence)
      end
    end
  end
end
