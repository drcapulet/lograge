require 'logger'

describe Lograge::LogSubscriber do
  let(:event_params) { { 'foo' => 'bar' } }
  let(:log_output)   { StringIO.new }
  let(:subscriber)   { described_class.new }

  let(:event) do
    ActiveSupport::Notifications::Event.new(
      Lograge::AS_NOTIFICATION,
      Time.now,
      Time.now,
      2,
      status: 200,
      controller: 'HomeController',
      action: 'index',
      format: 'application/json',
      method: 'GET',
      path: '/home?foo=bar',
      params: event_params,
      db_runtime: 0.02,
      view_runtime: 0.01
    )
  end

  let(:logger) do
    Logger.new(log_output).tap { |logger| logger.formatter = ->(_, _, _, msg) { msg } }
  end

  before { Lograge.logger = logger }

  context 'with custom_options configured for cee output' do
    before do
      Lograge.formatter = ->(data) { "My test: #{data}" }
    end

    it 'combines the hash properly for the output' do
      Lograge.custom_options = { data: 'value' }
      subscriber.request(event)
      expect(log_output.string).to match(/^My test: {.*:data=>"value"/)
    end

    it 'combines the output of a lambda properly' do
      Lograge.custom_options = ->(_event) { { data: 'value' } }

      subscriber.request(event)
      expect(log_output.string).to match(/^My test: {.*:data=>"value"/)
    end

    it 'works when the method returns nil' do
      Lograge.custom_options = ->(_event) { nil }

      subscriber.request(event)
      expect(log_output.string).to be_present
    end
  end

  context 'when processing an action with lograge output' do
    before do
      Lograge.formatter = Lograge::Formatters::KeyValue.new
    end

    it 'includes the URL in the log output' do
      subscriber.request(event)
      expect(log_output.string).to include('/home')
    end

    it 'does not include the query string in the url' do
      subscriber.request(event)
      expect(log_output.string).not_to include('?foo=bar')
    end

    it 'starts the log line with the HTTP method' do
      subscriber.request(event)
      expect(log_output.string).to match(/^method=GET /)
    end

    it 'includes the status code' do
      subscriber.request(event)
      expect(log_output.string).to include('status=200')
    end

    it 'includes the controller and action' do
      subscriber.request(event)
      expect(log_output.string).to include('controller=HomeController action=index')
    end

    it 'includes the duration' do
      subscriber.request(event)
      expect(log_output.string).to match(/duration=[\.0-9]{4,4} /)
    end

    it 'includes the view rendering time' do
      subscriber.request(event)
      expect(log_output.string).to match(/view=0.01 /)
    end

    it 'includes the database rendering time' do
      subscriber.request(event)
      expect(log_output.string).to match(/db=0.02/)
    end

    context 'when an exception is raised' do
      let(:exception) { 'ActiveRecord::RecordNotFound' }

      before do
        event.payload[:exception] = [exception, 'Record not found']
        event.payload[:status] = 404
      end

      it 'adds the exception details' do
        subscriber.request(event)
        expect(log_output.string).to match(/status=404$/)
        expect(log_output.string).to match(
          /error='ActiveRecord::RecordNotFound: Record not found' /
        )
      end
    end

    it 'returns an unknown status when no status or exception is found' do
      event.payload[:status] = nil
      event.payload[:exception] = nil
      subscriber.request(event)
      expect(log_output.string).to match(/status=0$/)
    end

    context 'with a redirect' do
      before do
        RequestStore.store[:lograge_location] = 'http://www.example.com?key=value'
      end

      it 'adds the location to the log line' do
        subscriber.request(event)
        expect(log_output.string).to match(%r{location=http://www.example.com})
      end

      it 'removes the thread local variable' do
        subscriber.request(event)
        expect(RequestStore.store[:lograge_location]).to be_nil
      end
    end

    it 'does not include a location by default' do
      subscriber.request(event)
      expect(log_output.string).to_not include('location=')
    end

    context 'with unpermitted_parameters' do
      before do
        RequestStore.store[:lograge_unpermitted_params] = %w(florb blarf)
      end

      it 'adds the unpermitted_params to the log line' do
        subscriber.request(event)
        expect(log_output.string).to include('unpermitted_params=["florb", "blarf"]')
      end

      it 'removes the thread local variable' do
        subscriber.request(event)
        expect(RequestStore.store[:lograge_unpermitted_params]).to be_nil
      end
    end

    it 'does not include unpermitted_params by default' do
      subscriber.request(event)
      expect(log_output.string).to_not include('unpermitted_params=')
    end
  end

  context 'with custom_options configured for lograge output' do
    before do
      Lograge.formatter = Lograge::Formatters::KeyValue.new
    end

    it 'combines the hash properly for the output' do
      Lograge.custom_options = { data: 'value' }
      subscriber.request(event)
      expect(log_output.string).to match(/ data=value/)
    end

    it 'combines the output of a lambda properly' do
      Lograge.custom_options = ->(_event) { { data: 'value' } }

      subscriber.request(event)
      expect(log_output.string).to match(/ data=value/)
    end
    it 'works when the method returns nil' do
      Lograge.custom_options = ->(_event) { nil }

      subscriber.request(event)
      expect(log_output.string).to be_present
    end
  end

  context 'when event payload includes a "custom_payload"' do
    before do
      Lograge.formatter = Lograge::Formatters::KeyValue.new
    end

    it 'incorporates the payload correctly' do
      event.payload[:custom_payload] = { data: 'value' }

      subscriber.request(event)
      expect(log_output.string).to match(/ data=value/)
    end

    it 'works when custom_payload is nil' do
      event.payload[:custom_payload] = nil

      subscriber.request(event)
      expect(log_output.string).to be_present
    end
  end

  context 'with before_format configured for lograge output' do
    before do
      Lograge.formatter = Lograge::Formatters::KeyValue.new
      Lograge.before_format = nil
    end

    it 'outputs correctly' do
      Lograge.before_format = ->(data, payload) { Hash[*data.first].merge(Hash[*payload.first]) }

      subscriber.request(event)

      expect(log_output.string).to include('method=GET')
      expect(log_output.string).to include('status=200')
    end
    it 'works if the method returns nil' do
      Lograge.before_format = ->(_data, _payload) { nil }

      subscriber.request(event)
      expect(log_output.string).to be_present
    end
  end

  context 'with ignore configured' do
    before do
      Lograge.ignore_nothing
    end

    it 'does not log ignored controller actions given a single ignored action' do
      Lograge.ignore_actions 'HomeController#index'
      subscriber.request(event)
      expect(log_output.string).to be_blank
    end

    it 'does not log ignored controller actions given a single ignored action after a custom ignore' do
      Lograge.ignore(->(_event) { false })

      Lograge.ignore_actions 'HomeController#index'
      subscriber.request(event)
      expect(log_output.string).to be_blank
    end

    it 'logs non-ignored controller actions given a single ignored action' do
      Lograge.ignore_actions 'FooController#bar'
      subscriber.request(event)
      expect(log_output.string).to be_present
    end

    it 'does not log ignored controller actions given multiple ignored actions' do
      Lograge.ignore_actions ['FooController#bar', 'HomeController#index', 'BarController#foo']
      subscriber.request(event)
      expect(log_output.string).to be_blank
    end

    it 'logs non-ignored controller actions given multiple ignored actions' do
      Lograge.ignore_actions ['FooController#bar', 'BarController#foo']
      subscriber.request(event)
      expect(log_output.string).to_not be_blank
    end

    it 'does not log ignored events' do
      Lograge.ignore(->(event) { 'GET' == event.payload[:method] })

      subscriber.request(event)
      expect(log_output.string).to be_blank
    end

    it 'logs non-ignored events' do
      Lograge.ignore(->(event) { 'foo' == event.payload[:method] })

      subscriber.request(event)
      expect(log_output.string).not_to be_blank
    end

    it 'does not choke on nil ignore_actions input' do
      Lograge.ignore_actions nil
      subscriber.request(event)
      expect(log_output.string).not_to be_blank
    end

    it 'does not choke on nil ignore input' do
      Lograge.ignore nil
      subscriber.request(event)
      expect(log_output.string).not_to be_blank
    end
  end

  it "will fallback to ActiveSupport's logger if one isn't configured" do
    Lograge.formatter = Lograge::Formatters::KeyValue.new
    Lograge.logger = nil
    ActiveSupport::LogSubscriber.logger = logger

    subscriber.request(event)

    expect(log_output.string).to be_present
  end
end
