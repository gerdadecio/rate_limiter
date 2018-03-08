module Middleware
  class RequestLimit
    def initialize(redis, redis_key:, max_requests: 100, time_window: 3600)
      @max_requests = max_requests
      @redis = redis
      @redis_key = redis_key
      @time_window = time_window

      process
    end

    def reached?
      @redis.get(key).to_i >= @max_requests
    end

    def rate_limit_headers
      {
        "X-Rate-Limit-Limit" =>  @max_requests,
        "X-Rate-Limit-Remaining" => (@max_requests - @redis.get(key).to_i).to_s,
        "X-Rate-Limit-Reset" => time_til_reset
      }
    end

    def limit_reached_message
      {
        message: "Rate limit exceeded. Try again in #{remaining_time_til_reset} seconds"
      }.to_json
    end

    private

    def process
      unless @redis.get(key)
        @redis.set(key, 0)
        @redis.expire(key, @time_window)
      end

      increment_count
    end

    def increment_count
      @redis.incr(key)
    end

    def key
      "count:#{@redis_key}"
    end

    def time_til_reset
      (@redis.ttl(key) + Time.now.to_i).to_s
    end

    def remaining_time_til_reset
      @redis.ttl(key)
    end

  end
end
