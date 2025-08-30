# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/resource_toolbar' do
  # rubocop:todo RSpec/MultipleExpectations
  it 'renders provided action buttons' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    render partial: 'shared/resource_toolbar', locals: {
      edit_path: '/edit',
      view_path: '/view',
      destroy_path: '/destroy',
      destroy_confirm: 'Are you sure?'
    }

    expect(rendered).to include(t('globals.edit'))
    expect(rendered).to include(t('globals.view'))
    expect(rendered).to include(t('globals.delete'))
    expect(rendered).to include('href="/edit"')
    expect(rendered).to include('href="/view"')
    expect(rendered).to include('href="/destroy"')
  end

  it 'omits buttons when paths are missing' do # rubocop:todo RSpec/MultipleExpectations
    render partial: 'shared/resource_toolbar'

    expect(rendered).not_to include(t('globals.edit'))
    expect(rendered).not_to include(t('globals.view'))
    expect(rendered).not_to include(t('globals.delete'))
  end

  it 'renders additional content from block in extra section' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    render inline: <<~ERB
      <%= render 'shared/resource_toolbar' do %>
        Custom Action
      <% end %>
    ERB
    expect(rendered).to include('Custom Action')
    expect(rendered).to include('resource-toolbar-extra')
  end
end
