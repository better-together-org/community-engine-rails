# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the theme <style> elements in <head>. The live theme swap and Turbo navigation rely on the ids,
# the dynamic Turbo tracking and the marker on the platform Css block, which must stay last.
RSpec.describe 'Theme style tags DOM contract', :as_user, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:cfg) { BetterTogether::PlatformThemeConfig }

  before do
    host_platform.update!(allow_user_themes: true, theme: cfg.flat_theme('neutral').merge('preset' => 'neutral'),
                          css_block_attributes: { content: 'body { letter-spacing: 0; }' })
    BetterTogether::User.find_by(email: 'user@example.test').person.update!(theme: 'warm')
    login('user@example.test', 'SecureTest123!@#')
  end

  it 'renders the platform theme, the personal theme and the Css block in cascade order' do # rubocop:disable RSpec/MultipleExpectations
    get settings_path(locale: I18n.default_locale)
    styles = Nokogiri::HTML(response.body).css('head style').to_a
    platform, personal = %w[platform-theme-style user-theme-style].map { |id| styles.find { |s| s['id'] == id } }
    block = styles.find { |s| s['data-bts-css-block'] }

    expect([platform, personal, block]).to all(be_present)
    expect([platform, personal].map { |s| s['data-turbo-track'] }).to eq(%w[dynamic dynamic])
    expect(styles.index(platform)).to be < styles.index(personal)
    expect(styles.index(personal)).to be < styles.index(block)
  end
end
