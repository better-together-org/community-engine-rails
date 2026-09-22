# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/robot',
          class: 'BetterTogether::Robot',
          aliases: %i[better_together_robot robot] do
    association :platform, factory: 'better_together/platform'
    name { 'Translation Robot' }
    sequence(:identifier) { |n| "translation_#{n}" }
    robot_type { 'translation' }
    provider { 'openai' }
    default_model { 'gpt-4o-mini-2024-07-18' }
    default_embedding_model { 'text-embedding-3-small' }
    system_prompt do
      'You are a translation assistant for CMS content. Only return translated text.'
    end
    settings { {} }
    active { true }

    trait :global do
      platform { nil }
    end

    trait :ollama do
      provider { 'ollama' }
      default_model { 'llama3.2' }
      default_embedding_model { 'nomic-embed-text' }
      settings { { assume_model_exists: true } }
    end
  end
end
