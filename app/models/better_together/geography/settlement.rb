# frozen_string_literal: true

module BetterTogether
  module Geography
    class Settlement < ApplicationRecord # rubocop:todo Style/Documentation
      include Geospatial::One
      include Identifier
      include Protected
      include PrimaryCommunity

      # VICKI EDITS
      include Attachments::Images 

      attachable_cover_image




      has_community

      slugged :name

      belongs_to :country, class_name: 'BetterTogether::Geography::Country', optional: true
      belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true

      has_many :region_settlements, class_name: 'BetterTogether::Geography::RegionSettlement'
      has_many :regions, through: :region_settlements, source: :region

      def to_s
        name  
      end
    
      configure_attachment_cleanup
    end
  end
end
