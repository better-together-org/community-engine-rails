# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

namespace :better_together do
  namespace :content do
    desc 'Import mermaid diagrams from docs/diagrams/source/ directory'
    task import_diagrams: :environment do
      puts 'Importing Mermaid diagrams from docs/diagrams/source/...'

      # Check engine root first (for gem development), then Rails.root (for host apps)
      engine_root = BetterTogether::Engine.root
      diagram_dir = engine_root.join('docs/diagrams/source')

      unless Dir.exist?(diagram_dir)
        # Fallback to Rails.root for host applications
        diagram_dir = Rails.root.join('docs/diagrams/source')
        unless Dir.exist?(diagram_dir)
          puts '  Directory not found in either:'
          puts "    - #{engine_root.join('docs/diagrams/source')}"
          puts "    - #{Rails.root.join('docs/diagrams/source')}"
          puts '  Skipping import.'
          exit 0
        end
      end

      puts "  Using directory: #{diagram_dir}"

      diagram_files = Dir.glob(diagram_dir.join('*.mmd'))
      if diagram_files.empty?
        puts '  No .mmd files found'
        exit 0
      end

      puts "  Found #{diagram_files.length} diagram files"
      puts

      created_count = 0
      skipped_count = 0

      diagram_files.each do |file_path|
        # Calculate relative path from the directory we're using
        base_dir = diagram_dir.parent.parent.parent # Go up from docs/diagrams/source to root
        relative_path = Pathname.new(file_path).relative_path_from(base_dir).to_s
        filename = File.basename(file_path, '.mmd')

        # Generate human-readable name from filename
        name = filename.titleize

        # Check if already imported
        existing = BetterTogether::Content::MermaidDiagram.find_by(
          "content_data->>'diagram_file_path' = ?", relative_path
        )

        if existing
          puts "  ⏭️  Skipping #{filename} (already imported)"
          skipped_count += 1
          next
        end

        begin
          diagram = BetterTogether::Content::MermaidDiagram.create!(
            diagram_file_path: relative_path,
            caption: name,
            theme: 'neutral', # Default theme for docs
            auto_height: true
          )

          puts "  ✅ Imported #{filename} → Diagram ##{diagram.id}"
          created_count += 1
        rescue ActiveRecord::RecordInvalid => e
          puts "  ❌ Failed to import #{filename}: #{e.message}"
        end
      end

      puts
      puts "Import complete: #{created_count} created, #{skipped_count} skipped"
    end

    desc 'List all diagrams and their file paths'
    task list_diagrams: :environment do
      diagrams = BetterTogether::Content::MermaidDiagram.all

      if diagrams.empty?
        puts 'No mermaid diagrams found.'
        exit 0
      end

      puts "Found #{diagrams.count} mermaid diagrams:"
      puts

      diagrams.find_each do |diagram|
        source_type = if diagram.diagram_file_path.present?
                        "📄 File: #{diagram.diagram_file_path}"
                      elsif diagram.diagram_source.present?
                        '📝 Inline source'
                      else
                        '⚠️  No content'
                      end

        caption = diagram.caption.presence || '(no caption)'
        puts "  ID #{diagram.id}: #{caption}"
        puts "    #{source_type}"
        puts "    Theme: #{diagram.theme}, Auto-height: #{diagram.auto_height}"
        puts
      end
    end

    desc 'Create a documentation page with all imported diagrams'
    task create_diagram_gallery: :environment do
      puts 'Creating diagram gallery page...'

      page = BetterTogether::Page.find_or_create_by!(slug: 'diagram-gallery') do |p|
        p.title = 'Diagram Gallery'
        p.published = true
        p.privacy = 'public'
      end

      # Clear existing blocks
      page.page_blocks.destroy_all

      # Add intro
      intro = BetterTogether::Content::Markdown.create!(
        markdown_source: <<~MARKDOWN
          # Diagram Gallery

          This page showcases all available Mermaid diagrams from the documentation.
        MARKDOWN
      )
      page.page_blocks.create!(block: intro, position: 1)

      # Add all file-based diagrams
      diagrams = BetterTogether::Content::MermaidDiagram.where.not(
        "content_data->>'diagram_file_path'": nil
      ).order(:id)

      if diagrams.any?
        diagrams.each_with_index do |diagram, index|
          page.page_blocks.create!(
            block: diagram,
            position: index + 2
          )
        end

        puts "  ✅ Created gallery page with #{diagrams.count} diagrams"
        puts '  View at: /en/diagram-gallery (or your locale)'
      else
        puts '  ⚠️  No file-based diagrams found to add'
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
