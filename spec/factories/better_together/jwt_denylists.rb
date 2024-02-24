# frozen_string_literal: true

FactoryBot.define do
  factory :jwt_denylist do
    jti { 'MyString' }
    exp { '2021-01-03 20:16:42' }
  end
end
