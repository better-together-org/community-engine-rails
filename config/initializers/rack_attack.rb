# frozen_string_literal: true

module Rack
  # Sets default Rack::Attack configuration
  class Attack
    ### Configure Cache ###

    # If you don't want to use Rails.cache (Rack::Attack's default), then
    # configure it here.
    #
    # Note: The store is only used for throttling (not blocklisting and
    # safelisting). It must implement .increment and .write like
    # ActiveSupport::Cache::Store

    rack_attack_redis = ENV.fetch('RACK_ATTACK_REDIS_URL', nil)

    # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    if rack_attack_redis
      Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
        url: rack_attack_redis
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

    ### Fail2Ban for PHP Files ###

    # Block requests for .php files, which are often targeted in WordPress attacks.
    blocklist('fail2ban/php-files') do |req|
      req.path.end_with?('.php')
    end

    # Block suspicious requests for '/etc/password' or wordpress specific paths.
    # After 3 blocked requests in 10 minutes, block all requests from that IP for 5 minutes.
    blocklist('fail2ban pentesters') do |req|
      # `filter` returns truthy value if request fails, or if it's from a previously banned IP
      # so the request is blocked
      Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 5.minutes) do
        # The count for the IP is incremented if the return value is truthy
        CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
          req.path.include?('/etc/passwd') ||
          req.path.include?('wp-admin') ||
          req.path.include?('wp-content') ||
          req.path.include?('wp-files') ||
          req.path.include?('wp-login') ||
          req.path.include?('.php')
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
end
