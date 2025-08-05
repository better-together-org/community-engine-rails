# frozen_string_literal: true

module Noticed
  FactoryBot.define do
    factory :noticed_notification, class: 'Noticed::Notification', aliases: %i[notification] do
      type { 'BetterTogether::NewMessageNotifier' }
      recipient { association(:better_together_person) }
      params { {} }
    end
  end
end
