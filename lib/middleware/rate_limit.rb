module Middleware
  autoload :RequestLimit, 'middleware/rate_limit/request_limit'

  class RateLimit
    def initialize(app, redis)
      @app = app
      @redis = redis
    end

    def call(env)
      request_limit = RequestLimit.new(
        @redis,
        redis_key: env['REMOTE_ADDR'],
        max_requests: 100,
        time_window: 3600
      )

      if request_limit.reached?
        [
          429,
          request_limit.rate_limit_headers,
          [request_limit.limit_reached_message]
        ]
      else
        status, headers, body = @app.call(env)
        [
          status,
          headers.merge(request_limit.rate_limit_headers),
          body
        ]
      end
    end
  end
end