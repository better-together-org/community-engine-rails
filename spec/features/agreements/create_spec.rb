# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'managing agreements', :as_platform_manager do
  before do
    fill_in 'agreement[title_en]', with: 'Test Agreement'
    select 'Public', from: 'agreement[privacy]'
    click_button 'Create Agreement'
  end

  scenario 'agreement appears on index' do
    create(:agreement, title: 'Existing Agreement', slug: 'existing-agreement', privacy: 'public')

    visit agreements_path(locale: I18n.default_locale)
    expect(page).to have_content('Existing Agreement')
  end
end
