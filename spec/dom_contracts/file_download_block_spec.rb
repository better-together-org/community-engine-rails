# frozen_string_literal: true

require 'rails_helper'

# Stable hooks that the file download block screenshots and styles rely on.
RSpec.describe 'File download block DOM contract', type: :request do
  let(:upload) do
    create(:better_together_upload, privacy: 'public').tap do |record|
      record.file.attach(io: StringIO.new('x' * 2048), filename: 'minutes.pdf', content_type: 'application/pdf')
    end
  end
  let(:page_record) do
    create(:better_together_page, privacy: 'public', published_at: 1.day.ago).tap do |record|
      block = create(:content_file_download_block, upload_id: upload.id, label_en: 'Board minutes',
                                                   description_en: 'Approved at the March meeting.')
      record.page_blocks.create!(block:, position: 0)
    end
  end

  before { configure_host_platform }

  it 'exposes a card with title link, meta line and description', :aggregate_failures do
    get better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale)

    page = Capybara.string(response.body)
    expect(page).to have_css('.file-download-block .file-download-block__title a', text: 'Board minutes')
    expect(page).to have_css('.file-download-block__meta', text: 'PDF, 2 KB')
    expect(page).to have_css('.file-download-block__description', text: 'Approved at the March meeting.')
  end
end
