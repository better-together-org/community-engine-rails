# frozen_string_literal: true

require 'rake'

module BetterTogether
  # Generates the sitemap in a background job so newly published pages are included
  class SitemapRefreshJob < ApplicationJob
    queue_as :default

    def perform
      Rails.application.load_tasks unless Rake::Task.task_defined?('sitemap:refresh')
      Rake::Task['sitemap:refresh'].invoke
      Rake::Task['sitemap:refresh'].reenable
    end
  end
end
