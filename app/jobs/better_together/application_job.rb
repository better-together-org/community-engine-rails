# frozen_string_literal: true

module BetterTogether
  # Base job class for Better Together background work.
  class ApplicationJob < ActiveJob::Base
    discard_on ActiveStorage::FileNotFoundError
  end
end
