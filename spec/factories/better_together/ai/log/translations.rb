# frozen_string_literal: true

FactoryBot.define do
  factory :ai_log_translation, class: 'BetterTogether::Ai::Log::Translation' do
    request { 'Translate the following text from en to fr: Hello' }
    response { 'Bonjour' }
    model { 'gpt-4o-mini-2024-07-18' }
    prompt_tokens { 5 }
    completion_tokens { 2 }
    tokens_used { 7 }
    status { 'success' }
    source_locale { 'en' }
    target_locale { 'fr' }
    association :initiator, factory: :better_together_person
  end
end
