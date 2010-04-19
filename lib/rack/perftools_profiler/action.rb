module Rack::PerftoolsProfiler
  
  class Action

    def initialize(env, profiler, middleware)
      @env = env
      @request = Rack::Request.new(env)
      @data_params = @request.params.clone
      @profiler = profiler
      @middleware = middleware
    end
    
    def act
      # do nothing
    end

    def self.for_env(env, profiler, middleware)
      request = Rack::Request.new(env)
      klass = 
        case request.path
        when '/__start__'
          StartProfiling
        when '/__stop__'
          StopProfiling
        when '/__data__'
          ReturnData
        else
          if ProfileOnce.has_special_param?(request)
            ProfileOnce
          else
            CallAppDirectly
          end
        end
      klass.new(env, profiler, middleware)
    end

  end

end
