# frozen_string_literal: true

# Removes query strings from existing page_url entries
class PurgeQueryStringsFromPageUrls < ActiveRecord::Migration[7.1]
  class PageView < ApplicationRecord # rubocop:todo Style/Documentation
    self.table_name = 'better_together_metrics_page_views'
  end

  def up
    PageView.where("page_url LIKE '%?%'").find_each do |pv|
      uri = URI.parse(pv.page_url)
      PageView.where(id: pv.id).update_all(page_url: uri.path)
    rescue URI::InvalidURIError
      PageView.where(id: pv.id).update_all(page_url: nil)
    end
  end

  def down
    # irreversible
  end
end
