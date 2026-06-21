# frozen_string_literal: true

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil) || ENV.fetch('OPENAI_ACCESS_TOKEN', nil)
  config.openai_api_base = ENV['OPENAI_API_BASE'] if ENV['OPENAI_API_BASE'].present?
  config.openai_organization_id = ENV['OPENAI_ORG_ID'] if ENV['OPENAI_ORG_ID'].present?
  config.openai_project_id = ENV['OPENAI_PROJECT_ID'] if ENV['OPENAI_PROJECT_ID'].present?
  config.openai_use_system_role = true if ENV['OPENAI_USE_SYSTEM_ROLE'] == 'true'

  config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1')
  config.ollama_api_key = ENV['OLLAMA_API_KEY'] if ENV['OLLAMA_API_KEY'].present?

  config.default_model = ENV.fetch('BETTER_TOGETHER_LLM_MODEL', 'gpt-4o-mini-2024-07-18')
  config.default_embedding_model = ENV.fetch('BETTER_TOGETHER_EMBEDDING_MODEL', 'text-embedding-3-small')
  config.request_timeout = Integer(ENV.fetch('BETTER_TOGETHER_LLM_TIMEOUT', 120))
  config.max_retries = Integer(ENV.fetch('BETTER_TOGETHER_LLM_MAX_RETRIES', 2))
  config.logger = Rails.logger
end
