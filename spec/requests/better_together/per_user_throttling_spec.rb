# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Per-user throttling', :as_user do
  let(:locale) { I18n.default_locale }
  let(:me) { BetterTogether::User.find_by!(email: 'user@example.test').person }
  let(:target) { create(:better_together_person) }
  let(:target_post) do
    create(:better_together_post, creator: target, author: target, privacy: 'public', published_at: 1.minute.ago)
  end

  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    ENV['BTS_THROTTLE_COMMENT_CREATE_LIMIT'] = '2'
    ENV['BTS_THROTTLE_COMMENT_CREATE_PERIOD'] = '60'
    example.run
  ensure
    Rack::Attack.cache.store = original_store
    ENV.delete('BTS_THROTTLE_COMMENT_CREATE_LIMIT')
    ENV.delete('BTS_THROTTLE_COMMENT_CREATE_PERIOD')
  end

  def post_comment
    post better_together.comments_path(locale:), params: {
      commentable_type: 'BetterTogether::Post', commentable_id: target_post.id, comment: { content: 'hi' }
    }
  end

  before { grant_content_publishing_agreement(me) }

  it 'allows requests up to the limit then answers 503 with Retry-After', :aggregate_failures do
    2.times { post_comment }
    expect(response).not_to have_http_status(:service_unavailable)

    post_comment

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers['Retry-After'].to_i).to be_between(1, 60)
  end

  it 'does not create the comment once throttled' do
    2.times { post_comment }

    expect { post_comment }.not_to change(BetterTogether::Comment, :count)
  end

  it 'counts each account separately' do
    2.times { post_comment }
    Rack::Attack.cache.count("per-user/comment_create/#{create(:better_together_person).id}", 60)

    expect(Rack::Attack.cache.count("per-user/comment_create/#{me.id}", 60)).to be > 2
  end

  it 'is disabled by a zero limit' do
    ENV['BTS_THROTTLE_COMMENT_CREATE_LIMIT'] = '0'
    4.times { post_comment }

    expect(response).not_to have_http_status(:service_unavailable)
  end

  describe BetterTogether::PerUserThrottling do
    it 'reads defaults and env overrides', :aggregate_failures do
      expect(described_class.settings_for(:message_send)).to eq(limit: 30, period: 60)
      expect(described_class.settings_for(:comment_create)).to eq(limit: 2, period: 60)
    end

    it 'rejects unknown throttle names' do
      expect { Class.new(ActionController::Base) { include BetterTogether::PerUserThrottling }.throttle_per_user(:nope) }
        .to raise_error(ArgumentError)
    end
  end
end
