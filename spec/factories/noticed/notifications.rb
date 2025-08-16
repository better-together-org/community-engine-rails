# frozen_string_literal: true

module Noticed
  FactoryBot.define do
    factory :noticed_notification, class: 'Noticed::Notification', aliases: %i[notification] do
      type { 'BetterTogether::NewMessageNotifier' }
      event { association :noticed_event, type: type }
      recipient { association(:better_together_person) }
    end
  end
end
