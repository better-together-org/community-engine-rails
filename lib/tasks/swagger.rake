# frozen_string_literal: true

namespace :swagger do # rubocop:todo Metrics/BlockLength
  desc 'Generate swagger documentation with environment-aware URLs'
  task generate: :environment do
    # Ensure we have the correct base URL for this environment
    base_url = BetterTogether.base_url

    puts "Generating Swagger documentation for environment: #{Rails.env}"
    puts "Base URL: #{base_url}"

    # Shell out to rspec directly with the correct flags to avoid --dry-run
    # Use only integration specs which have the rswag 'path' DSL
    spec_pattern = 'spec/integration/**/api/**/*_spec.rb'
    sh "bundle exec rspec --pattern '#{spec_pattern}' --format Rswag::Specs::SwaggerFormatter --order defined"

    puts '✓ Swagger documentation generated at swagger/v1/swagger.yaml'
    puts "  Server URL: #{base_url}"
  end

  desc 'Validate swagger documentation is up to date'
  task validate: :environment do
    require 'yaml'

    swagger_path = BetterTogether::Engine.root.join('swagger/v1/swagger.yaml')

    unless File.exist?(swagger_path)
      puts '✗ Swagger documentation not found. Run: rake swagger:generate'
      exit 1
    end

    swagger = YAML.load_file(swagger_path)
    current_base_url = BetterTogether.base_url

    # Check if any server URL matches current environment
    server_urls = swagger['servers']&.map { |s| s['url'] } || []

    if server_urls.include?(current_base_url)
      puts "✓ Swagger documentation is current for #{Rails.env}"
      puts "  Base URL: #{current_base_url}"
    else
      puts "✗ Swagger documentation may be outdated for #{Rails.env}"
      puts "  Expected URL: #{current_base_url}"
      puts "  Found URLs: #{server_urls.join(', ')}"
      puts '  Run: rake swagger:generate'
      exit 1
    end
  end
end
