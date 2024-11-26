# frozen_string_literal: true

module BetterTogether
  class ApplicationBot
    attr_reader :client, :model

    # Default model can be overridden
    def initialize(model: 'gpt-4o-mini-2024-07-18')
      # Fetch the OpenAI access token and raise a descriptive error if it’s not set
      access_token = ENV.fetch('OPENAI_ACCESS_TOKEN') do
        raise KeyError, "OpenAI access token is missing. Please set 'OPENAI_ACCESS_TOKEN' in your environment."
      end

      # Initialize the client with the fetched access token
      @client = OpenAI::Client.new(access_token:)

      # Set the model for the bot
      @model = model
    end
  end
end
