module Rack::PerftoolsProfiler
  
  class Action

    def initialize(env, profiler, middleware)
      @env = env
      @request = Rack::Request.new(env)
      @get_params = @request.GET.clone
      @profiler = profiler
      @middleware = middleware
    end
    
    def act
      # do nothing
    end

    def self.for_env(env, profiler, middleware)
      request = Rack::Request.new(env)
      klass = 
        if ENV["PROFILE_PASSWORD"] && request.GET['profile'] != ENV["PROFILE_PASSWORD"]
          CallAppDirectly
        else
          case request.path_info
          when %r{/__start__$}
            StartProfiling
          when %r{/__stop__$}
            StopProfiling
          when %r{/__data__$}
            ReturnData
          else
            if ProfileOnce.has_special_param?(request)
              ProfileOnce
            else
              CallAppDirectly
            end
          end
        end
      klass.new(env, profiler, middleware)
    end

  end

end
