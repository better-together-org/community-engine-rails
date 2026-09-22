# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'securerandom'
require 'shellwords'

module BetterTogether
  module ContentSecurity
    # Invokes the shared content safety orchestrator and returns parsed contract records.
    class OrchestratorRunner
      class Error < StandardError; end

      def initialize(command: BetterTogether.content_safety_orchestrator_command)
        @command = command
      end

      def call(payload)
        raise Error, 'Content safety orchestrator command is not configured.' if command_tokens.blank?

        input_path = write_payload(payload)
        JSON.parse(run_command(input_path))
      rescue Errno::ENOENT => e
        raise Error, "Content safety orchestrator failed: #{e.message}"
      rescue JSON::ParserError => e
        raise Error, "Content safety orchestrator returned invalid JSON: #{e.message}"
      ensure
        FileUtils.rm_f(input_path) if input_path
      end

      private

      def command_tokens
        @command_tokens ||= case @command
                            when Array
                              @command
                            when String
                              Shellwords.split(@command)
                            else
                              []
                            end
      end

      def write_payload(payload)
        path = BetterTogether::Engine.root.join('tmp', 'content-safety', "mail-screening-#{SecureRandom.uuid}.json")
        FileUtils.mkdir_p(path.dirname)
        path.write(JSON.pretty_generate(payload))
        path
      end

      def run_command(input_path)
        stdout, stderr, status = Open3.capture3(*command_tokens, '--input-json', input_path.to_s, '--format', 'json')
        raise Error, failure_message(stderr, stdout) unless status.success?

        stdout
      end

      def failure_message(stderr, stdout)
        detail = stderr.presence || stdout.presence || 'unknown failure'
        "Content safety orchestrator failed: #{detail.to_s.strip}"
      end
    end
  end
end
