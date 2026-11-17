# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/application.css' do # rubocop:disable RSpec/DescribeClass
  let(:css) { Rails.application.assets.find_asset('better_together/application.css').to_s }

  it 'resolves SCSS variables used in custom properties' do
    unresolved = css.scan(/--[a-z0-9-]+:\s*[^;}]*\$[a-z][a-z-]*[^;}]*/)

    expect(unresolved).to be_empty
  end

  it 'gives the navbar brand the light-background text colour' do
    expect(css).to match(/--bs-navbar-brand-color:\s*#222/)
  end
end
