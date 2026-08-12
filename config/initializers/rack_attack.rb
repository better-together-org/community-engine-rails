# frozen_string_literal: true

module Rack
  # Sets default Rack::Attack configuration
  # rubocop:disable Metrics/ClassLength
  class Attack
    ### Configure Cache ###

    # If you don't want to use Rails.cache (Rack::Attack's default), then
    # configure it here.
    #
    # Note: The store is only used for throttling (not blocklisting and
    # safelisting). It must implement .increment and .write like
    # ActiveSupport::Cache::Store

    rack_attack_redis = ENV.fetch('RACK_ATTACK_REDIS_URL', nil)
    rack_attack_pool_size = ENV.fetch('RACK_ATTACK_REDIS_POOL_SIZE', 5).to_i
    rack_attack_pool_timeout = ENV.fetch('RACK_ATTACK_REDIS_POOL_TIMEOUT', 5).to_f

    # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    if rack_attack_redis
      # ActiveSupport 8.0.3 still initializes ConnectionPool with a positional Hash,
      # which breaks with connection_pool 3.x keyword-only initialization.
      rack_attack_redis_pool = ConnectionPool.new(
        size: rack_attack_pool_size,
        timeout: rack_attack_pool_timeout
      ) do
        Redis.new(url: rack_attack_redis)
      end

      Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
        redis: rack_attack_redis_pool,
        pool: false
      )
    end

    safelist('allow monitors') do |req|
      allowed_user_agents = [
        # rubocop:todo Layout/LineLength
        'Better Stack Better Uptime Bot Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
        # rubocop:enable Layout/LineLength
        # rubocop:todo Layout/LineLength
        'Better Uptime Bot Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36'
        # rubocop:enable Layout/LineLength
      ]
      # Requests are allowed if the return value is truthy
      allowed_user_agents.include?(req.user_agent)
    end

    ### Throttle Spammy Clients ###

    # If any single client IP is making tons of requests, then they're
    # probably malicious or a poorly-configured scraper. Either way, they
    # don't deserve to hog all of the app server's CPU. Cut them off!
    #
    # Note: If you're serving assets through rack, those requests may be
    # counted by rack-attack and this throttle may be activated too
    # quickly. If so, enable the condition to exclude them from tracking.

    # Throttle all requests by IP (60rpm)
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
    throttle('req/ip', limit: 300, period: 5.minutes, &:ip)

    ### MCP Endpoint Throttling ###

    # MCP tool invocations are compute-intensive (DB queries, policy evaluation).
    # Apply tighter per-IP limits than global request throttle.

    # Throttle all MCP requests by IP (60 per minute)
    throttle('mcp/ip', limit: 60, period: 1.minute) do |req|
      req.ip if req.path.start_with?('/mcp')
    end

    # Throttle MCP tool call POSTs more aggressively (30 per minute)
    throttle('mcp/tool-calls/ip', limit: 30, period: 1.minute) do |req|
      req.ip if req.path == '/mcp/messages' && req.post?
    end

    # Per-token MCP throttle (uses first 32 chars of Bearer token as key)
    throttle('mcp/token', limit: 120, period: 1.minute) do |req|
      if req.path.start_with?('/mcp')
        req.env['HTTP_AUTHORIZATION']&.sub(/^Bearer\s+/i, '')&.first(32)
      end
    end

    ### Prevent Brute-Force Login Attacks ###

    # The most common brute-force login attack is a brute-force password
    # attack where an attacker simply tries a large number of emails and
    # passwords to see if any credentials match.
    #
    # Another common method of attack is to use a swarm of computers with
    # different IPs to try brute-forcing a password for a specific account.

    # Throttle POST requests to /users/sign-in by IP address
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
    throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
      req.ip if req.path.include?('/users/sign-in') && req.post?
    end

    ### API Authentication Endpoint Throttling ###

    # Throttle API login endpoint by IP (5 requests per 20 seconds)
    throttle('api_logins/ip', limit: 5, period: 20.seconds) do |req|
      req.ip if req.path.include?('/api/auth/sign_in') && req.post?
    end

    # Throttle API registration endpoint by IP (3 requests per minute)
    throttle('api_registrations/ip', limit: 3, period: 1.minute) do |req|
      req.ip if req.path.include?('/api/auth/sign_up') && req.post?
    end

    # Throttle API password reset endpoint by IP (5 requests per minute)
    throttle('api_password_resets/ip', limit: 5, period: 1.minute) do |req|
      req.ip if req.path.include?('/api/auth/password') && req.post?
    end

    # Throttle OAuth token endpoint by IP (10 requests per minute)
    throttle('oauth/token/ip', limit: 10, period: 1.minute) do |req|
      req.ip if req.path.include?('/oauth/token') && req.post?
    end

    # Throttle POST requests to /users/sign-in by email param
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{normalized_email}"
    #
    # Note: This creates a problem where a malicious user could intentionally
    # throttle logins for another user and force their login requests to be
    # denied, but that's not very common and shouldn't happen to you. (Knock
    # on wood!)
    throttle('logins/email', limit: 5, period: 20.seconds) do |req|
      if req.path.include?('/users/sign-in') && req.post?
        # Normalize the email, using the same logic as your authentication process, to
        # protect against rate limit bypasses. Return the normalized email if present, nil otherwise.
        req.params['email'].to_s.downcase.gsub(/\s+/, '').presence
      end
    end

    ### Permanent IP Denylist ###

    # Confirmed CVE-2026-66066 (Rails ActiveStorage + libvips untrusted-loader
    # RCE) exploitation-attempt source IPs, identified via a fleet-wide log
    # forensics sweep (2026-08-12) after the Rails 8.0.5.1 patch closed the
    # vulnerability. Every one of these IPs was directly observed triggering
    # the vips crash signature (Vips::Error: matload/mat2vips ... blocked) on
    # the vulnerable ActiveStorage representation/blob endpoints -- this is
    # not a generic scanner list, every entry has confirmed attack evidence.
    #
    # Deliberately IP-only: the same actors rotated through common, generic
    # browser user-agent strings (stock Chrome/Firefox/Safari on standard
    # OSes) shared by large numbers of legitimate visitors -- blocking by UA
    # would cause real collateral blocking. Two entries self-identified with
    # the UA "CVE-2026-66066 security verification"; still IP-blocked here
    # rather than by that UA string, for the same consistency reason.
    PERMANENT_IP_DENYLIST = %w[
      157.66.56.32
      46.250.230.56
      203.176.137.245
      138.199.60.25
      138.199.60.13
      91.199.163.63
      91.92.42.135
      43.156.114.53
      221.216.138.182
      185.244.208.177
      103.151.173.90
      65.181.112.46
    ].freeze

    # ENV-based extension point so future confirmed-bad IPs can be added
    # without a gem release: comma-separated, e.g.
    # RACK_ATTACK_EXTRA_IP_DENYLIST=1.2.3.4,5.6.7.8
    blocklist('permanent-ip-denylist') do |req|
      PERMANENT_IP_DENYLIST.include?(req.ip) ||
        ENV.fetch('RACK_ATTACK_EXTRA_IP_DENYLIST', '').split(',').map(&:strip).include?(req.ip)
    end

    ### Fail2Ban for PHP Files ###

    # Block requests for .php files, which are often targeted in WordPress attacks.
    blocklist('fail2ban/php-files') do |req|
      req.path.end_with?('.php')
    end

    # Block WordPress and common CMS probe paths.
    # After 3 hits in 10 minutes, block the IP for 5 minutes.
    blocklist('fail2ban/pentesters') do |req|
      Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes,
                                                            bantime: 5.minutes) do
        CGI.unescape(req.query_string).include?('/etc/passwd') ||
          req.path.include?('/etc/passwd') ||
          req.path.include?('wp-admin') ||
          req.path.include?('wp-content') ||
          req.path.include?('wp-files') ||
          req.path.include?('wp-login') ||
          req.path.end_with?('.php')
      end
    end

    ### Fail2Ban for Scanner/Bot Probes ###

    # Block URL template placeholders used by SEO crawlers and vulnerability scanners
    # (e.g. /en/shop/[category]/*, /fr/blog/[year]/[month]/[slug]).
    # These are never valid app paths. After 2 hits in 5 minutes, block for 30 minutes.
    blocklist('fail2ban/url-template-probes') do |req|
      Rack::Attack::Fail2Ban.filter("url-template-#{req.ip}", maxretry: 2, findtime: 5.minutes,
                                                              bantime: 30.minutes) do
        req.path.match?(/[\[\]*]/)
      end
    end

    # Block path traversal attacks (/../, /..\ etc.). Block immediately for 1 hour.
    blocklist('fail2ban/path-traversal') do |req|
      Rack::Attack::Fail2Ban.filter("path-traversal-#{req.ip}", maxretry: 1, findtime: 10.minutes,
                                                                bantime: 1.hour) do
        req.path.include?('..') || CGI.unescape(req.path).include?('..')
      end
    end

    # Block header/URL injection probes (paths with embedded protocol strings).
    # Block immediately for 1 hour.
    blocklist('fail2ban/url-injection') do |req|
      Rack::Attack::Fail2Ban.filter("url-injection-#{req.ip}", maxretry: 1, findtime: 10.minutes,
                                                               bantime: 1.hour) do
        req.path.match?(/\s+https?:/i)
      end
    end

    # Block common vulnerability scanner paths (env leaks, git config, shell probes, etc.)
    # After 3 hits in 10 minutes, block for 1 hour.
    SCANNER_PATH_PATTERNS = %r{
      /\.env|/\.git/|/\.aws/|/\.ssh/|
      /etc/shadow|/proc/self|
      /var/log/|
      /phpinfo|/xmlrpc\.php|
      /actuator|
      /cgi-bin/
    }xi

    blocklist('fail2ban/vuln-scanner-paths') do |req|
      Rack::Attack::Fail2Ban.filter("vuln-scanner-#{req.ip}", maxretry: 3, findtime: 10.minutes,
                                                              bantime: 1.hour) do
        req.path.match?(SCANNER_PATH_PATTERNS)
      end
    end

    ### Custom Throttle Response ###

    # By default, Rack::Attack returns an HTTP 429 for throttled responses,
    # which is just fine.
    #
    # If you want to return 503 so that the attacker might be fooled into
    # believing that they've successfully broken your app (or you just want to
    # customize the response), then uncomment these lines.
    self.throttled_responder = lambda do |_env|
      [503, # status
       {},   # headers
       ['']] # body
    end

    self.blocklisted_responder = lambda do |_request|
      # Using 503 because it may make attacker think that they have successfully
      # DOSed the site. Rack::Attack returns 403 for blocklists by default
      [503, {}, ['Blocked']]
    end
  end
  # rubocop:enable Metrics/ClassLength
end
