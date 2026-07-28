# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Builds alert messages for insufficient C3 balance scenarios
    class InsufficientC3AlertBuilder
      def self.call(agreement, controller)
        new(agreement, controller).build
      end

      def initialize(agreement, controller)
        @agreement = agreement
        @controller = controller
      end

      def build
        payer = @agreement.try(:request)&.try(:creator)
        return payer_message unless payer_is_current_user?(payer)

        current_user_message(payer)
      end

      private

      def payer_is_current_user?(payer)
        payer.present? && payer == @controller.current_person
      end

      def current_user_message(payer)
        price_millitokens = @agreement.try(:offer)&.try(:c3_price_millitokens).to_i
        current_millitokens = available_millitokens_for(payer)
        @controller.t('flash.joatu.agreement.insufficient_c3',
                      needed: @controller.helpers.tree_seeds_display(price_millitokens),
                      current: @controller.helpers.tree_seeds_display(current_millitokens),
                      default: 'You need %<needed>s to accept this offer. Your current balance is %<current>s.')
      end

      def payer_message
        price_millitokens = @agreement.try(:offer)&.try(:c3_price_millitokens).to_i
        @controller.t('flash.joatu.agreement.insufficient_c3_payer',
                      needed: @controller.helpers.tree_seeds_display(price_millitokens),
                      default: 'The payer has insufficient Tree Seeds to accept this offer (needs %<needed>s).')
      end

      def available_millitokens_for(payer)
        balance = BetterTogether::C3::Balance.find_by(holder: payer, community: nil)
        balance&.available_millitokens.to_i
      end
    end
  end
end
