# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards say how their platform collects tax: where it is registered, whether it collects,
    # whether prices include the tax, and its registration number. Registrations are reached only
    # through the billing owner. The registration number is never shown back; leaving it blank
    # on an edit keeps the stored one.
    class TaxRegistrationsController < ApplicationController
      include OwnerScoped

      before_action :set_registration, only: %i[edit update]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::TaxRegistration
        @registrations = policy_scope(platform_registrations).order(:country_iso, :region_code, :effective_from)
      end

      def new
        @registration = platform_registrations.build(status: 'registered')
        authorize @registration
      end

      def create
        @registration = platform_registrations.build(registration_params)
        authorize @registration

        if @registration.save
          redirect_to billing_tax_registrations_path(locale: I18n.locale), notice: t('better_together.billing.tax_registrations.created')
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit
        authorize @registration
      end

      def update
        authorize @registration
        @registration.assign_attributes(registration_params)

        if @registration.save
          redirect_to billing_tax_registrations_path(locale: I18n.locale), notice: t('better_together.billing.tax_registrations.updated')
        else
          render :edit, status: :unprocessable_content
        end
      end

      private

      # Taxes can be set up before billing is enabled for the platform.
      def billing_available? = BetterTogether::Billing.configurable?(billing_owner)

      def platform_registrations = billing_owner.billing_tax_registrations.sold_by_platform

      def set_registration
        @registration = platform_registrations.find(params[:id])
      end

      def registration_params
        permitted = params.require(:billing_tax_registration)
                          .permit(:country_id, :state_id, :status, :prices_include_tax, :registration_number,
                                  :effective_from, :effective_to)
        # "" on the inclusive toggle means the country's usual way; a blank number keeps the stored one.
        permitted[:prices_include_tax] = nil if permitted[:prices_include_tax].blank?
        permitted.delete(:registration_number) if permitted[:registration_number].blank? && @registration&.persisted?
        whole_days(permitted)
      end

      # Dates are whole days: a registration is in force from the start of its first day to the end of its last,
      # and an empty end means it is ongoing.
      def whole_days(permitted)
        started = permitted[:effective_from].presence && Time.zone.parse(permitted[:effective_from].to_s)
        ended = permitted[:effective_to].presence && Time.zone.parse(permitted[:effective_to].to_s)
        permitted[:effective_from] = started&.beginning_of_day
        permitted[:effective_to] = ended&.end_of_day
        permitted
      end
    end
  end
end
