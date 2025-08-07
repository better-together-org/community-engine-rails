# frozen_string_literal: true

module BetterTogether
  # Renders the templates for built-in static pages
  class StaticPageTemplateController < AbstractController::Base
    include AbstractController::Rendering
    include ActionView::Layouts
    include AbstractController::Helpers
    include AbstractController::Translation
    include AbstractController::AssetPaths

    # include ActionController::UrlWriter

    # Uncomment if you want to use helpers
    # defined in ApplicationHelper in your views
    helper ApplicationHelper

    # Make sure your controller can find views
    self.view_paths = [
      'app/views',
      File.expand_path("#{::BetterTogether::Engine.root}app/views", __dir__)
    ]

    # You can define custom helper methods to be used in views here
    # helper_method :current_admin
    # def current_admin; nil; end

    PAGE_LIST = %i[
      accessibility better_together code_of_conduct community_engine privacy
      subprocessors terms_of_service
    ].freeze

    PAGE_LIST.each do |page|
      define_method page do
        render template: "better_together/static_pages/#{page}"
      end
    end
  end
end
