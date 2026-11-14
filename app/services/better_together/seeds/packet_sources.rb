# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Where packets may be read from. The legacy single-file loader is limited to config/seeds;
    # packets may also live in host-app directories or an operator-controlled upload area.
    # Extra roots come from register_root or BETTER_TOGETHER_SEED_PACKET_ROOTS (colon separated).
    module PacketSources
      class Forbidden < SecurityError; end

      @extra_roots = []

      class << self
        def register_root(path)
          @extra_roots |= [Pathname.new(path.to_s)]
        end

        def reset!
          @extra_roots = []
        end

        def roots
          env = ENV.fetch('BETTER_TOGETHER_SEED_PACKET_ROOTS', '').split(':').compact_blank.map { |p| Pathname.new(p) }
          ([Rails.root.join('config/seeds'), BetterTogether::Engine.root.join('config/seeds')] + @extra_roots + env).map do |root|
            real(root)
          end.compact
        end

        # Returns the resolved packet path, or raises Forbidden. Symlinks are resolved first,
        # so a link inside an allowed root cannot point the loader elsewhere.
        def resolve!(path)
          raise Forbidden, 'packet path contains ..' if path.to_s.split('/').include?('..')

          resolved = real(Pathname.new(path.to_s))
          raise Forbidden, "packet path not found: #{path}" unless resolved

          allowed = roots.any? { |root| resolved == root || resolved.to_s.start_with?("#{root}/") }
          raise Forbidden, "packet path #{resolved} is outside the allowed roots (#{roots.join(', ')})" unless allowed

          resolved
        end

        private

        def real(pathname)
          pathname.realpath
        rescue Errno::ENOENT
          nil
        end
      end
    end
  end
end
