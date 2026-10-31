# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the hooks a host app overrides: an extra between the heading and the list on the four geography
# indexes, and an extra before the publishing date on the post form. They are empty in the engine; an override
# replaces only its own partial.
RSpec.describe 'Geography index and post form hooks DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:page_html) { Nokogiri::HTML(response.body) }
  let(:index_paths) do
    { 'regions' => better_together.geography_regions_path(locale:),
      'countries' => better_together.geography_countries_path(locale:),
      'states' => better_together.geography_states_path(locale:),
      'continents' => better_together.geography_continents_path(locale:) }
  end

  describe 'default render' do
    it 'renders each index with its heading and table and nothing extra', :aggregate_failures do
      index_paths.each_value do |path|
        get path

        expect(response).to have_http_status(:ok)
        expect(page_html.at_css('h1')).to be_present
        expect(page_html.at_css('table.table')).to be_present
        expect(page_html.at_css('#host-index-extra')).to be_nil
      end
    end

    it 'renders the post form with the publishing date and nothing extra', :aggregate_failures do
      get better_together.new_post_path(locale:)

      expect(page_html.at_css('[name="post[published_at]"]')).to be_present
      expect(page_html.at_css('#host-post-form-extra')).to be_nil
    end
  end

  describe 'a host override' do
    let(:override_dir) { Rails.root.join('tmp/geography_index_hooks_views') }
    let(:controllers) do
      [BetterTogether::Geography::RegionsController, BetterTogether::Geography::CountriesController,
       BetterTogether::Geography::StatesController, BetterTogether::Geography::ContinentsController,
       BetterTogether::PostsController]
    end
    let!(:original_paths) { controllers.index_with(&:view_paths) }

    before do
      %w[regions countries states continents].each do |kind|
        dir = override_dir.join("better_together/geography/#{kind}")
        FileUtils.mkdir_p(dir)
        File.write(dir.join('_index_extra.html.erb'),
                   "<%# locals: (records:) -%>\n<div id=\"host-index-extra\"><%= records.size %></div>\n")
      end
      posts_dir = override_dir.join('better_together/posts')
      FileUtils.mkdir_p(posts_dir)
      File.write(posts_dir.join('_form_extra.html.erb'),
                 "<%# locals: (form:, post:) -%>\n<div id=\"host-post-form-extra\"></div>\n")
      controllers.each { |controller| controller.prepend_view_path(override_dir.to_s) }
    end

    after do
      original_paths.each { |controller, paths| controller.view_paths = paths }
      FileUtils.rm_rf(override_dir)
    end

    it 'shows the extra on each index above the list', :aggregate_failures do
      index_paths.each_value do |path|
        get path

        expect(page_html.at_css('#host-index-extra')).to be_present
        expect(page_html.at_css('table.table')).to be_present
      end
    end

    it 'shows the extra on the post form and keeps the publishing date', :aggregate_failures do
      get better_together.new_post_path(locale:)

      expect(page_html.at_css('#host-post-form-extra')).to be_present
      expect(page_html.at_css('[name="post[published_at]"]')).to be_present
    end
  end
end
