# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::PageView do
  let(:viewed_at) { Time.zone.now }
  let(:locale) { 'en' }

  around do |example|
    previous_platform = Current.platform
    Current.reset
    example.run
    Current.platform = previous_platform
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'normalizes page_url to exclude query strings' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    page_view = described_class.new(
      page_url: 'http://127.0.0.1:3000/path?foo=bar',
      viewed_at: viewed_at,
      locale: locale
    )

    expect(page_view).to be_valid
    expect(page_view.page_url).to eq('/path')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'rejects URLs containing sensitive parameters' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    page_view = described_class.new(
      page_url: 'http://127.0.0.1:3000/path?token=abc',
      viewed_at: viewed_at,
      locale: locale
    )

    expect(page_view).not_to be_valid
    expect(page_view.errors[:page_url]).to include('contains sensitive parameters')
  end

  it 'assigns platform from explicit internal current platform context' do
    platform = create(:better_together_platform)
    Current.platform = platform

    page_view = described_class.create!(
      page_url: 'http://127.0.0.1:3000/path',
      viewed_at: viewed_at,
      locale: locale,
      logged_in: false
    )

    expect(page_view.platform).to eq(platform)
  end

  it 'does not borrow platform from external current platform context' do
    Current.platform = create(:better_together_platform, external: true)

    page_view = described_class.new(
      page_url: 'http://127.0.0.1:3000/path',
      viewed_at: viewed_at,
      locale: locale,
      logged_in: false
    )

    page_view.valid?

    expect(page_view.platform).to be_nil
  end
end
