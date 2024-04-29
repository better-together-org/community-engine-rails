require 'rails_helper'

RSpec.describe "people/new", type: :view do
  before(:each) do
    assign(:person, Person.new())
  end

  it "renders new person form" do
    render

    assert_select "form[action=?][method=?]", people_path, "post" do
    end
  end
end
