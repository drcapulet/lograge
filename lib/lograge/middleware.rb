module Lograge
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ::Rack::Request.new(env)

      # By creating a different event, we get a better understanding of the
      # entire request, including time taken and changes make by middleware.
      ActiveSupport::Notifications.instrument(
        Lograge::AS_NOTIFICATION,
        method: request.request_method,
        path: request.path,
      ) do |payload|
        begin
          @app.call(env).tap do |status, _headers, _body|
            # We always use this status instead of the one in the original event
            # because a middleware could have changed it.
            payload.merge!(status: status)
          end
        ensure
          # Make sure to keep the status
          status = payload[:status]

          if RequestStore.store[:lograge_event]
            payload.merge!(RequestStore.store[:lograge_event].payload)
          end

          payload[:status] = status if status
        end
      end
    end
  end
end
