# frozen_string_literal: true

require 'uri'

module BetterTogether
  # Builds Elasticsearch client options from environment variables.
  module ElasticsearchClientOptions
    module_function

    def build(env = ENV)
      base_options(env).tap do |options|
        attach_ssl_options(options, env)
        attach_ca_fingerprint(options, env)
      end
    end

    def resolved_url(env)
      base_url = env_value(env, 'ELASTICSEARCH_URL') || begin
        host = env.fetch('ES_HOST', 'http://localhost')
        port = env.fetch('ES_PORT', 9200)
        "#{host}:#{port}"
      end

      inject_credentials(base_url, env)
    end

    def base_options(env)
      {
        url: resolved_url(env),
        retry_on_failure: true,
        reload_connections: true,
        transport_options: {
          request: {
            timeout: 5,
            open_timeout: 2
          }
        }
      }
    end

    def inject_credentials(url, env)
      uri = URI.parse(url)
      return url if uri.user || uri.password

      username = env_value(env, 'ELASTICSEARCH_USERNAME', 'ES_USERNAME')
      password = env_value(env, 'ELASTICSEARCH_PASSWORD', 'ES_PASSWORD')
      return url unless username || password

      uri.user = username if username
      uri.password = password if password
      uri.to_s
    end

    def build_ssl_options(env)
      ssl_options = {}

      ca_file = env_value(env, 'ELASTICSEARCH_CA_CERT_FILE', 'ELASTICSEARCH_CA_CERTS', 'ES_CA_CERT_FILE', 'ES_CA_CERTS')
      ssl_options[:ca_file] = ca_file if ca_file

      verify = env_value(env, 'ELASTICSEARCH_SSL_VERIFY', 'ES_SSL_VERIFY')
      ssl_options[:verify] = truthy?(verify) unless verify.nil?

      ssl_options
    end

    def attach_ssl_options(options, env)
      ssl_options = build_ssl_options(env)
      return unless ssl_options.any?

      options[:transport_options][:ssl] = ssl_options
    end

    def attach_ca_fingerprint(options, env)
      ca_fingerprint = env_value(env, 'ELASTICSEARCH_CA_FINGERPRINT', 'ES_CA_FINGERPRINT')
      return unless ca_fingerprint

      options[:ca_fingerprint] = ca_fingerprint
    end

    def env_value(env, *keys)
      keys.each do |key|
        value = env[key]
        return value if value && !value.empty?
      end

      nil
    end

    def truthy?(value)
      !%w[0 false no off].include?(value.to_s.strip.downcase)
    end
  end
end
