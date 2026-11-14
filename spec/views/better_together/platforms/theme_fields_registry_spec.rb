# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/platforms/_theme_fields' do # rubocop:disable RSpec/DescribeClass
  let(:platform) { create(:better_together_platform) }
  let(:tokens) { BetterTogether::PlatformThemeConfig.builtin_themes['neutral'].merge('primary' => '#0b3d2e') }

  before do
    allow(view).to receive(:current_person).and_return(nil)
    view.extend(BetterTogether::Content::BlocksHelper)
  end

  after { BetterTogether::PlatformThemeConfig.reset_registered_themes! }

  it 'lists host-registered themes beside the built-in ones' do
    BetterTogether::PlatformThemeConfig.register_theme('acme_forest', tokens, name: 'Acme forest')

    render partial: 'better_together/platforms/theme_fields', locals: { platform:, form: ActionView::Helpers::FormBuilder.new(:platform, platform, view, {}) }

    expect(rendered).to include('Acme forest').and include('Neutral light')
  end
end
