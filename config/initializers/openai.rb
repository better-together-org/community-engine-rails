
if ENV["OPENAI_ACCESS_TOKEN"]
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN"),
    config.log_errors = Rails.env.development?
  end
end