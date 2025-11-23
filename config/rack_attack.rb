# frozen_string_literal: true

# Configure Rack::Attack for rate limiting
module Rack
  class Attack
    # Throttle all requests by IP (60 requests per minute)
    throttle('req/ip', limit: 60, period: 60, &:ip)

    # Throttle POST requests to /api/v1/chain by IP (10 per minute)
    throttle('chain/ip', limit: 10, period: 60) do |req|
      req.ip if req.path == '/api/v1/chain' && req.post?
    end

    # Throttle POST requests to block creation (30 per minute)
    throttle('block/ip', limit: 30, period: 60) do |req|
      req.ip if req.path.match?(%r{^/api/v1/chain/.+/block$}) && req.post?
    end

    # Custom response for throttled requests
    self.throttled_responder = lambda do |_env|
      [
        429,
        { 'Content-Type' => 'application/json' },
        [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
      ]
    end
  end
end
