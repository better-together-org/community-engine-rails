# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/uploads/index.html.erb' do
  it 'renders total storage usage' do
    view.define_singleton_method(:resource_class) { BetterTogether::Upload }
    allow(view).to receive(:total_upload_size).and_return('3 MB')
    assign(:uploads, [])

    render

    expect(rendered).to include('You&#39;re using 3 MB of storage')
  end
end
