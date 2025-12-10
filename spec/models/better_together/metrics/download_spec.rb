# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::Download do
    describe 'factory' do
      it 'creates a valid download' do
        community = create(:community)
        download = create(:metrics_download,
                          downloadable: community,
                          file_name: 'report.pdf',
                          file_type: 'application/pdf',
                          file_size: 2048,
                          downloaded_at: Time.current,
                          locale: 'en')
        expect(download).to be_valid
        expect(download.file_name).to eq('report.pdf')
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:downloadable) }
    end

    describe 'validations' do
      describe 'file_name' do
        it 'requires file_name to be present' do
          download = build(:metrics_download, file_name: nil)
          expect(download).not_to be_valid
          expect(download.errors[:file_name]).to include("can't be blank")
        end
      end

      describe 'file_type' do
        it 'requires file_type to be present' do
          download = build(:metrics_download, file_type: nil)
          expect(download).not_to be_valid
          expect(download.errors[:file_type]).to include("can't be blank")
        end
      end

      describe 'file_size' do
        it 'requires file_size to be present' do
          download = build(:metrics_download, file_size: nil)
          expect(download).not_to be_valid
          expect(download.errors[:file_size]).to include("can't be blank")
        end
      end

      describe 'downloaded_at' do
        it 'requires downloaded_at to be present' do
          download = build(:metrics_download, downloaded_at: nil)
          expect(download).not_to be_valid
          expect(download.errors[:downloaded_at]).to include("can't be blank")
        end
      end

      describe 'locale' do
        it 'requires locale to be present' do
          download = build(:metrics_download, locale: nil)
          expect(download).not_to be_valid
          expect(download.errors[:locale]).to include("can't be blank")
        end

        it 'validates locale is in available locales' do
          download = build(:metrics_download, locale: 'invalid')
          expect(download).not_to be_valid
          expect(download.errors[:locale]).to include('is not included in the list')
        end

        it 'accepts valid locales' do
          I18n.available_locales.each do |locale|
            download = build(:metrics_download, locale: locale.to_s)
            expect(download).to be_valid, "Expected #{locale} to be valid"
          end
        end
      end
    end

    describe 'file tracking' do
      it 'tracks file metadata' do
        download = create(:metrics_download,
                          file_name: 'annual_report.pdf',
                          file_type: 'application/pdf',
                          file_size: 4096)

        expect(download.file_name).to eq('annual_report.pdf')
        expect(download.file_type).to eq('application/pdf')
        expect(download.file_size).to eq(4096)
      end
    end
  end
end
