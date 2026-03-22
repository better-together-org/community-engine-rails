# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/IndexedLet
module BetterTogether
  module Metrics # rubocop:disable Metrics/ModuleLength
    RSpec.describe ReportsController do
      describe 'GET #index', :as_platform_manager do
        let!(:page_view1) do
          create(:metrics_page_view,
                 page_url: '/page1',
                 viewed_at: 2.days.ago)
        end
        let!(:page_view2) do
          create(:metrics_page_view,
                 page_url: '/page1',
                 viewed_at: 1.day.ago)
        end
        let!(:page_view3) do
          create(:metrics_page_view,
                 page_url: '/page2',
                 viewed_at: 1.day.ago)
        end

        let!(:link_click1) do
          create(:metrics_link_click,
                 url: 'https://example.com',
                 page_url: '/page1',
                 internal: false,
                 clicked_at: 2.days.ago)
        end
        let!(:link_click2) do
          create(:metrics_link_click,
                 url: 'https://internal.example.com/path',
                 page_url: '/page2',
                 internal: true,
                 clicked_at: 1.day.ago)
        end

        let!(:download) do
          create(:metrics_download,
                 file_name: 'document.pdf')
        end

        let!(:share1) do
          create(:metrics_share,
                 url: 'https://facebook.com/share/page1',
                 platform: 'facebook')
        end
        let!(:share2) do
          create(:metrics_share,
                 url: 'https://bsky.app/share/page1',
                 platform: 'bluesky')
        end
        let!(:share3) do
          create(:metrics_share,
                 url: 'https://facebook.com/share/page2',
                 platform: 'facebook')
        end

        let!(:valid_link) do
          create(:content_link,
                 host: 'example.com',
                 valid_link: true,
                 last_checked_at: 1.day.ago)
        end
        let!(:invalid_link) do
          create(:content_link,
                 host: 'broken.com',
                 valid_link: false,
                 last_checked_at: 1.day.ago)
        end

        before do
          get better_together.metrics_reports_path(locale: I18n.default_locale)
        end

        it 'returns http success' do
          expect(response).to have_http_status(:success)
        end

        it 'assigns page views grouped by URL' do
          expect(assigns(:page_views_by_url)).to be_present
          expect(assigns(:page_views_by_url)['/page1']).to eq(2)
          expect(assigns(:page_views_by_url)['/page2']).to eq(1)
        end

        it 'assigns page views grouped by day' do
          expect(assigns(:page_views_daily)).to be_present
          expect(assigns(:page_views_daily)).to be_a(Hash)
        end

        it 'assigns link clicks grouped by URL' do
          expect(assigns(:link_clicks_by_url)).to be_present
          expect(assigns(:link_clicks_by_url)['https://example.com']).to eq(1)
          expect(assigns(:link_clicks_by_url)['https://internal.example.com/path']).to eq(1)
        end

        it 'assigns link clicks grouped by day' do
          expect(assigns(:link_clicks_daily)).to be_present
          expect(assigns(:link_clicks_daily)).to be_a(Hash)
        end

        it 'assigns internal vs external link clicks' do
          expect(assigns(:internal_vs_external)).to be_present
          expect(assigns(:internal_vs_external)[true]).to eq(1)  # internal
          expect(assigns(:internal_vs_external)[false]).to eq(1) # external
        end

        it 'assigns link clicks grouped by page' do
          expect(assigns(:link_clicks_by_page)).to be_present
          expect(assigns(:link_clicks_by_page)['/page1']).to eq(1)
          expect(assigns(:link_clicks_by_page)['/page2']).to eq(1)
        end

        it 'assigns downloads grouped by file' do
          expect(assigns(:downloads_by_file)).to be_present
          expect(assigns(:downloads_by_file)['document.pdf']).to eq(1)
        end

        it 'assigns shares grouped by platform' do
          expect(assigns(:shares_by_platform)).to be_present
          expect(assigns(:shares_by_platform)['facebook']).to eq(2)
          expect(assigns(:shares_by_platform)['bluesky']).to eq(1)
        end

        it 'assigns shares grouped by URL and platform' do
          expect(assigns(:shares_by_url_and_platform)).to be_present
          expect(assigns(:shares_by_url_and_platform)[['https://facebook.com/share/page1', 'facebook']]).to eq(1)
          expect(assigns(:shares_by_url_and_platform)[['https://bsky.app/share/page1', 'bluesky']]).to eq(1)
          expect(assigns(:shares_by_url_and_platform)[['https://facebook.com/share/page2', 'facebook']]).to eq(1)
        end

        it 'assigns shares data for Chart.js' do
          expect(assigns(:shares_data)).to be_present
          expect(assigns(:shares_data)[:labels]).to include('https://facebook.com/share/page1', 'https://facebook.com/share/page2')
          expect(assigns(:shares_data)[:datasets]).to be_an(Array)
          expect(assigns(:shares_data)[:datasets].map { |d| d[:label] }).to include('Facebook', 'Bluesky')
        end

        it 'assigns links grouped by host' do
          expect(assigns(:links_by_host)).to be_present
          expect(assigns(:links_by_host)['example.com']).to eq(1)
          expect(assigns(:links_by_host)['broken.com']).to eq(1)
        end

        it 'assigns invalid links grouped by host' do
          expect(assigns(:invalid_by_host)).to be_present
          expect(assigns(:invalid_by_host)['broken.com']).to eq(1)
          expect(assigns(:invalid_by_host)['example.com']).to be_nil
        end

        it 'assigns failures grouped by day' do
          expect(assigns(:failures_daily)).to be_present
          expect(assigns(:failures_daily)).to be_a(Hash)
        end

        context 'when testing Chart.js data structure' do
          it 'generates proper dataset structure' do
            datasets = assigns(:shares_data)[:datasets]
            expect(datasets.first).to have_key(:label)
            expect(datasets.first).to have_key(:backgroundColor)
            expect(datasets.first).to have_key(:data)
          end

          it 'includes color for each platform' do
            datasets = assigns(:shares_data)[:datasets]
            datasets.each do |dataset|
              expect(dataset[:backgroundColor]).to be_present
              expect(dataset[:backgroundColor]).to match(/rgba\(\d+,\s*\d+,\s*\d+,\s*[\d.]+\)/)
            end
          end
        end
      end

      describe '#random_color_for_platform' do
        let(:controller) { described_class.new }

        it 'returns specific color for facebook' do
          expect(controller.random_color_for_platform('facebook')).to eq('rgba(59, 89, 152, 0.5)')
        end

        it 'returns specific color for bluesky' do
          expect(controller.random_color_for_platform('bluesky')).to eq('rgba(29, 161, 242, 0.5)')
        end

        it 'returns specific color for linkedin' do
          expect(controller.random_color_for_platform('linkedin')).to eq('rgba(0, 123, 182, 0.5)')
        end

        it 'returns specific color for pinterest' do
          expect(controller.random_color_for_platform('pinterest')).to eq('rgba(189, 8, 28, 0.5)')
        end

        it 'returns specific color for reddit' do
          expect(controller.random_color_for_platform('reddit')).to eq('rgba(255, 69, 0, 0.5)')
        end

        it 'returns specific color for whatsapp' do
          expect(controller.random_color_for_platform('whatsapp')).to eq('rgba(37, 211, 102, 0.5)')
        end

        it 'returns default color for unknown platform' do
          expect(controller.random_color_for_platform('unknown')).to eq('rgba(75, 192, 192, 0.5)')
        end
      end
    end
  end
end
# rubocop:enable RSpec/IndexedLet
