# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_governed_authors', type: :view do
  it 'renders both person and robot authors truthfully' do
    assign(:current_person, nil)
    view.define_singleton_method(:profile_image_tag) { |_person, **_opts| '<span>profile</span>'.html_safe }
    hidden_policy = Struct.new(:show?).new(false)
    view.define_singleton_method(:policy) { |_record| hidden_policy }

    person = create(:person, name: 'Ada Person')
    robot = create(:robot, name: 'Writer Robot', identifier: 'writer-bot')

    render partial: 'better_together/shared/governed_authors',
           locals: { authors: [person, robot], flex_layout: 'flex-row', flex_align_items: 'center' }

    expect(rendered).to include('Ada Person')
    expect(rendered).to include('Writer Robot')
    expect(rendered).to include('Robot')
  end
end
