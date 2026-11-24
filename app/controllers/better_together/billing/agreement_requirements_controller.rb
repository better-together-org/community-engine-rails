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

      def edit
        @requirement = platform_requirements.find(params[:id])
        authorize @requirement
        load_form_options
      end

      def update
        @requirement = platform_requirements.find(params[:id])
        authorize @requirement

        if @requirement.update(requirement_params)
          redirect_to billing_agreement_requirements_path(locale: I18n.locale), notice: t('better_together.billing.requirements.updated')
        else
          load_form_options
          render :edit, status: :unprocessable_content
        end
      end

      # Puts a draft or retired agreement in force from the purchase terms list.
      def activate_agreement
        requirement = platform_requirements.find(params[:id])
        authorize requirement
        agreement = requirement.agreement
        authorize agreement, :update?, policy_class: BetterTogether::AgreementPolicy

        agreement.update!(lifecycle_state: 'active')
        redirect_to billing_agreement_requirements_path(locale: I18n.locale), notice: t('better_together.billing.requirements.activated')
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
        load_form_options
        @readiness = BetterTogether::Billing::Readiness.call(billing_owner)
      end

      def load_form_options
        @agreements = platform_agreements.where(agreement_kind: 'transactional_agreement').order(:identifier)
        @plans = platform_plans.order(:identifier)
      end

      # The agreement and the plan are looked up inside this platform, so an id from another
      # platform simply finds nothing.
      def requirement_params
        permitted = params.require(:billing_agreement_requirement).permit(:agreement_id, :target_plan_id, :purpose, :payment_method, :mode,
                                                                          :position)
        attributes = permitted.except(:target_plan_id, :agreement_id).to_h.symbolize_keys
        attributes.merge!(agreement_attribute(permitted), target_attribute(permitted))
      end

      def agreement_attribute(permitted)
        return {} unless permitted.key?(:agreement_id)

        { agreement_id: platform_agreements.find_by(id: permitted[:agreement_id])&.id }
      end

      def target_attribute(permitted)
        return {} unless permitted.key?(:target_plan_id)

        { target: platform_plans.find_by(id: permitted[:target_plan_id]) }
      end

      def platform_agreements = BetterTogether::Agreement.for_platform(billing_owner)
    end
  end
end
