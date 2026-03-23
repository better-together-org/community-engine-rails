# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Real Elasticsearch search matching', type: :integration do
  let(:backend_url) { ENV.fetch('ELASTICSEARCH_URL', 'http://host.docker.internal:9200') }
  let(:backend_uri) { URI.parse(backend_url) }
  let(:page_index_name) { "better_together-pages-search-spec-#{SecureRandom.hex(6)}" }
  let(:post_index_name) { "better_together-posts-search-spec-#{SecureRandom.hex(6)}" }
  let(:markdown_token) { 'alpha-markdown-orbit-1001' }
  let(:rich_text_token) { 'beta-richtext-ember-1002' }
  let(:post_title_token) { 'gamma-posttitle-lantern-1003' }
  let(:post_content_token) { 'delta-postcontent-river-1004' }
  let(:shared_token) { 'shared-harbor-signal-1005' }

  let!(:markdown_page) do
    create(
      :better_together_page,
      title: 'Quiet Markdown Page',
      slug: 'quiet-markdown-page',
      privacy: 'public',
      page_blocks_attributes: [
        {
          block_attributes: {
            type: 'BetterTogether::Content::Markdown',
            markdown_source: <<~MD
              ## Hidden Signal

              #{markdown_token} appears only in this markdown block.
              #{shared_token} is shared with one post.
            MD
          }
        }
      ]
    )
  end

  let!(:rich_text_page) do
    create(
      :better_together_page,
      title: 'Quiet Rich Text Page',
      slug: 'quiet-rich-text-page',
      privacy: 'public',
      page_blocks_attributes: [
        {
          block_attributes: {
            type: 'BetterTogether::Content::RichText',
            content: "<p>#{rich_text_token} appears only in this rich text block.</p>"
          }
        }
      ]
    )
  end

  let!(:title_post) do
    create(
      :better_together_post,
      title: "Story #{post_title_token}",
      identifier: "story-#{post_title_token}",
      content: 'A post with a generic body.'
    )
  end

  let!(:content_post) do
    create(
      :better_together_post,
      title: 'Signal Post',
      identifier: 'signal-post',
      content: "This post body contains #{post_content_token} and #{shared_token}."
    )
  end

  around do |example|
    original_elasticsearch_url = ENV.fetch('ELASTICSEARCH_URL', nil)
    original_enable_tests = ENV.fetch('ENABLE_ELASTICSEARCH_TESTS', nil)
    original_page_index_name = BetterTogether::Page.__elasticsearch__.index_name
    original_post_index_name = BetterTogether::Post.__elasticsearch__.index_name

    ENV['ELASTICSEARCH_URL'] = backend_url
    ENV['ENABLE_ELASTICSEARCH_TESTS'] = 'true'
    BetterTogether::Page.__elasticsearch__.index_name = page_index_name
    BetterTogether::Post.__elasticsearch__.index_name = post_index_name
    WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_elasticsearch_request?)
    BetterTogether::Search.reset_backend!

    unless BetterTogether::Search.backend.available?
      skip "Elasticsearch is unavailable at #{backend_url}"
    end

    recreate_search_indices
    example.run
  ensure
    recreate_search_indices if BetterTogether::Search.backend.available?
    WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_elasticsearch_request?)
    ENV['ELASTICSEARCH_URL'] = original_elasticsearch_url
    ENV['ENABLE_ELASTICSEARCH_TESTS'] = original_enable_tests
    BetterTogether::Page.__elasticsearch__.index_name = original_page_index_name
    BetterTogether::Post.__elasticsearch__.index_name = original_post_index_name
    BetterTogether::Search.reset_backend!
  end

  before do
    reindex_registry!
  end

  def allowed_elasticsearch_request?
    lambda do |uri|
      allowed_hosts = [
        [backend_uri.host, backend_uri.port],
        ['elasticsearch', 9200],
        ['host.docker.internal', 9200]
      ]

      allowed_hosts.include?([uri.host, uri.port])
    end
  end

  it 'matches a page only by markdown block content' do
    results = search_records(markdown_token)

    expect(results).to contain_exactly(markdown_page)
  end

  it 'matches a page only by rich text block content' do
    results = search_records(rich_text_token)

    expect(results).to contain_exactly(rich_text_page)
  end

  it 'matches a post only by title content' do
    results = search_records(post_title_token)

    expect(results).to contain_exactly(title_post)
  end

  it 'matches a post only by body content' do
    results = search_records(post_content_token)

    expect(results).to contain_exactly(content_post)
  end

  it 'returns the expected mixed set for a shared token' do
    results = search_records(shared_token)

    expect(results).to contain_exactly(markdown_page, content_post)
  end

  it 'returns no records for a nonsense token' do
    expect(search_records('nonsense-token-zzzz-9999')).to be_empty
  end

  def search_records(query)
    BetterTogether::Search.backend.search(query).records
  end

  def reindex_registry!
    BetterTogether::Search::Registry.entries.each do |entry|
      BetterTogether::Search.backend.ensure_index(entry)
      BetterTogether::Search.backend.import_model(entry, force: true)
      BetterTogether::Search.backend.refresh_index(entry)
    end
  end

  def recreate_search_indices
    BetterTogether::Search::Registry.entries.each do |entry|
      BetterTogether::Search.backend.delete_index(entry)
      BetterTogether::Search.backend.ensure_index(entry)
      BetterTogether::Search.backend.refresh_index(entry)
    end
  end
end
