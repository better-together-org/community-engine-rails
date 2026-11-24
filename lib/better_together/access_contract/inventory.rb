# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

module BetterTogether
  module AccessContract
    # Introspects routes, controllers, views, MCP tools and jobs so the subsystem inventory
    # is read from the code and cannot go stale.
    class Inventory
      AUTH_CALL = /\b(authorize|policy_scope|authorize_\w+|verify_authorized|verify_policy_scoped)\b/
      AUTH_CALLBACK = /\A\s*(?:prepend_)?(?:before|after|around)_action\s+:(\w*(?:authori[sz]e|verify_authorized|verify_policy_scoped)\w*)(.*)\z/

      attr_reader :contract

      def initialize(contract)
        @contract = contract
      end

      # One entry per routed controller action of the pilot controllers.
      def routed_actions(controllers = pilot_controllers)
        @routed ||= {}
        @routed[controllers] ||= build_routes(controllers)
      end

      def pilot_controllers
        contract.subsystems.values.flat_map { |f| f['controllers'] || [] }.uniq
      end

      def views_for(controller)
        dir = AccessContract.root.join('app/views', controller)
        Dir[dir.join('*')].map { |f| File.basename(f) }.sort
      end

      # Files under dir whose source mentions the model's class name, relative to the engine root.
      def mentions(model, dir)
        short = Regexp.escape(model.demodulize)
        Dir[AccessContract.root.join(dir, '**/*.rb')].select { |f| File.read(f).match?(/\b#{short}\b/) }
                                                     .map { |f| Pathname(f).relative_path_from(AccessContract.root).to_s }.sort
      end

      def mcp_tools(model) = mentions(model, 'app/tools')
      def jobs(model) = mentions(model, 'app/jobs')

      def allowlist
        @allowlist ||= contract.subsystems.values.reduce({}) { |acc, f| acc.merge(f['controller_allowlist'] || {}) }
      end

      private

      def build_routes(controllers)
        raw = BetterTogether::Engine.routes.routes.filter_map do |route|
          controller = route.defaults[:controller]
          next unless controllers.include?(controller)

          { controller:, action: route.defaults[:action], verb: route.verb.to_s, path: route.path.spec.to_s.sub('(.:format)', '') }
        end
        grouped = raw.group_by { |r| [r[:controller], r[:action]] }.sort
        grouped.map { |(controller, action), rows| route_entry(controller, action, rows) }
      end

      def route_entry(controller, action, rows)
        first = rows.min_by { |r| r[:path] }
        status, detail = authorization_status(controller, action)
        { controller:, action:, verb: first[:verb], path: first[:path], paths: rows.size, status:, detail: }
      end

      def authorization_status(path, action)
        klass = "#{path.camelize}Controller".safe_constantize
        return [:missing, 'controller not found'] unless klass
        return [:not_implemented, 'routed but the controller defines no such action'] unless klass.action_methods.include?(action)

        reason = allowlist["#{path}##{action}"] || allowlist["#{path.delete_prefix('better_together/')}##{action}"]
        return [:allowlisted, reason] if reason

        covered_by(klass, action) || [:missing, nil]
      end

      def covered_by(klass, action)
        return [:api, 'Pundit::ResourceController'] if klass.ancestors.include?(Pundit::ResourceController)
        return [:action, 'authorize or policy_scope in the action'] if body_authorizes?(klass, action)

        [:callback, 'authorization callback'] if callback_authorizes?(klass, action)
      end

      def body_authorizes?(klass, action)
        file, line = klass.instance_method(action).source_location
        return false unless file && File.exist?(file)

        method_body(File.readlines(file), line - 1).match?(AUTH_CALL)
      end

      def method_body(lines, start)
        indent = lines[start][/\A\s*/]
        finish = ((start + 1)...lines.size).find { |i| lines[i] =~ /\A#{indent}end\b/ } || start
        lines[start..finish].join
      end

      def callback_authorizes?(klass, action)
        klass.ancestors.grep(Class).select { |k| k.name.to_s.start_with?('BetterTogether') }.any? do |k|
          callback_args(k).any? { |args| callback_applies?(args, action) }
        end
      end

      def callback_args(klass)
        @callback_args ||= {}
        @callback_args[klass.name] ||= begin
          file = Object.const_source_location(klass.name)&.first
          file && File.exist?(file) ? File.readlines(file, chomp: true).filter_map { |l| l.match(AUTH_CALLBACK)&.captures&.last } : []
        end
      end

      def callback_applies?(args, action)
        only = option_list(args, 'only')
        except = option_list(args, 'except')
        (only.nil? || only.include?(action)) && !except&.include?(action)
      end

      def option_list(args, key)
        match = args.match(/#{key}:\s*(%i\[[^\]]*\]|\[[^\]]*\]|:\w+)/)
        match && (match[1].scan(/\w+/) - ['i'])
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
