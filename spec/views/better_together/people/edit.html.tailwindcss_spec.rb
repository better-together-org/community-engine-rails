require 'rails_helper'

RSpec.describe "people/edit", type: :view do
  let(:person) {
    Person.create!()
  }

  before(:each) do
    assign(:person, person)
  end

  it "renders the edit person form" do
    render

    assert_select "form[action=?][method=?]", person_path(person), "post" do
    end
  end
end
