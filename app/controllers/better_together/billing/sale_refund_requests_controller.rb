# frozen_string_literal: true

module BetterTogether
  module Billing
    # The steward's queue of refund requests for what the platform sells, and the decision on each: approve, approve
    # part, or decline, with a reply the buyer is told.
    class SaleRefundRequestsController < ApplicationController
      include OwnerScoped

      PER_PAGE = 25

      before_action :set_request, only: %i[show decide]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::RefundRequest
        @refund_requests = queue.newest_first.page(params[:page]).per(PER_PAGE)
      end

      def show
        authorize @refund_request
      end

      def decide
        authorize @refund_request
        RefundRequests::Decide.call(request: @refund_request, decider: current_user.person, outcome: params[:outcome],
                                    approved_amount_cents:, note: params[:decision_note])
        redirect_to request_path, notice: t('better_together.billing.refund_requests.decided')
      rescue RefundRequests::Decide::Refused => e
        redirect_to request_path, alert: e.message
      end

      private

      def request_path = billing_refund_request_path(@refund_request, locale: I18n.locale)

      def queue
        scope = policy_scope(billing_owner.billing_refund_requests).includes(:order, :requester)
        RefundRequest::STATUSES.include?(params[:status].to_s) ? scope.where(status: params[:status]) : scope
      end

      def set_request
        @refund_request = billing_owner.billing_refund_requests.find(params[:id])
      end

      def approved_amount_cents
        params[:approved_amount].present? ? Currency.to_minor(params[:approved_amount], @refund_request.currency).to_i : nil
      end
    end
  end
end
