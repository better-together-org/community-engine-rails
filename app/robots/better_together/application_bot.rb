# frozen_string_literal: true

module BetterTogether
  class ApplicationBot # rubocop:todo Style/Documentation
    attr_reader :model, :provider, :robot

    def initialize(robot: nil, identifier: nil, platform: Current.platform, model: nil, provider: nil)
      @robot = robot || resolve_robot(identifier:, platform:)
      @model = model.presence || default_model
      @provider = provider.presence || default_provider
    end

    private

    def default_robot_identifier
      nil
    end

    def ask(prompt, system_prompt:, temperature: nil, max_tokens: nil)
      BetterTogether.llm_chat(
        prompt:,
        system_prompt:,
        model:,
        provider:,
        adapter_name: provider,
        temperature:,
        max_tokens:,
        assume_model_exists: assume_model_exists?,
        metadata: robot_metadata
      )
    end

    def embed(text, model: nil, dimensions: nil)
      BetterTogether.embed_text(
        text,
        model: model.presence || robot&.embedding_model,
        provider:,
        adapter_name: provider,
        dimensions:,
        assume_model_exists: assume_model_exists?,
        metadata: robot_metadata
      )
    end

    def resolve_robot(identifier:, platform:)
      robot_identifier = identifier.presence || default_robot_identifier
      return if robot_identifier.blank?

      BetterTogether::Robot.resolve(identifier: robot_identifier, platform:)
    end

    def default_model
      @robot&.chat_model || ENV.fetch('BETTER_TOGETHER_LLM_MODEL', 'gpt-4o-mini-2024-07-18')
    end

    def default_provider
      @robot&.llm_provider || ENV.fetch('BETTER_TOGETHER_LLM_PROVIDER', 'openai')
    end

    def assume_model_exists?
      robot&.settings_hash&.fetch(:assume_model_exists, false)
    end

    def robot_metadata
      {
        robot_id: robot&.id,
        robot_identifier: robot&.identifier,
        platform_id: robot&.platform_id
      }
    end
  end
end
