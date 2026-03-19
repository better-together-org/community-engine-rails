# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::PageBlocks', :no_auth do
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:manager_token) { api_sign_in_and_get_token(manager_user) }
  let(:manager_headers) { api_auth_headers(manager_user, token: manager_token) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_token) { api_sign_in_and_get_token(regular_user) }
  let(:regular_headers) { api_auth_headers(regular_user, token: regular_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let(:page)  { create(:better_together_page) }
  let(:block) { create(:content_markdown, :simple, privacy: 'public') }

  describe 'GET /api/v1/page_blocks' do
    let!(:page_block) { create(:page_content_block, page: page, block: block) }
    let(:url) { '/api/v1/page_blocks' }

    context 'when authenticated as platform manager' do
      before { get url, headers: manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the page_block' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |pb| pb['id'] }
        expect(ids).to include(page_block.id)
      end
    end

    context 'when unauthenticated' do
      before { get url }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as regular user' do
      before { get url, headers: regular_headers }

      it 'returns success status with empty data (policy scope)' do
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_empty
      end
    end
  end

  describe 'POST /api/v1/page_blocks' do
    let(:url) { '/api/v1/page_blocks' }
    let(:payload) do
      {
        data: {
          type: 'page_blocks',
          attributes: { position: 0 },
          relationships: {
            page: { data: { type: 'pages', id: page.id } },
            block: { data: { type: 'blocks', id: block.id } }
          }
        }
      }.to_json
    end

    context 'when authenticated as platform manager' do
      before { post url, params: payload, headers: manager_headers.merge(jsonapi_headers) }

      it 'returns created status' do
        expect(response).to have_http_status(:created)
      end

      it 'creates the page_block association' do
        expect(page.blocks.reload).to include(block)
      end
    end

    context 'when unauthenticated' do
      before { post url, params: payload, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as regular user' do
      before { post url, params: payload, headers: regular_headers.merge(jsonapi_headers) }

      it 'returns forbidden or not found status' do
        expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/page_blocks/:id' do
    let(:page_block) { create(:page_content_block, page: page, block: block, position: 0) }
    let(:url) { "/api/v1/page_blocks/#{page_block.id}" }
    let(:payload) do
      {
        data: {
          type: 'page_blocks',
          id: page_block.id,
          attributes: { position: 5 }
        }
      }.to_json
    end

    context 'when authenticated as platform manager' do
      before { patch url, params: payload, headers: manager_headers.merge(jsonapi_headers) }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the position' do
        expect(page_block.reload.position).to eq(5)
      end
    end

    context 'when unauthenticated' do
      before { patch url, params: payload, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as regular user' do
      before { patch url, params: payload, headers: regular_headers.merge(jsonapi_headers) }

      it 'returns forbidden or not found status' do
        expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/page_blocks/:id' do
    let(:page_block) { create(:page_content_block, page: page, block: block) }
    let(:url) { "/api/v1/page_blocks/#{page_block.id}" }

    context 'when authenticated as platform manager' do
      before { delete url, headers: manager_headers }

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'removes the association but preserves the block' do
        expect(BetterTogether::Content::PageBlock.find_by(id: page_block.id)).to be_nil
        expect(BetterTogether::Content::Block.find_by(id: block.id)).not_to be_nil
      end
    end

    context 'when unauthenticated' do
      before { delete url }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as regular user' do
      before { delete url, headers: regular_headers }

      it 'returns forbidden or not found status' do
        expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
      end
    end
  end
end
