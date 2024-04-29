require 'rails_helper'

RSpec.describe "people/show", type: :view do
  before(:each) do
    assign(:person, Person.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
