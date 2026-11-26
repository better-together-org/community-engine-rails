# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward adds a price to a product and takes one off sale. A price is never edited: a different amount is a new price,
    # and the old one is archived, so an order always matches a price that existed.
    class PricesController < ApplicationController
      include OwnerScoped

      before_action :set_product
      after_action :verify_authorized

      def new
        @price = @product.prices.build(currency: BetterTogether::Billing::Configuration.default_currency)
        authorize @price
      end

      def create
        @price = @product.prices.build(price_params.merge(platform_id: billing_owner.id))
        authorize @price

        if @price.save
          redirect_to billing_product_path(@product, locale: I18n.locale), notice: t('better_together.billing.prices.created')
        else
          render :new, status: :unprocessable_content
        end
      end

      def archive
        price = @product.prices.find(params[:id])
        authorize price
        price.archive!
        redirect_to billing_product_path(@product, locale: I18n.locale), notice: t('better_together.billing.prices.archived')
      end

      private

      def set_product
        @product = billing_owner.billing_products.sold_by_platform.find(params[:product_id])
      end

      # The amount is typed in major units and converted for the currency (see MajorAmount), never given as cents.
      def price_params = params.require(:billing_price).permit(Price.permitted_attributes)
    end
  end
end
