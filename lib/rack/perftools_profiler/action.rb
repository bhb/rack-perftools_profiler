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
      password = request.GET['profile']
      klass =
        case request.path_info
        when %r{/__start__$}
          password_protected(StartProfiling, profiler, password)
        when %r{/__stop__$}
          password_protected(StopProfiling, profiler, password)
        when %r{/__data__$}
          password_protected(ReturnData, profiler, password)
        else
          if ProfileOnce.has_special_param?(request)
            password_protected(ProfileOnce, profiler, password)
          else
            CallAppDirectly
          end
        end
      klass.new(env, profiler, middleware)
    end

    private

    def self.password_protected(klass, profiler, password)
      if profiler.accepts?(password)
        klass
      else
        ReturnPasswordError
      end
    end

  end

end
