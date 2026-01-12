# frozen_string_literal: true

# Migration to add creator tracking to all metrics report tables
class AddCreatorToMetricsReports < ActiveRecord::Migration[7.2]
  # rubocop:disable Metrics/MethodLength
  def change
    # Add creator_id to all metrics report tables only if the column doesn't exist
    unless column_exists?(:better_together_metrics_user_account_reports, :creator_id)
      add_reference :better_together_metrics_user_account_reports, :creator,
                    foreign_key: { to_table: :better_together_people },
                    type: :uuid,
                    null: true,
                    index: true
    end

    unless column_exists?(:better_together_metrics_link_checker_reports, :creator_id)
      add_reference :better_together_metrics_link_checker_reports, :creator,
                    foreign_key: { to_table: :better_together_people },
                    type: :uuid,
                    null: true,
                    index: true
    end

    unless column_exists?(:better_together_metrics_page_view_reports, :creator_id)
      add_reference :better_together_metrics_page_view_reports, :creator,
                    foreign_key: { to_table: :better_together_people },
                    type: :uuid,
                    null: true,
                    index: true
    end

    return if column_exists?(:better_together_metrics_link_click_reports, :creator_id)

    add_reference :better_together_metrics_link_click_reports, :creator,
                  foreign_key: { to_table: :better_together_people },
                  type: :uuid,
                  null: true,
                  index: true
  end
  # rubocop:enable Metrics/MethodLength
end
