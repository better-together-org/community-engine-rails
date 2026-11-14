# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/file_download_block_spec.rb'
RSpec.describe 'Documentation screenshots for the file download block', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', host_url: 'http://www.example.com') }
  end
  let(:upload) do
    create(:better_together_upload, privacy: 'public', platform: host_platform).tap do |record|
      record.file.attach(io: StringIO.new("%PDF-1.4 #{'x' * 150_000}"), filename: 'board-minutes-march.pdf',
                         content_type: 'application/pdf')
    end
  end
  let(:block) do
    create(:content_file_download_block, upload_id: upload.id, label_en: 'Board minutes, March',
                                         description_en: 'Approved at the March board meeting.')
  end
  let(:docs_page) do
    create(:better_together_page, title: 'Board documents', slug: 'board-documents', privacy: 'public',
                                  published_at: 1.day.ago, platform: host_platform, show_title: true).tap do |record|
      record.page_blocks.create!(block:, position: 0)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    docs_page
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'visitor', feature_set: 'file_download_block', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_block
    visit better_together.render_page_path(path: 'board-documents', locale:)
    expect(page).to have_css('.file-download-block')
    page.execute_script("document.querySelector('.file-download-block').scrollIntoView({block: 'center'})")
  end

  it 'captures the annotated block' do
    bullets = ['The link text is the block label, else the file name.',
               'Type and size come from the upload.']
    BetterTogether::CapybaraScreenshotEngine.capture(
      'file_download_block', device: :both, metadata: metadata('annotated'),
                             callouts: [{ id: 'card', selector: '.file-download-block', title: 'Download card',
                                          bullets: }],
                             narrative: { title: 'File download block', audience: %w[visitor editor],
                                          journey_step: 'As a visitor, I download a document from a page.',
                                          callouts: [{ id: 'card', title: 'Download card',
                                                       description: bullets.join(' ') }],
                                          accessibility_notes: 'The title is a real link; the icon is hidden from AT.' }
    ) { visit_block }
    expect(page).to have_css('.file-download-block')
  end

  it 'captures the plain block' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'file_download_block_plain', device: :both, metadata: metadata('plain')
    ) { visit_block }
    expect(page).to have_css('.file-download-block')
  end
end
