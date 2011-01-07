require 'test_helper'

class RackPerftoolsProfilerTest < Test::Unit::TestCase
  include Rack::PerftoolsProfiler

  context "testing Rack::PerftoolsProfiler" do

    setup do
      @app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['Oh hai der']] }
      @slow_app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['slow app']] }
      @start_env = Rack::MockRequest.env_for('/__start__')
      @stop_env = Rack::MockRequest.env_for('/__stop__')
      @data_env = Rack::MockRequest.env_for('/__data__')
      @root_request_env = Rack::MockRequest.env_for("/")    
      @profiled_request_env = Rack::MockRequest.env_for("/", :params => "profile=true")
      @profiled_request_env_with_times = Rack::MockRequest.env_for("/", :params => "profile=true&times=2")
    end

    context 'Rack::Lint checks' do

      should 'pass all Lint checks with text printer' do
        app = Rack::Lint.new(Rack::PerftoolsProfiler.with_profiling_off(@slow_app, :default_printer => 'text'))
        app.call(@root_request_env)
        app.call(@profiled_request_env)
        app.call(@profiled_request_env_with_times)
        app.call(@start_env)
        app.call(@stop_env)
        app.call(@data_env)
      end

      should 'pass all Lint checks with gif printer' do
        app = Rack::Lint.new(Rack::PerftoolsProfiler.with_profiling_off(@slow_app, :default_printer => 'gif'))
        app.call(@root_request_env)
        app.call(@profiled_request_env)
        app.call(@profiled_request_env_with_times)
        app.call(@start_env)
        app.call(@stop_env)
        app.call(@data_env)
      end

    end

    should 'raise error if options contains invalid key' do
      error = assert_raises ProfilerArgumentError do 
        Rack::PerftoolsProfiler.with_profiling_off(@app, :mode => 'walltime', :default_printer => 'gif', :foobar => 'baz')
      end
      assert_match(/Invalid option\(s\)\: foobar/, error.message)
    end
    
    should 'raise error if printer is invalid' do
      error = assert_raises ProfilerArgumentError do 
        Rack::PerftoolsProfiler.with_profiling_off(@app, :mode => 'walltime', :default_printer => 'badprinter')
      end
      assert_match(/Invalid printer type\: badprinter/, error.message)
    end
    
    should 'not modify options hash' do
      options = {:mode => 'walltime', :default_printer => 'gif'}
      old_options = options.clone
      Rack::PerftoolsProfiler.with_profiling_off(@app, options)
      assert_equal old_options, options
    end

    context 'when not profiling' do

      should 'call app directly' do
        status, headers, body = Rack::PerftoolsProfiler.with_profiling_off(@app).call(@root_request_env)
        assert_equal 200, status
        assert_equal 'text/plain', headers['Content-Type']
        assert_equal 'Oh hai der', RackResponseBody.new(body).to_s
      end
      
      should 'provide no data by default when __data__ is called' do
        Rack::PerftoolsProfiler.clear_data
        status, headers, body = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text').call(@data_env)
        assert_equal 404, status
        assert_equal 'text/plain', headers['Content-Type']
        assert_match(/No profiling data available./, RackResponseBody.new(body).to_s)
      end

    end

  end

end
