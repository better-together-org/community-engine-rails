# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::PageViewReport do
    describe 'factory' do
      it 'creates a valid page view report' do
        report = build(:metrics_page_view_report, file_format: 'csv')
        expect(report).to be_valid
        expect(report.file_format).to eq('csv')
      end
    end

    describe 'Active Storage attachments' do
      it 'has one attached report_file' do
        report = build(:metrics_page_view_report)
        expect(report).to respond_to(:report_file)
      end
    end

    describe 'validations' do
      describe 'file_format' do
        it 'requires file_format to be present' do
          report = build(:metrics_page_view_report, file_format: nil)
          expect(report).not_to be_valid
          expect(report.errors[:file_format]).to include("can't be blank")
        end
      end
    end

    describe 'attributes' do
      it 'has filters as jsonb with default empty hash' do
        report = build(:metrics_page_view_report)
        expect(report.filters).to eq({})
      end

      it 'accepts custom filters' do
        filters = { 'from_date' => '2025-01-01', 'to_date' => '2025-12-31', 'filter_pageable_type' => 'Community' }
        report = build(:metrics_page_view_report, filters: filters)
        expect(report.filters).to eq(filters)
      end

      it 'has sort_by_total_views attribute' do
        report = build(:metrics_page_view_report, sort_by_total_views: true)
        expect(report.sort_by_total_views).to be true
      end
    end

    describe 'callbacks' do
      it 'responds to generate_report!' do
        report = build(:metrics_page_view_report)
        expect(report).to respond_to(:generate_report!)
      end
    end

    describe 'report generation' do
      it 'generates report data before creation' do
        report = build(:metrics_page_view_report)
        expect(report).to receive(:generate_report!)
        report.save
      end
    end
  end
end
