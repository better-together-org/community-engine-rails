FactoryBot.define do
  factory :group, class: 'TheSeed::Group' do
    name { "MyString" }
    description { "MyText" }
  end
end
