module Lograge
  class ActionControllerLogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      RequestStore.store[:lograge_event] = event
    end

    def redirect_to(event)
      RequestStore.store[:lograge_location] = event.payload[:location]
    end

    def unpermitted_parameters(event)
      RequestStore.store[:lograge_unpermitted_params] ||= []
      RequestStore.store[:lograge_unpermitted_params].concat(event.payload[:keys])
    end
  end
end
