# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the post community chip: the identifiers the docs screenshots
# (spec/docs_screenshots/better_together/post_community_chip_spec.rb) target.
RSpec.describe 'Post community chip DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include ActionView::RecordIdentifier

  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let!(:community) { create(:better_together_community, privacy: 'public', name: 'Contract Community') }
  let!(:post_record) do
    create(:better_together_post, community:, platform: host_platform, privacy: 'public', published_at: 1.day.ago)
  end

  before { configure_host_platform }

  it 'puts the chip inside the post card and the show page community wrapper' do
    get better_together.posts_path(locale:)
    index = Nokogiri::HTML(response.body)
    expect(index.css("##{dom_id(post_record)} .community-chip")).not_to be_empty

    get better_together.post_path(post_record, locale:)
    show = Nokogiri::HTML(response.body)
    expect(show.css("##{dom_id(post_record, :community)} .community-chip")).not_to be_empty
  end
end
