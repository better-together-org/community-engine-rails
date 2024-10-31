
module BetterTogether
  class ApplicationBot
    attr_reader :client

    def initialize
      @client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_ACCESS_TOKEN'))
    end
  end
end
