module Lograge
  class LogSubscriber < ActiveSupport::LogSubscriber
    def event(event)
      return if Lograge.ignore?(event)

      payload = event.payload
      data = extract_request(event, payload)
      data = Lograge.before_format(data, payload)
      formatted_message = Lograge.formatter.call(data)
      logger.send(Lograge.log_level, formatted_message)
    end

    def logger
      Lograge.logger.presence || super
    end

    private

    def custom_options(event)
      options = Lograge.custom_options(event) || {}
      options.merge event.payload[:custom_payload] || {}
    end

    def extract_exception(payload)
      exception, message = payload[:exception]
      return {} unless exception

      { error: "#{exception}: #{message}" }
    end

    if ::ActionPack::VERSION::MAJOR == 3 && ::ActionPack::VERSION::MINOR.zero?
      def extract_format(payload)
        format = payload[:formats]&.first
        return {} unless format

        { format: format }
      end
    else
      def extract_format(payload)
        format = payload[:format]
        return {} unless format

        { format: format }
      end
    end

    def extract_location
      location = RequestStore.store[:lograge_location]
      return {} unless location

      RequestStore.store[:lograge_location] = nil
      { location: strip_query_string(location) }
    end

    def extract_path(payload)
      path = payload[:path]
      strip_query_string(path)
    end

    def extract_rails(payload)
      return {} unless payload.key?(:action) || payload.key?(:controller)

      {
        controller: payload[:controller],
        action: payload[:action]
      }
    end

    def extract_request(event, payload)
      data = initial_data(payload)

      data.merge!(extract_exception(payload))
      data.merge!(extract_format(payload))
      data.merge!(extract_location)
      data.merge!(extract_rails(payload))
      data.merge!(extract_runtimes(event, payload))
      data.merge!(extract_status(payload))
      data.merge!(extract_unpermitted_params)

      data.merge!(custom_options(event))
    end

    def extract_runtimes(event, payload)
      data = { duration: event.duration.to_f.round(2) }
      data[:view] = payload[:view_runtime].to_f.round(2) if payload.key?(:view_runtime)
      data[:db] = payload[:db_runtime].to_f.round(2) if payload.key?(:db_runtime)
      data
    end

    def extract_status(payload)
      if (status = payload[:status])
        { status: status.to_i }
      elsif payload[:exception]
        { status: 500 }
      else
        { status: 0 }
      end
    end

    def extract_unpermitted_params
      unpermitted_params = RequestStore.store[:lograge_unpermitted_params]
      return {} unless unpermitted_params

      RequestStore.store[:lograge_unpermitted_params] = nil
      { unpermitted_params: unpermitted_params }
    end

    def initial_data(payload)
      {
        method: payload[:method],
        path: extract_path(payload),
      }
    end

    def strip_query_string(path)
      index = path.index('?')
      index ? path[0, index] : path
    end
  end
end
