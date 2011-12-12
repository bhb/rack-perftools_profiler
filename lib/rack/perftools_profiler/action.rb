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
      accepted = profiler.accepts?(password)
      klass =
        case request.path_info
        when %r{/__start__$}
          password_protect(StartProfiling, accepted)
        when %r{/__stop__$}
          password_protect(StopProfiling, accepted)
        when %r{/__data__$}
          password_protect(ReturnData, accepted)
        else
          if ProfileOnce.has_special_param?(request)
            password_protect(ProfileOnce, accepted)
          else
            CallAppDirectly
          end
        end
      klass.new(env, profiler, middleware)
    end

    private

    def self.password_protect(klass, accepted)
      accepted ? klass : ReturnPasswordError
    end

  end

end
