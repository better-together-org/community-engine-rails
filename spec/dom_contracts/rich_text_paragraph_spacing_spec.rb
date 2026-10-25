# frozen_string_literal: true

require 'rails_helper'

# DOM contract for rich text paragraph spacing: the identifiers the docs screenshots
# (spec/docs_screenshots/better_together/rich_text_paragraph_spacing_spec.rb) target.
RSpec.describe 'Rich text paragraph spacing DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let!(:post_record) do
    create(:better_together_post, platform: host_platform, privacy: 'public', published_at: 1.day.ago,
                                  content: '<p>First paragraph.</p><p>Second paragraph.</p>')
  end

  before { configure_host_platform }

  it 'renders written paragraphs as direct children of the trix-content wrapper' do
    get better_together.post_path(post_record, locale:)
    paragraphs = Nokogiri::HTML(response.body).css('.post-content .trix-content > p')
    expect(paragraphs.size).to eq(2)
  end

  it 'styles direct paragraphs like the blocks the editor writes' do
    css = Rails.root.join('../../app/assets/stylesheets/better_together/trix-extensions/richtext.scss').read
    expect(css).to match(/>\s*div,\s*>\s*p\s*\{/)
  end
end
