# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_governed_contributions' do
  it 'renders grouped contribution roles for people and robots' do
    post = create(:better_together_post)
    person = create(:better_together_person, name: 'Editor Person', identifier: 'editor-person')
    robot = create(:better_together_robot, name: 'Review Bot', identifier: 'review-bot')

    post.add_governed_contributor(person, role: 'editor')
    post.add_governed_contributor(robot, role: 'reviewer')

    view.define_singleton_method(:profile_image_tag) do |_entity, **_options|
      '<img alt="Editor Person" />'.html_safe
    end

    allow(view).to receive_messages(current_person: nil, policy: double(show?: true))
    allow(view).to receive(:person_path) { |arg| "/people/#{arg.to_param}" }

    render partial: 'better_together/shared/governed_contributions', locals: { record: post }

    page = Capybara.string(rendered)

    expect(rendered).to include('Editors')
    expect(rendered).to include('Reviewers')
    expect(page).to have_link('Editor Person', href: "/people/#{person.to_param}")
    expect(rendered).to include('Review Bot (@review-bot)')
  end
end
