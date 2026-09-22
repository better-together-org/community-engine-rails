# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::BlocksController, :as_platform_manager do
  include Devise::Test::ControllerHelpers
  include BetterTogether::Engine.routes.url_helpers
  include AutomaticTestConfiguration

  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('platform_manager@example.test', 'SecureTest123!@#', :platform_manager) }

  before do
    configure_host_platform
    sign_in user
  end

  describe 'POST #create' do
    it 'persists extra permitted attributes for standalone html blocks' do
      html_content = '<p>Standalone HTML block content</p>'

      expect do
        post :create, params: {
          locale:,
          block: {
            type: 'BetterTogether::Content::Html',
            identifier: "standalone-html-#{SecureRandom.hex(4)}",
            html_content:
          }
        }
      end.to change(BetterTogether::Content::Html, :count).by(1)

      created_block = BetterTogether::Content::Html.order(created_at: :desc).first
      expect(response).to redirect_to(content_block_path(locale: locale, id: created_block.to_param))
      expect(created_block.html_content).to eq(html_content)
    end
  end

  describe 'PATCH #update' do
    let!(:block) do
      create(:better_together_content_html, html_content: '<p>Original content</p>')
    end

    it 'updates extra permitted attributes for standalone html blocks' do
      updated_html_content = '<p>Updated standalone HTML block content</p>'

      patch :update, params: {
        locale:,
        id: block.to_param,
        block: {
          html_content: updated_html_content
        }
      }

      expect(response).to redirect_to(content_block_path(locale: locale, id: block.to_param))
      expect(block.reload.html_content).to eq(updated_html_content)
    end
  end
end
