# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards manage the billing plans of their platform. Plans are reached only through
    # the billing owner (see OwnerScoped), and what a steward may change on a plan is
    # decided by the plan itself: fields the processor fixes at creation are not permitted
    # once the plan is linked, so a crafted request cannot change them either.
    class PlansController < ApplicationController
      include OwnerScoped

      before_action :set_plan, only: %i[show edit update sync snapshot]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Plan
        @plans = policy_scope(platform_plans).order(:identifier)
      end

      def show
        authorize @plan
      end

      def new
        @plan = platform_plans.build(next_plan_defaults.merge(link_existing: params[:mode] == 'link'))
        authorize @plan
      end

      def create
        @plan = platform_plans.build(plan_params_for_create)
        authorize @plan

        if @plan.save
          redirect_to billing_plan_path(@plan), notice: t('better_together.billing.plans.created')
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit
        authorize @plan
      end

      def update
        authorize @plan
        assign_update_params

        if @plan.save
          redirect_to billing_plan_path(@plan), notice: t('better_together.billing.plans.updated')
        else
          render :edit, status: :unprocessable_content
        end
      end

      # Pushes the plan to the processor again, for a plan whose last push failed.
      def sync
        authorize @plan, :sync?

        if @plan.sync_supported?
          @plan.restart_sync!
          BetterTogether::Billing::SyncPlanJob.perform_later(@plan.id)
          redirect_to billing_plan_path(@plan), notice: t('better_together.billing.plans.sync_requested')
        else
          redirect_to billing_plan_path(@plan), alert: t('better_together.billing.plans.sync_unsupported')
        end
      end

      # A live look at the processor-side price, loaded into the plan page's turbo frame.
      def snapshot
        authorize @plan, :snapshot?
        @snapshot = BetterTogether::Billing::PlanSnapshot.call(@plan)

        render partial: 'better_together/billing/plans/snapshot', locals: { plan: @plan, snapshot: @snapshot }
      end

      private

      # What the platform sells itself. Plans sold by one of its communities or people belong
      # to that seller and are not managed from here (see PlanPolicy#manage_billing?).
      def platform_plans = billing_owner.billing_plans.sold_by_platform

      def set_plan
        @plan = platform_plans.find(params[:id])
      end

      # "Change price": a processor price cannot be edited, so the next price is a new plan
      # that starts from this one and shares its product.
      def next_plan_defaults
        source = platform_plans.find_by(id: params[:from])
        return {} unless source

        { identifier: "#{source.identifier}-next", name: source.name, description: source.description,
          processor: source.processor, processor_product_id: source.processor_product_id,
          billing_interval: source.billing_interval, currency: source.currency, metadata: source.metadata }
      end

      def plan_params_for_create
        permitted = params.require(:billing_plan).permit(Plan.permitted_attributes_for_create).to_h
        permitted['metadata'] = normalized_metadata(permitted['metadata']) if permitted['metadata']
        permitted
      end

      # Only fields this plan still accepts. Metadata is merged into what is stored, so a
      # key the form does not carry (one a later feature or the processor wrote) survives.
      def assign_update_params
        permitted = params.require(:billing_plan).permit(@plan.permitted_update_attributes).to_h
        metadata = permitted.delete('metadata')
        @plan.assign_attributes(permitted)
        @plan.metadata = @plan.metadata.merge(normalized_metadata(metadata)) if metadata
      end

      # The benefits box posts one string with a benefit per line; owner types arrive as
      # a list with blanks from unchecked boxes.
      def normalized_metadata(metadata)
        metadata = metadata.to_h
        if metadata.key?('participant_benefits')
          metadata['participant_benefits'] = Array(metadata['participant_benefits']).flat_map { |text| text.to_s.split(/\r?\n/) }
                                                                                    .map(&:strip).compact_blank
        end
        if metadata.key?('eligible_billable_owner_types')
          metadata['eligible_billable_owner_types'] = Array(metadata['eligible_billable_owner_types']).compact_blank
        end
        metadata
      end
    end
  end
end
