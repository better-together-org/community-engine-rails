# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards manage what their platform sells once: the products, with what each includes and its prices. Reached only
    # through the billing owner (see OwnerScoped); what may be changed is decided by Product.permitted_attributes, so a crafted
    # request cannot set the subtype, the seller or the platform.
    class ProductsController < ApplicationController
      include OwnerScoped

      before_action :set_product, only: %i[show edit update]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Product
        @products = policy_scope(platform_products).includes(:prices).order(:identifier).load
      end

      def show
        authorize @product
      end

      def new
        @product = platform_products.build
        authorize @product
      end

      def create
        @product = platform_products.build(params.require(:billing_product).permit(Product.permitted_attributes_for_create))
        authorize @product

        if @product.save
          redirect_to billing_product_path(@product, locale: I18n.locale), notice: t('better_together.billing.products.created')
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit
        authorize @product
      end

      def update
        authorize @product

        if @product.update(product_params)
          redirect_to billing_product_path(@product, locale: I18n.locale), notice: t('better_together.billing.products.updated')
        else
          render :edit, status: :unprocessable_content
        end
      end

      private

      # What the platform sells itself; a product sold by a community or person belongs to that seller.
      def platform_products = billing_owner.billing_products.sold_by_platform

      def set_product
        @product = platform_products.find(params[:id])
      end

      def product_params = params.require(:billing_product).permit(Product.permitted_attributes)
    end
  end
end
