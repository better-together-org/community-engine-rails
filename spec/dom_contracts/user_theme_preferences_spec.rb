# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the appearance preferences in a person's settings and the platform toggle.
RSpec.describe 'User theme preferences DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  describe 'as a person', :as_user do
    it 'renders the appearance section with stable ids in the preferences tab' do
      get settings_path(locale: I18n.default_locale)
      doc = Nokogiri::HTML(response.body)

      %w[person-appearance-preferences person_theme person_color_mode user-theme-preview user-theme-preview-state
         user-theme-preview-navbar user-theme-preview-body user-theme-preview-card user-theme-preview-footer
         user-theme-contrast-note].each do |id|
        expect(doc.at_css("#preferences ##{id}")).to be_present, "missing ##{id}"
      end
      expect(doc.at_css('#person-appearance-preferences')['data-controller']).to eq('better_together--user-theme-preview')
    end

    it 'wires the live preview to the select changes and saves' do
      get settings_path(locale: I18n.default_locale)
      action = Nokogiri::HTML(response.body).at_css('#person-appearance-preferences')['data-action']

      expect(action).to include('change->better_together--user-theme-preview#update',
                                'preference:saved->better_together--user-theme-preview#saved')
    end

    it 'gives the colour mode toggle a save url for signed-in people' do
      get settings_path(locale: I18n.default_locale)

      expect(Nokogiri::HTML(response.body).at_css('#color-mode-toggle')['data-better_together--color-mode-save-url-value']).to be_present
    end
  end

  describe 'platform allow_user_themes toggle', :as_platform_manager do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

    it 'renders the toggle inside the Appearance pane and saves it' do # rubocop:disable RSpec/MultipleExpectations
      get better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)
      field_id = ActionView::RecordIdentifier.dom_id(host_platform, :allow_user_themes)
      box = Nokogiri::HTML(response.body).at_css("#platform-appearance #platform-allow-user-themes input[type=checkbox]##{field_id}")
      expect(box).to be_present
      expect(box['name']).to eq('platform[allow_user_themes]')

      patch better_together.platform_path(locale: I18n.default_locale, id: host_platform.slug), params: { platform: { allow_user_themes: '0' } }
      expect(host_platform.reload.allow_user_themes).to be(false)
    end
  end
end
