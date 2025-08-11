# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/uploads/index.html.erb', type: :view do
  it 'renders total storage usage' do
    allow(view).to receive(:resource_class).and_return(BetterTogether::Upload)
    assign(:uploads, [])
    assign(:total_size, 3.megabytes)

    render

    expect(rendered).to include("You're using 3 MB of storage")
  end
end
