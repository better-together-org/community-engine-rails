# frozen_string_literal: true

module BetterTogether
  module Billing
    # Lets go of quota holds whose time ran out (an upload begun and never finished), so the bytes stop counting
    # against the limit. Quotas are billing's concern now that paid entitlements set their limits, so this runs on the
    # billing queue with the other sweeps. A maintenance sweep: the only cross-tenant read, acting on one hold at a time.
    class ExpireQuotaReservationsJob < ApplicationJob
      def perform
        BetterTogether::Quotas.expire_reservations!
      end
    end
  end
end
