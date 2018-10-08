describe Lograge::ActionControllerLogSubscriber do
  let(:event_params) { { 'foo' => 'bar' } }
  let(:subscriber)   { described_class.new }

  let(:event) do
    ActiveSupport::Notifications::Event.new(
      'process_action.action_controller',
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

  context 'when processing a redirect' do
    let(:redirect_event) do
      ActiveSupport::Notifications::Event.new(
        'redirect_to.action_controller',
        Time.now,
        Time.now,
        1,
        location: 'http://example.com',
        status: 302
      )
    end

    it 'stores the location in a thread local variable' do
      subscriber.redirect_to(redirect_event)
      expect(RequestStore.store[:lograge_location]).to eq('http://example.com')
    end
  end

  context 'when processing unpermitted parameters' do
    let(:unpermitted_parameters_event) do
      ActiveSupport::Notifications::Event.new(
        'unpermitted_parameters.action_controller',
        Time.now,
        Time.now,
        1,
        keys: %w(foo bar)
      )
    end

    it 'stores the parameters in a thread local variable' do
      subscriber.unpermitted_parameters(unpermitted_parameters_event)
      expect(RequestStore.store[:lograge_unpermitted_params]).to eq(%w(foo bar))
    end
  end
end
