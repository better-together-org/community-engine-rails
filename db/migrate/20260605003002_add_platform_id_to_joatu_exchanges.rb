# frozen_string_literal: true

# Phase 3 — Joatu exchange isolation.
# Requests, Offers, and Joatu::Agreements all get platform_id so exchange
# listings are scoped to the active platform context.
class AddPlatformIdToJoatuExchanges < ActiveRecord::Migration[7.2]
  def change
    %i[
      better_together_joatu_requests
      better_together_joatu_offers
      better_together_joatu_agreements
    ].each do |table|
      next unless table_exists?(table) && !column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid,
                    null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
