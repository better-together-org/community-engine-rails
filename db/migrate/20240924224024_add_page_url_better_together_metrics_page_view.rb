# frozen_string_literal: true

class AddPageUrlBetterTogetherMetricsPageView < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_column :better_together_metrics_page_views, :page_url, :string
  end
end
