require 'test_helper'

class MultipleRequestProfilingTest < Test::Unit::TestCase
  include Rack::PerftoolsProfiler

  def setup
    @app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['Oh hai der']] }
    @slow_app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['slow app']] }
    @start_env = Rack::MockRequest.env_for('/__start__')
    @stop_env = Rack::MockRequest.env_for('/__stop__')
    @data_env = Rack::MockRequest.env_for('/__data__')
    @root_request_env = Rack::MockRequest.env_for("/")    
  end

  def profile_requests(profiled_app, requests, options = {})
    get_data = options.fetch(:get_data) { true }
    if requests == :default
      requests = [@root_request_env]
    else
      requests = Array(requests)
    end
    profiled_app.call(@start_env)
    requests.each do |request|
      profiled_app.call(request)
    end
    profiled_app.call(@stop_env)
    profiled_app.call(@data_env) if get_data
  end

  should 'default to text printer' do
    _, headers, _ = profile_requests(Rack::PerftoolsProfiler.new(@app), :default)
    assert_equal "text/plain", headers['Content-Type']
  end

  should "set CPUPROFILE_REALTIME to 1 if mode is 'walltime' " do
    realtime = ENV['CPUPROFILE_REALTIME']
    assert_nil realtime
    app = lambda do |env|
      realtime = ENV['CPUPROFILE_REALTIME']
      [200, {}, ["hi"]]
    end
    profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'walltime')
    profile_requests(profiled_app, :default, :get_data => false)
    assert_equal '1', realtime
  end

  should "set CPUPROFILE_OBJECTS to 1 if mode is 'objects'" do
    objects = ENV['CPUPROFILE_OBJECTS']
    assert_nil objects
    app = lambda do |env|
      objects = ENV['CPUPROFILE_OBJECTS']
      [200, {}, ["hi"]]
    end
    profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'objects')
    profile_requests(profiled_app, :default, :get_data => false)
    assert_equal '1', objects
  end

  should "not set CPUPROFILE_FREQUENCY by default" do
    frequency = ENV['CPUPROFILE_FREQUENCY']
    assert_nil frequency
    app = lambda do |env|
      frequency = ENV['CPUPROFILE_FREQUENCY']
      [200, {}, ["hi"]]
    end
    profiled_app = Rack::PerftoolsProfiler.new(app)
    profile_requests(profiled_app, :default, :get_data => false)
    assert_nil frequency
  end

  should 'alter CPUPROFILE_FREQUENCY if frequency is set' do
    frequency = ENV['CPUPROFILE_FREQUENCY']
    assert_nil frequency
    app = lambda do |env|
      frequency = ENV['CPUPROFILE_FREQUENCY']
      [200, {}, ["hi"]]
    end
    profiled_app = Rack::PerftoolsProfiler.new(app, :frequency => 250)
    profiled_app.call(@start_env)
    profiled_app.call(@root_request_env)
    assert_equal '250', frequency
  end

  context 'when profiling is on' do

    should 'not provide profiling data when __data__ is called' do
      Rack::PerftoolsProfiler.clear_data
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      status, _, body = profiled_app.call(@data_env)
      assert_equal 400, status
      assert_match(/No profiling data available./, RackResponseBody.new(body).to_s)
    end

    should 'pass on profiling params in environment' do
      env = Rack::MockRequest.env_for('/', :params => 'times=2')
      old_env = env.clone
      app = @app.clone
      expected_env = env.clone
      expected_env['rack.request.query_string'] = 'times=2'
      expected_env['rack.request.query_hash'] = {'times' => '2'}
      app.expects(:call).with(expected_env)
      profiled_app = Rack::PerftoolsProfiler.new(app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(env)
      assert_equal env, old_env
    end

    should 'pass on non-profiling params in environment' do
      env = Rack::MockRequest.env_for('/', :params => 'param=value')
      old_env = env.clone
      app = @app.clone
      expected_env = env.clone
      expected_env['rack.request.query_string'] = 'param=value'
      expected_env['rack.request.query_hash'] = {'param' => 'value'}
      app.expects(:call).with(expected_env)
      profiled_app = Rack::PerftoolsProfiler.new(app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(env)
      assert_equal env, old_env
    end

    should 'not alter regular calls' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'gif')
      profiled_app.call(@start_env)
      status, headers, body = profiled_app.call(@root_request_env)
      assert_equal 200, status
      assert_equal 'text/plain', headers['Content-Type']
      assert_equal 'Oh hai der', RackResponseBody.new(body).to_s
    end

  end

  context 'after profiling is finished' do

    should 'return profiling data when __data__ is called' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'gif')
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      profiled_app.call(@stop_env)
      status, headers, body = profiled_app.call(@data_env)
      assert_equal 200, status
      assert_equal "image/gif", headers['Content-Type']
    end

  end
  
  should 'keeps data from multiple calls' do
    profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
    profiled_app.call(@start_env)
    profiled_app.call(Rack::MockRequest.env_for('/method1'))
    profiled_app.call(Rack::MockRequest.env_for('/method2'))
    profiled_app.call(@stop_env)
    status, headers, body = profiled_app.call(@data_env)
    assert_match(/method1/, RackResponseBody.new(body).to_s)
    assert_match(/method2/, RackResponseBody.new(body).to_s)
  end

  should "allow 'printer' param to override :default_printer option'" do
    profiled_app = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf')
    profiled_app.call(@start_env)
    profiled_app.call(@root_request_env)
    profiled_app.call(@stop_env)
    custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'printer=gif')
    _, headers, _ = profiled_app.call(custom_data_env)
    assert_equal 'image/gif', headers['Content-Type']
  end

  should "accept 'focus' param" do
    profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
    profiled_app.call(@start_env)
    profiled_app.call(Rack::MockRequest.env_for('/method1'))
    profiled_app.call(Rack::MockRequest.env_for('/method2'))
    profiled_app.call(@stop_env)
    custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'focus=method1')
    status, headers, body = profiled_app.call(custom_data_env)
    assert_no_match(/method2/, RackResponseBody.new(body).to_s)
  end

  should "accept 'ignore' param" do
    profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
    profiled_app.call(@start_env)
    profiled_app.call(Rack::MockRequest.env_for('/method1'))
    profiled_app.call(Rack::MockRequest.env_for('/method2'))
    profiled_app.call(@stop_env)
    custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'ignore=method1')
    status, headers, body = profiled_app.call(custom_data_env)
    assert_no_match(/method1/, RackResponseBody.new(body).to_s)
  end

end
