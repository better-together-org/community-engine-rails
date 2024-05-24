require 'rails_helper'

RSpec.describe 'geography/settlements/index', type: :view do
  before(:each) do
    assign(:geography_settlements, build_list(:settlement, 3))
  end

  it 'renders a list of geography/settlements' do
    # render
    # cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
