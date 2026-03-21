# frozen_string_literal: true

# JSONAPI-Resources STI aliases for Content::Block subtypes.
#
# JSONAPI-Resources resolves the resource class for an AR record by computing
# "#{namespace}::#{model.class.name.demodulize}Resource". Because all Block STI
# subtypes share the same resource surface (BlockResource), we register each
# demodulized subtype name as a constant pointing back to BlockResource.
#
# New Block subtypes added in the future must be added here.
module BetterTogether
  module Api
    module V1
      AccordionBlockResource     = BlockResource
      AlertBlockResource         = BlockResource
      CallToActionBlockResource  = BlockResource
      ChecklistBlockResource     = BlockResource
      CommunitiesBlockResource   = BlockResource
      CssResource                = BlockResource
      EventsBlockResource        = BlockResource
      HeroResource               = BlockResource
      HtmlResource               = BlockResource
      ImageResource              = BlockResource
      MarkdownResource           = BlockResource
      MermaidDiagramResource     = BlockResource
      NavigationAreaBlockResource = BlockResource
      PeopleBlockResource        = BlockResource
      PostsBlockResource         = BlockResource
      QuoteBlockResource         = BlockResource
      RichTextResource           = BlockResource
      StatisticsBlockResource    = BlockResource
      TemplateResource           = BlockResource
      VideoBlockResource         = BlockResource
    end
  end
end
