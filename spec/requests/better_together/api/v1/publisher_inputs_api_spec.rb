# frozen_string_literal: true

require 'rails_helper'

# Inputs a publisher script needs: base64 images, attribution links, categories by identifier, namespaced page slugs,
# original dates on backfilled posts, and a fixed API locale.
RSpec.describe 'BetterTogether::Api::V1 publisher inputs', :no_auth do
  let(:user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:headers) do
    api_auth_headers(user, token: token).merge('Content-Type' => 'application/vnd.api+json',
                                               'Accept' => 'application/vnd.api+json')
  end
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end
  let(:png) do
    Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
  let(:data) { Base64.strict_encode64(png) }

  before { grant_content_publishing_agreement(user.person) }

  def jsonapi_update(type, id, attributes)
    { data: { type:, id:, attributes: } }.to_json
  end

  def jsonapi(type, attributes)
    { data: { type:, attributes: } }.to_json
  end

  describe 'blocks' do
    it 'creates an image block from base64 data with an attribution link', :aggregate_failures do
      attributes = { block_type: 'Image', identifier: 'api-photo', privacy: 'public', media_data: data,
                     media_filename: 'ship.png', caption: 'EXPLORA III', alt_text_en: 'A ship',
                     attribution_en: 'Photo: A. Photographer, CC BY 4.0',
                     attribution_url_en: 'https://commons.wikimedia.org/wiki/File:Ship.jpg' }
      post '/api/v1/blocks', params: jsonapi('blocks', attributes), headers: headers

      expect(response).to have_http_status(:created), response.body
      block = BetterTogether::Content::Image.find_by(identifier: 'api-photo')
      expect(block.media).to be_attached
      expect(block.attribution_url).to eq('https://commons.wikimedia.org/wiki/File:Ship.jpg')
      expect(JSON.parse(response.body)['data']['attributes']).not_to have_key('media_data')
    end

    it 'creates a hero block with a base64 background', :aggregate_failures do
      attributes = { block_type: 'Hero', identifier: 'api-hero', privacy: 'public', heading_en: 'EXPLORA III',
                     background_image_data: data, background_image_filename: 'hero.png' }
      post '/api/v1/blocks', params: jsonapi('blocks', attributes), headers: headers

      expect(response).to have_http_status(:created), response.body
      expect(BetterTogether::Content::Hero.find_by(identifier: 'api-hero').background_image_file).to be_attached
    end

    it 'rejects image data on a block type that has no image', :aggregate_failures do
      attributes = { block_type: 'Markdown', identifier: 'api-md', privacy: 'public', media_data: data }
      post '/api/v1/blocks', params: jsonapi('blocks', attributes), headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(BetterTogether::Content::Markdown.find_by(identifier: 'api-md')).to be_nil
    end
  end

  describe 'pages' do
    let!(:category) { create(:category, identifier: 'ships') }

    it 'keeps a namespaced slug and files the page under a category', :aggregate_failures do
      attributes = { title: 'EXPLORA III', slug: 'ships/mt-explora-iii', privacy: 'public',
                     category_identifiers: ['ships'], published_at: 1.day.ago.iso8601 }
      post '/api/v1/pages', params: jsonapi('pages', attributes), headers: headers

      expect(response).to have_http_status(:created), response.body
      page = BetterTogether::Page.friendly.find('ships/mt-explora-iii')
      expect(page.categories).to contain_exactly(category)
      expect(JSON.parse(response.body)['data']['attributes']['category_identifiers']).to eq(['ships'])
    end

    it 'rejects an unknown category identifier' do
      attributes = { title: 'EXPLORA III', slug: 'ships/x', privacy: 'public', category_identifiers: ['nope'] }
      post '/api/v1/pages', params: jsonapi('pages', attributes), headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'posts' do
    let!(:category) { create(:category, identifier: 'ships') }
    let(:original) { Time.zone.parse('2026-09-30 06:30') }

    it 'keeps the original dates and categories of a backfilled post', :aggregate_failures do
      attributes = { title: 'Harbour, September 29', content: '<p>Vessels</p>', privacy: 'public',
                     category_identifiers: ['ships'], created_at: original.iso8601, updated_at: original.iso8601 }
      post '/api/v1/posts', params: jsonapi('posts', attributes), headers: headers

      expect(response).to have_http_status(:created), response.body
      record = BetterTogether::Post.order(:created_at).last
      expect(record.created_at).to be_within(1.second).of(original)
      expect(record.updated_at).to be_within(1.second).of(original)
      expect(record.categories).to contain_exactly(category)
    end

    it 'sets updated_at back on an update', :aggregate_failures do
      record = create(:better_together_post, privacy: 'public', creator: user.person)
      patch "/api/v1/posts/#{record.id}",
            params: jsonapi_update('posts', record.id, title: 'Renamed', updated_at: original.iso8601), headers: headers

      expect(response).to have_http_status(:ok), response.body
      expect(record.reload.updated_at).to be_within(1.second).of(original)
    end

    it 'keeps attached image blocks when the body is rewritten', :aggregate_failures do
      BetterTogether::Content::Image.include(ActionText::Attachable)
      BetterTogether::Content::Image.include(Module.new { def to_attachable_partial_path = 'better_together/test_support/attachable' })
      BetterTogether::ContentSecurity::AttachableRegistry.register('BetterTogether::Content::Image')
      block = BetterTogether::Content::Image.create!(platform: BetterTogether::Platform.find_by(host: true), privacy: 'public',
                                                     identifier: 'pi-img', creator: user.person, caption: 'Harbour',
                                                     media_data: data, media_filename: 'h.png')
      post '/api/v1/posts', params: jsonapi('posts', title: 'Arrived', content: '<p>Arrived</p>', privacy: 'public',
                                                     attachment_block_ids: [block.id]), headers: headers
      expect(response).to have_http_status(:created), response.body
      id = JSON.parse(response.body).dig('data', 'id')
      patch "/api/v1/posts/#{id}", params: jsonapi_update('posts', id, content: '<p>Departed</p>'), headers: headers

      expect(response).to have_http_status(:ok), response.body
      body = BetterTogether::Post.find(id).content.body
      expect(body.attachables.map(&:id)).to eq([block.id])
      expect(body.to_html).to include('Departed')
      expect(body.to_html).not_to include('Arrived')
      expect(JSON.parse(response.body).dig('data', 'attributes')).not_to have_key('attachment_block_ids')
    ensure
      BetterTogether::ContentSecurity::AttachableRegistry.reset!
    end

    it 'never rewrites created_at after creation', :aggregate_failures do
      record = create(:better_together_post, privacy: 'public', creator: user.person)
      created = record.created_at
      patch "/api/v1/posts/#{record.id}",
            params: jsonapi_update('posts', record.id, created_at: 1.year.ago.iso8601), headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(record.reload.created_at).to be_within(1.second).of(created)
    end
  end

  describe 'locale' do
    it 'stores API content under the default locale even when the thread locale was leaked', :aggregate_failures do
      I18n.locale = :es
      attributes = { title: 'Locale test', slug: 'locale-test', privacy: 'public' }
      post '/api/v1/pages', params: jsonapi('pages', attributes), headers: headers

      expect(response).to have_http_status(:created), response.body
      expect(BetterTogether::Page.find_by(identifier: 'locale-test').title(locale: I18n.default_locale)).to eq('Locale test')
    ensure
      I18n.locale = I18n.default_locale
    end
  end
end
