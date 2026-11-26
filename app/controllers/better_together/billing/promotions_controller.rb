# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards make promotion codes and switch them on and off. The code is shown once, in the response to
    # the form that made it (never in a redirect or flash), and cannot be read back afterwards.
    class PromotionsController < ApplicationController
      include OwnerScoped

      before_action :set_promotion, only: %i[activate deactivate]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Promotion
        @promotions = promotions.order(created_at: :desc)
      end

      def new
        authorize BetterTogether::Billing::Promotion
      end

      def create
        authorize BetterTogether::Billing::Promotion
        @result = Promotions::Create.call(platform: billing_owner, actor: current_user.person, **promotion_attributes)
        response.headers['Cache-Control'] = 'no-store'
        render :created, status: :created
      rescue Promotions::Create::Refused => e
        @error = e.message
        render :new, status: :unprocessable_content
      end

      def activate = switch(true)

      def deactivate = switch(false)

      private

      def promotions = billing_owner.billing_promotions

      def set_promotion
        @promotion = promotions.find(params[:id])
      end

      def switch(active)
        authorize @promotion, active ? :activate? : :deactivate?
        @promotion.update!(active:)
        redirect_to billing_promotions_path(locale: I18n.locale), notice: t('better_together.billing.promotions.switched')
      end

      def promotion_attributes
        currency = params[:currency].to_s.upcase
        { name: params[:name].to_s.strip, **name_translations, currency:, amount_cents: Currency.to_minor(params[:amount], currency).to_i,
          **limit_attributes }
      end

      # name_fr, name_es and so on: the same promotion name in the other languages.
      def name_translations
        (I18n.available_locales - [I18n.locale]).to_h { |locale| [:"name_#{locale}", params["name_#{locale}"].to_s.strip.presence] }.compact
      end

      def limit_attributes
        { credit_expires_after_days: whole_number(:credit_expires_after_days), max_redemptions: whole_number(:max_redemptions),
          starts_at: time_param(:starts_at), ends_at: time_param(:ends_at), purposes: Array(params[:purposes]),
          new_members_only: params[:new_members_only] == '1' }
      end

      def whole_number(key) = params[key].to_s.match?(/\A\d{1,9}\z/) ? params[key].to_i : nil

      def time_param(key)
        params[key].present? ? Time.zone.parse(params[key].to_s) : nil
      rescue ArgumentError
        nil
      end
    end
  end
end
