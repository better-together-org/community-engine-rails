# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe UploadsHelper, type: :helper do
    describe '#total_upload_size' do
      it 'returns human readable total size' do
        uploads = [double(byte_size: 2.megabytes), double(byte_size: 3.megabytes)]
        expect(helper.total_upload_size(uploads)).to eq '5 MB'
      end
    end
  end
end
