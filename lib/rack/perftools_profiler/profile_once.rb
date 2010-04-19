module Rack::PerftoolsProfiler

  class ProfileOnce < ProfileDataAction
    include Rack::Utils

    def self.has_special_param?(request)
      request.params['profile'] != nil
    end

    def initialize(*args)
      super
      request = Rack::Request.new(@env)
      @times = (request.params.fetch('times') {1}).to_i
      check_printer_arg
      @new_env = delete_custom_params(@env)
    end
    
    def act
      @profiler.profile do
        @times.times { @middleware.call_app(@new_env) }
      end
    end

    def response
      @middleware.profiler_data_response(@profiler.data(@data_params))
    end

    def delete_custom_params(env)
      new_env = env.clone
      
      params = Rack::Request.new(new_env).params
      params.delete('profile')
      params.delete('times')
      params.delete('printer')
      params.delete('ignore')
      params.delete('focus')

      new_env.delete('rack.request.query_string')
      new_env.delete('rack.request.query_hash')

      new_env['QUERY_STRING'] = build_query(params)
      new_env
    end

  end

end
