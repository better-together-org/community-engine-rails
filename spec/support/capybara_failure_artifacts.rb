# frozen_string_literal: true

require 'fileutils'

module BetterTogether
  # Saves a screenshot, page HTML and browser console for failed JS feature specs into a
  # directory CI uploads as an artifact. capybara-screenshot skips pages with an empty
  # current_path (a browser that never loaded anything), which are the hardest failures
  # to diagnose, so this captures the driver state directly and records why it could not.
  module CapybaraFailureArtifacts
    module_function

    def directory
      @directory ||= Pathname.new(
        File.expand_path(ENV.fetch('CAPYBARA_ARTIFACT_PATH', 'tmp/capybara-artifacts'), BetterTogether::Engine.root)
      ).tap { |path| FileUtils.mkdir_p(path) }
    end

    def basename(example)
      slug = example.full_description.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')[0, 100]
      "#{Time.now.utc.strftime('%H%M%S')}-#{slug}"
    end

    def capture(example, session)
      base = directory.join(basename(example))
      notes = [*header(example, session), save(session, base, :screenshot), save(session, base, :html),
               console(session, base)]
      File.write("#{base}.txt", notes.compact.join("\n"))
    end

    def header(example, session)
      ["example: #{example.location}", "path: #{safe { session.current_path }.inspect}",
       "url: #{safe { session.current_url }.inspect}"]
    end

    def save(session, base, kind)
      if kind == :screenshot
        session.save_screenshot("#{base}.png")
      else
        File.write("#{base}.html", session.html)
      end
      nil
    rescue StandardError => e
      "#{kind} not saved: #{e.class}: #{e.message[0, 200]}"
    end

    def console(session, base)
      logs = session.driver.browser.logs.get(:browser)
      File.write("#{base}.console.log", logs.map { |entry| "#{entry.level} #{entry.message}" }.join("\n"))
      nil
    rescue StandardError => e
      "console not saved: #{e.class}: #{e.message[0, 200]}"
    end

    def safe
      yield
    rescue StandardError
      nil
    end
  end
end

Capybara.save_path = BetterTogether::CapybaraFailureArtifacts.directory.to_s

RSpec.configure do |config|
  config.after(:each, :js, type: :feature) do |example|
    BetterTogether::CapybaraFailureArtifacts.capture(example, Capybara.current_session) if example.exception
  end
end
