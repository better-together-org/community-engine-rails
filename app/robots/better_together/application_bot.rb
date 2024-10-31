module BetterTogether
  class ApplicationBot
    attr_reader :client

    def initialize
      # Fetch the OpenAI access token and raise a descriptive error if it’s not set
      access_token = ENV.fetch('OPENAI_ACCESS_TOKEN') do
        raise KeyError, "OpenAI access token is missing. Please set 'OPENAI_ACCESS_TOKEN' in your environment."
      end

      # Initialize the client with the fetched access token
      @client = OpenAI::Client.new(access_token: access_token)
    end
  end
end
