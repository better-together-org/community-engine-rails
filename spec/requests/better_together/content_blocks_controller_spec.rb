# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Content::BlocksController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:blocks_path) { "/#{locale}/#{BetterTogether.route_scope_path}/content/blocks" }

  describe 'POST /content/blocks' do
    it 'persists extra permitted attributes for standalone html blocks' do
      html_content = '<p>Standalone HTML block content</p>'

      expect do
        post blocks_path, params: {
          block: {
            type: 'BetterTogether::Content::Html',
            identifier: "standalone-html-#{SecureRandom.hex(4)}",
            html_content:
          }
        }
      end.to change(BetterTogether::Content::Html, :count).by(1)

      created_block = BetterTogether::Content::Html.order(created_at: :desc).first
      expect(created_block.html_content).to eq(html_content)
    end
  end

  describe 'PATCH /content/blocks/:id' do
    let!(:block) do
      create(:better_together_content_html, html_content: '<p>Original content</p>')
    end

    it 'updates extra permitted attributes for standalone html blocks' do
      updated_html_content = '<p>Updated standalone HTML block content</p>'

      patch "#{blocks_path}/#{block.to_param}", params: {
        block: {
          html_content: updated_html_content
        }
      }

      expect(block.reload.html_content).to eq(updated_html_content)
    end
  end
end
