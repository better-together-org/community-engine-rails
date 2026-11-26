# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Adds structured data to a finished PDF as an incremental update (the original bytes stay untouched): files
      # attached to the document (the Factur-X XML as `factur-x.xml`, the schema.org JSON-LD as `order.jsonld`), an
      # XMP metadata stream naming the Factur-X profile, and an Info dictionary with title, author and dates.
      #
      # Reads like a Factur-X / ZUGFeRD hybrid invoice and `pdfdetach -list` shows both files. It is not certified
      # PDF/A-3 (fonts and colour profile are the PDF writer's), and nothing here is validated against the schema.
      class PdfAttachments
        Attachment = Data.define(:name, :content, :mime, :relationship, :description)

        def initialize(pdf, attachments:, title:, author:, created_at:)
          @pdf = pdf.b
          @attachments = attachments
          @title = title
          @author = author
          @created_at = created_at
        end

        def to_pdf
          @out = @pdf.dup
          @offsets = {}
          @next = size
          file_refs = @attachments.map { |attachment| add_file(attachment) }
          xmp = add_stream(xmp_packet, '/Type /Metadata /Subtype /XML')
          info = add_object(info_dictionary)
          write_root(file_refs, xmp)
          write_xref(info)
          @out
        end

        private

        def trailer = @trailer ||= @pdf[/trailer\s*<<(.*?)>>\s*startxref/m, 1].to_s
        def size = trailer[%r{/Size (\d+)}, 1].to_i
        def root_number = trailer[%r{/Root (\d+) 0 R}, 1].to_i
        def previous_xref = @pdf[/startxref\s+(\d+)\s+%%EOF\s*\z/, 1].to_i
        def id_entry = trailer[%r{/ID \[.*?\]}m]

        def root_dictionary
          @root_dictionary ||= @pdf[/^#{root_number} 0 obj\s*<<(.*?)>>\s*endobj/m, 1].to_s.strip
        end

        def add_object(body)
          number = @next
          @next += 1
          @offsets[number] = @out.bytesize
          @out << "#{number} 0 obj\n#{body}\nendobj\n".b
          number
        end

        def add_stream(data, dictionary)
          data = data.b
          add_object("<<#{dictionary} /Length #{data.bytesize}>>\nstream\n#{data}\nendstream".b)
        end

        def add_file(attachment) # rubocop:disable Metrics/AbcSize
          stream = add_stream(attachment.content, "/Type /EmbeddedFile /Subtype /#{name_escape(attachment.mime)} " \
                                                  "/Params << /Size #{attachment.content.bytesize} " \
                                                  "/ModDate #{pdf_string(pdf_date)} >>")
          spec = add_object("<</Type /Filespec /F #{pdf_string(attachment.name)} /UF #{pdf_string(attachment.name)} " \
                            "/Desc #{pdf_string(attachment.description)} /AFRelationship /#{attachment.relationship} " \
                            "/EF << /F #{stream} 0 R /UF #{stream} 0 R >>>>")
          [attachment.name, spec]
        end

        def write_root(file_refs, xmp)
          names = file_refs.map { |name, spec| "#{pdf_string(name)} #{spec} 0 R" }.join(' ')
          af = file_refs.map { |_name, spec| "#{spec} 0 R" }.join(' ')
          extra = "/Names << /EmbeddedFiles << /Names [#{names}] >> >> /AF [#{af}] /Metadata #{xmp} 0 R"
          @offsets[root_number] = @out.bytesize
          @out << "#{root_number} 0 obj\n<<#{root_dictionary} #{extra}>>\nendobj\n".b
        end

        def write_xref(info) # rubocop:disable Metrics/AbcSize
          start = @out.bytesize
          numbers = @offsets.keys.sort
          @out << "xref\n".b
          numbers.chunk_while { |a, b| b == a + 1 }.each do |run|
            @out << "#{run.first} #{run.size}\n".b
            run.each { |number| @out << format("%010d 00000 n \n", @offsets[number]).b }
          end
          @out << "trailer\n<</Size #{@next} /Root #{root_number} 0 R /Info #{info} 0 R /Prev #{previous_xref} #{id_entry}>>\n".b
          @out << "startxref\n#{start}\n%%EOF\n".b
        end

        def info_dictionary
          "<</Title #{pdf_string(@title)} /Author #{pdf_string(@author)} /Producer (Community Engine) " \
            "/CreationDate #{pdf_string(pdf_date)} /ModDate #{pdf_string(pdf_date)}>>"
        end

        def pdf_date = @created_at.utc.strftime("D:%Y%m%d%H%M%S'00'")

        # A PDF text string as UTF-16BE hex, so any language survives.
        def pdf_string(text) = "<FEFF#{text.to_s.encode('UTF-16BE').unpack1('H*').upcase}>"

        def name_escape(text) = text.to_s.gsub('/', '#2F')

        def xmp_packet
          <<~XMP
            <?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
            <x:xmpmeta xmlns:x="adobe:ns:meta/">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmp="http://ns.adobe.com/xap/1.0/"
                  xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#">
                  <dc:title><rdf:Alt><rdf:li xml:lang="x-default">#{ERB::Util.html_escape(@title)}</rdf:li></rdf:Alt></dc:title>
                  <dc:creator><rdf:Seq><rdf:li>#{ERB::Util.html_escape(@author)}</rdf:li></rdf:Seq></dc:creator>
                  <xmp:CreateDate>#{@created_at.utc.iso8601}</xmp:CreateDate>
                  <fx:DocumentType>INVOICE</fx:DocumentType>
                  <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>
                  <fx:Version>1.0</fx:Version>
                  <fx:ConformanceLevel>#{InvoiceXml::PROFILE.split(':').last.upcase}</fx:ConformanceLevel>
                </rdf:Description>
              </rdf:RDF>
            </x:xmpmeta>
            <?xpacket end="w"?>
          XMP
        end
      end
    end
  end
end
