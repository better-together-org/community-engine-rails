# frozen_string_literal: true

module BetterTogether
  module Billing
    # Makes the invoice and receipt of an order again in another language. A steward who placed an order for someone
    # who does not read the language it was made in, or the buyer, picks one of the supported languages; the order
    # remembers it, so documents made later (after a payment or a refund) stay in it. The documents already made are
    # kept, marked superseded, like any document that is replaced.
    #
    # Reached through the buyer's own order, or through a sale the platform's stewards manage.
    class OrderDocumentsController < ApplicationController
      include OwnerScoped

      before_action :set_order
      after_action :verify_authorized

      def create
        authorize @order, sale_route? ? :sale? : :show?
        locale = chosen_locale
        return redirect_back_to_order(alert: t('better_together.billing.order_documents.unknown_locale')) unless locale

        return redirect_back_to_order(alert: t('better_together.billing.order_documents.already_in_language')) if already_in?(locale)

        regenerate(locale)
        redirect_back_to_order(notice: t('better_together.billing.order_documents.regenerated', language: language_name(locale)))
      end

      private

      def sale_route? = params[:sale_id].present?

      def set_order
        @order = if sale_route?
                   billing_owner.billing_orders.sold_by_platform.find(params[:sale_id])
                 else
                   billing_owner.billing_orders.bought_by(current_user.person).find(params[:order_id])
                 end
      end

      def chosen_locale
        I18n.available_locales.find { |locale| locale.to_s == params[:document_locale].to_s }
      end

      def already_in?(locale) = @order.documents_locale == locale.to_s

      def regenerate(locale)
        @order.update!(document_locale: locale.to_s)
        kinds = [@order.invoice_document, @order.receipt_document].compact.map { |document| document.kind.to_sym }
        kinds = [nil] if kinds.empty?
        kinds.each { |kind| Orders::GenerateDocument.call(@order, kind:, locale:) }
      end

      def language_name(locale) = I18n.t("locales.#{locale}", default: locale.to_s)

      def redirect_back_to_order(**flash)
        path = sale_route? ? billing_sale_path(@order, locale: I18n.locale) : billing_order_path(@order, locale: I18n.locale)
        redirect_to path, **flash
      end
    end
  end
end
