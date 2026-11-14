# frozen_string_literal: true

module BetterTogether
  module Billing
    # A person redeems a promotion code from their credit page. Every failure gets the same answer (see
    # Promotions::Redeem), and the code is never put in a redirect, flash, log line or notice.
    class PromotionRedemptionsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def create
        authorize BetterTogether::Billing::CreditAccount, :own?
        Promotions::Redeem.call(platform: billing_owner, person: current_user.person, code: params[:promotion_code])
        redirect_to billing_credit_path(locale: I18n.locale), notice: t('better_together.billing.promotions.redeemed')
      rescue Promotions::Redeem::Invalid
        redirect_to billing_credit_path(locale: I18n.locale), alert: t('better_together.billing.promotions.invalid')
      end
    end
  end
end
