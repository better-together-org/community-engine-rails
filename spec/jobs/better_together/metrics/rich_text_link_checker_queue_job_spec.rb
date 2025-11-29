# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Metrics
    RSpec.describe RichTextLinkCheckerQueueJob do
      let(:job) { described_class.new }

      before do
        dummy_job = Class.new(ActiveJob::Base)
        allow(job).to receive(:child_job_class).and_return(dummy_job)

        # Prepare fake links grouped by host: two hosts with two links each
        @links_by_host = {
          'a.test' => [instance_double(BetterTogether::Content::Link, id: 1),
                       instance_double(BetterTogether::Content::Link, id: 2)],
          'b.test' => [instance_double(BetterTogether::Content::Link, id: 3),
                       instance_double(BetterTogether::Content::Link, id: 4)]
        }

        total_links_count = @links_by_host.values.map(&:size).sum

        # Stub model_collection.where(host: host) to return the array of links for that host
        model_collection_double = instance_double(ActiveRecord::Relation, size: total_links_count)
        allow(model_collection_double).to receive_messages(group: model_collection_double,
                                                           order: model_collection_double)
        allow(model_collection_double).to receive_messages(size: total_links_count,
                                                           count: @links_by_host.transform_values(&:size))
        allow(model_collection_double).to receive(:where) do |h|
          @links_by_host[h[:host]] || []
        end
        allow(job).to receive_messages(records_by_host: @links_by_host.transform_values(&:size),
                                       model_collection: model_collection_double)
        # Use ActiveJob test adapter to capture enqueued jobs
        ActiveJob::Base.queue_adapter = :test
      end

      it 'schedules child jobs spread across time window per host' do
        expect { job.perform }.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(4)
      end
    end
  end
end
