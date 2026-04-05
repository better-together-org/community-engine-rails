# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_governed_authors' do
  it 'renders both person and robot mentions truthfully' do
    person = create(:person, name: 'Person Author', identifier: 'person-author')
    robot = create(:robot, name: 'Release Bot', identifier: 'release-bot')

    view.define_singleton_method(:profile_image_tag) do |_entity, **_options|
      '<img alt="Person Author" />'.html_safe
    end

    allow(view).to receive(:current_person).and_return(nil)
    allow(view).to receive(:policy).with(person).and_return(double(show?: true))
    allow(view).to receive(:person_path).with(person).and_return("/people/#{person.to_param}")

    render partial: 'better_together/shared/governed_authors',
           locals: { authors: [person, robot], flex_layout: 'flex-row', flex_align_items: 'center' }

    page = Capybara.string(rendered)

    expect(page).to have_link('Person Author', href: "/people/#{person.to_param}")
    expect(rendered).to include('Release Bot')
    expect(rendered).to include('mention_robot')
    expect(rendered).to include('Robot')
  end
end
