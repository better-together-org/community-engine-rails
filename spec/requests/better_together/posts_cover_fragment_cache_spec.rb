# frozen_string_literal: true

require 'rails_helper'

# A ship post without a cover of its own shows its category's cover. The cached cover fragment must hold a stable
# same-origin proxy URL (never a signed, expiring service URL) and follow the category's image when it changes.
RSpec.describe 'Post cover fragment cache', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:category) { create(:category) }
  let(:post_record) do
    create(:better_together_post, :published, author: platform_manager.person, creator: platform_manager.person,
                                              community: host_platform.community, platform: host_platform,
                                              privacy: 'public')
  end
  let(:svg) { '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' }

  def with_fragment_caching
    caching = ActionController::Base.perform_caching
    store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    ActionController::Base.perform_caching = caching
    ActionController::Base.cache_store = store
  end

  def hero_src
    Nokogiri::HTML(response.body).at_css('.post-hero img')['src']
  end

  it 'shows the replaced category cover after the first render was cached' do
    host_platform.community.update!(privacy: 'public')
    post_record.categories << category
    category.cover_image.attach(io: StringIO.new(svg), filename: 'one.svg', content_type: 'image/svg+xml')

    with_fragment_caching do
      get better_together.post_path(post_record, locale:)
      first_src = hero_src

      travel_to(1.minute.from_now) do
        category.cover_image.attach(io: StringIO.new(svg), filename: 'two.svg', content_type: 'image/svg+xml')
        get better_together.post_path(post_record.reload, locale:)
      end

      expect(first_src).to include('/rails/active_storage/blobs/proxy/')
      expect(first_src).not_to match(%r{X-Amz|expires_in|/disk/})
      expect(hero_src).to include('two.svg')
      expect(hero_src).not_to eq(first_src)
    end
  end
end
