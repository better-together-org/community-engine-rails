# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards turn the payment methods outside a vendor (cash, cheque, e-transfer) on and off
    # for their platform and say what buyers are told so they can pay.
    #
    # The page is addressed by method name (`/billing/processor_settings/cash`), taken from the
    # installed methods and never resolved from the request. A method that has not been set up
    # has no row yet; the form builds one and the first save creates it.
    class ProcessorSettingsController < ApplicationController
      include OwnerScoped

      before_action :set_setting, only: %i[edit update]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::ProcessorSetting
        @methods = offline_method_names.map { |name| [name, existing_settings[name]] }
      end

      def edit
        authorize @setting
      end

      def update
        authorize @setting
        @setting.changed_by = current_user.person
        @setting.assign_attributes(setting_params)

        if @setting.save
          redirect_to billing_processor_settings_path(locale: I18n.locale), notice: t('better_together.billing.processor_settings.saved')
        else
          render :edit, status: :unprocessable_content
        end
      end

      private

      # Enabling is a separate decision from having a method installed, so this page works
      # before billing is enabled for the platform.
      def billing_available? = BetterTogether::Billing.configurable?(billing_owner)

      def platform_settings = billing_owner.billing_processor_settings.sold_by_platform

      def existing_settings = @existing_settings ||= platform_settings.index_by(&:processor)

      # Installed methods outside a vendor. Anything else named in the URL is a 404.
      def offline_method_names
        BetterTogether::Billing.processor_names.map(&:to_s).select { |name| BetterTogether::Billing.offline_method?(name) }
      end

      def set_setting
        name = offline_method_names.find { |candidate| candidate == params[:id].to_s }
        raise ActiveRecord::RecordNotFound unless name

        @setting = platform_settings.find_or_initialize_by(processor: name)
      end

      # Only the fields this method declares may be set.
      def setting_params
        fields = @setting.adapter.instruction_fields.map { |field| field.name.to_s }
        permitted = params.require(:billing_processor_setting)
                          .permit(:enabled, :hold_hours, :grant_on, :acknowledge, purposes: [], settings: fields)
        permitted[:settings] ||= {}
        permitted
      end
    end
  end
end
