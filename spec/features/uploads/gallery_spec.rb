# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'uploads gallery', type: :feature, js: true do # rubocop:disable Metrics/BlockLength
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
    @creator = BetterTogether::User.find_by(email: 'manager@example.test').person
  end

  def create_upload(name, creator:, created_at: Time.current)
    create(:better_together_upload, name:, creator:, created_at:).tap do |upload|
      upload.file.attach(io: StringIO.new('stub'), filename: "#{name}.txt", content_type: 'text/plain')
    end
  end

  scenario 'searches, sorts, and copies upload urls' do
    create_upload('Alpha', creator: @creator, created_at: 2.days.ago)
    create_upload('Beta', creator: @creator, created_at: 1.day.ago)

    visit file_index_path(locale: I18n.default_locale)

    expect(page.all('[data-better_together--uploads-target="item"] .card-title').map(&:text))
      .to eq(%w[Beta Alpha])

    fill_in placeholder: 'Search uploads', with: 'Al'
    expect(page).to have_selector('[data-name="Alpha"]', visible: true)
    expect(page).to have_selector('[data-name="Beta"].d-none', visible: :all)

    find('select[data-better_together--uploads-target="sort"]').select('Name')
    expect(page.all('[data-better_together--uploads-target="item"] .card-title').map(&:text))
      .to eq(%w[Alpha Beta])

    copy_button = find('button', text: 'Copy URL', match: :first)
    page.execute_script <<~JS
      window.copiedText = null;
      Object.defineProperty(navigator, "clipboard", {
        value: { writeText: function(t){ window.copiedText = t } }
      });
    JS
    copy_button.click
    expect(page.evaluate_script('window.copiedText')).to eq(copy_button['data-url'])
  end
end
