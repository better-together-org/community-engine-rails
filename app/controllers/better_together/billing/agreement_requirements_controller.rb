# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards choose which agreements a buyer must accept before paying: the platform's defaults,
    # terms of one plan, or the terms that come with a payment method. The agreements themselves
    # (their text, and whether they are in force) are managed with the platform's other agreements.
    #
    # Reached only through the platform; an agreement or plan of another platform is never
    # offered, and the platform on a requirement is the current one whatever is sent.
    class AgreementRequirementsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::AgreementRequirement
        load_page
        @requirement = platform_requirements.build(mode: 'additional')
      end

      def create
        authorize BetterTogether::Billing::AgreementRequirement
        @requirement = platform_requirements.build(requirement_params)

        if @requirement.save
          redirect_to billing_agreement_requirements_path(locale: I18n.locale), notice: t('better_together.billing.requirements.created')
        else
          load_page
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        requirement = platform_requirements.find(params[:id])
        authorize requirement
        requirement.destroy!
        redirect_to billing_agreement_requirements_path(locale: I18n.locale), notice: t('better_together.billing.requirements.removed')
      end

      private

      def billing_available? = BetterTogether::Billing.configurable?(billing_owner)

      def platform_requirements = billing_owner.billing_agreement_requirements

      def platform_plans = billing_owner.billing_plans.sold_by_platform

      def load_page
        @requirements = platform_requirements.includes(:agreement, :target).order(:purpose, :payment_method, :position)
        @agreements = BetterTogether::Agreement.for_platform(billing_owner).where(agreement_kind: 'transactional_agreement').order(:identifier)
        @plans = platform_plans.order(:identifier)
        @readiness = BetterTogether::Billing::Readiness.call(billing_owner)
      end

      # The agreement and the plan are looked up inside this platform, so an id from another
      # platform simply finds nothing.
      def requirement_params
        permitted = params.require(:billing_agreement_requirement).permit(:agreement_id, :target_plan_id, :purpose, :payment_method, :mode,
                                                                          :position)
        plan = platform_plans.find_by(id: permitted.delete(:target_plan_id))
        permitted[:agreement_id] = BetterTogether::Agreement.for_platform(billing_owner).find_by(id: permitted[:agreement_id])&.id
        permitted.merge(target: plan).to_h.symbolize_keys
      end
    end
  end
end
