# frozen_string_literal: true

module BetterTogether
  module Billing
    # The signed-in person's own billing addresses: the ones tax is worked out from, which is the default on
    # this platform, adding one, and choosing another as the default. Only their own addresses are ever read.
    class BillingAddressesController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Order, :index?
        load_addresses
        @new_address = person.contact_detail.addresses.build
      end

      def create # rubocop:disable Metrics/AbcSize
        authorize BetterTogether::Billing::Order, :index?
        result = Checkout::BillingAddressChoice.call(platform: billing_owner, person:, address_id: 'new', new_address: params[:billing_address],
                                                     make_default: params[:make_default_billing] == '1')
        if result.ok?
          return redirect_to(billing_billing_addresses_path(locale: I18n.locale),
                             notice: t('better_together.billing.addresses.added'))
        end

        load_addresses
        @new_address = result.address || person.contact_detail.addresses.build
        flash.now[:alert] = t("better_together.billing.addresses.refused.#{result.error}")
        render :index, status: :unprocessable_content
      end

      def default # rubocop:disable Metrics/AbcSize
        authorize BetterTogether::Billing::Order, :index?
        address = person.addresses.where.not(country_id: nil).where.not(state_id: nil).find(params[:id])
        DefaultAddress.set!(platform: billing_owner, person:, address:, kind: 'billing')
        redirect_to billing_billing_addresses_path(locale: I18n.locale), notice: t('better_together.billing.addresses.default_set')
      end

      private

      def person = current_user.person

      def load_addresses
        options = Checkout::BillingAddressOptions.new(platform: billing_owner, person:)
        @addresses = options.addresses
        @default_id = options.selected_id
      end
    end
  end
end
