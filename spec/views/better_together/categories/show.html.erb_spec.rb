require 'rails_helper'

RSpec.describe "categories/show", type: :view do
  before(:each) do
    assign(:category, Category.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
