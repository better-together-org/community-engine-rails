require 'rails_helper'

RSpec.describe "geography/regions/index", type: :view do
  before(:each) do
    assign(:geography_regions, [
      Geography::Region.create!(),
      Geography::Region.create!()
    ])
  end

  it "renders a list of geography/regions" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
