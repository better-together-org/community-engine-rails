# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Blocks', :no_auth do
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:manager_token) { api_sign_in_and_get_token(manager_user) }
  let(:manager_headers) { api_auth_headers(manager_user, token: manager_token) }

  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_token) { api_sign_in_and_get_token(regular_user) }
  let(:regular_headers) { api_auth_headers(regular_user, token: regular_token) }

  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/blocks' do
    let(:url) { '/api/v1/blocks' }
    let!(:block) { create(:content_markdown, :simple, privacy: 'public') }

    context 'when authenticated as platform manager' do
      before { get url, headers: manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'includes the block' do
        json = JSON.parse(response.body)
        block_ids = json['data'].map { |b| b['id'] }
        expect(block_ids).to include(block.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/blocks/:id' do
    let(:block) { create(:content_markdown, :simple, privacy: 'public') }
    let(:url) { "/api/v1/blocks/#{block.id}" }

    context 'when authenticated as platform manager' do
      before { get url, headers: manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the block type as block_type attribute' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['block_type']).to eq('BetterTogether::Content::Markdown')
      end

      it 'includes locale-suffixed attributes' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']).to have_key('markdown_source_en')
      end
    end
  end

  describe 'POST /api/v1/blocks' do
    let(:url) { '/api/v1/blocks' }

    let(:payload) do
      {
        data: {
          type: 'blocks',
          attributes: {
            block_type: 'BetterTogether::Content::Markdown',
            privacy: 'public',
            markdown_source_en: '# Hello\n\nWelcome to the page.'
          }
        }
      }.to_json
    end

    context 'when authenticated as platform manager' do
      before { post url, params: payload, headers: manager_headers.merge(jsonapi_headers) }

      it 'returns created status' do
        expect(response).to have_http_status(:created)
      end

      it 'creates a Markdown block' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['block_type']).to eq('BetterTogether::Content::Markdown')
      end
    end

    context 'when authenticated as regular user' do
      before { post url, params: payload, headers: regular_headers.merge(jsonapi_headers) }

      it 'returns not found (Pundit 404-gate)' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/blocks/:id' do
    let(:block) { create(:content_markdown, :simple, privacy: 'public') }
    let(:url) { "/api/v1/blocks/#{block.id}" }

    let(:payload) do
      {
        data: {
          type: 'blocks',
          id: block.id,
          attributes: {
            privacy: 'public',
            markdown_source_en: '# Updated content'
          }
        }
      }.to_json
    end

    context 'when authenticated as platform manager' do
      before { patch url, params: payload, headers: manager_headers.merge(jsonapi_headers) }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as regular user' do
      before { patch url, params: payload, headers: regular_headers.merge(jsonapi_headers) }

      it 'returns not found (Pundit 404-gate)' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/blocks/:id' do
    let(:block) { create(:content_markdown, :simple) }
    let(:url) { "/api/v1/blocks/#{block.id}" }

    context 'when authenticated as platform manager' do
      before { delete url, headers: manager_headers }

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'destroys the block' do
        expect(BetterTogether::Content::Block.find_by(id: block.id)).to be_nil
      end
    end
  end

  describe 'Content::Css / Content::Html truncation regression' do
    # Regression: before the type:text migration, content was stored in
    # mobility_string_translations (varchar 255), silently truncating any CSS
    # or HTML longer than 255 characters. This spec asserts round-trip fidelity.
    let(:long_css) { ".a { color: red; }\n" * 20 } # > 255 chars
    let(:long_html) { "<div class='x'>#{('hello ' * 50).strip}</div>" } # > 255 chars

    it 'persists and returns Content::Css body > 255 chars without truncation' do
      css_block = create(:better_together_content_css, content_text: long_css)
      get "/api/v1/blocks/#{css_block.id}", headers: manager_headers

      expect(response).to have_http_status(:ok)
      returned_content = JSON.parse(response.body).dig('data', 'attributes', 'content_en')
      expect(returned_content.length).to be > 255
      expect(returned_content).to eq(long_css)
    end

    it 'persists and returns Content::Html body > 255 chars without truncation' do
      html_block = create(:content_html, content: long_html)
      get "/api/v1/blocks/#{html_block.id}", headers: manager_headers

      expect(response).to have_http_status(:ok)
      returned_content = JSON.parse(response.body).dig('data', 'attributes', 'content_en')
      expect(returned_content.length).to be > 255
      expect(returned_content).to eq(long_html)
    end
  end
end
