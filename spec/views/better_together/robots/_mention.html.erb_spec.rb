# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/robots/_mention' do
  let(:robot) { build_stubbed(:robot, name: 'Release Bot', identifier: 'release-bot') }
  let(:avatar) do
    render partial: 'better_together/robots/mention', locals: { robot: }
    Capybara.string(rendered).find('.robot-avatar')
  end

  it 'shows the robot name and kind' do
    render partial: 'better_together/robots/mention', locals: { robot: }

    expect(rendered).to include('Release Bot', 'Robot')
  end

  it 'keeps the avatar a fixed circle instead of letting a flex row or h-50 squash it', :aggregate_failures do
    expect(avatar[:class].split).to include('rounded-circle', 'flex-shrink-0')
    expect(avatar[:class].split).not_to include('h-50')
    expect(avatar[:style]).to include('width: 50px', 'height: 50px')
  end

  it 'leaves a gap between the avatar and the name' do
    expect(avatar[:class].split).to include('me-2')
  end

  it 'labels the avatar for assistive technology' do
    expect(avatar).to have_css('.visually-hidden', text: 'Robot author')
  end
end
