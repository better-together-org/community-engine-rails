# frozen_string_literal: true

module Noticed
  FactoryBot.define do
    factory :noticed_event, class: 'Noticed::Event' do
      type { 'BetterTogether::NewMessageNotifier' }
      params { {} }
    end
  end
end
