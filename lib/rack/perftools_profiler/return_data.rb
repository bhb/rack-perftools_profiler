module Rack::PerftoolsProfiler

  class ReturnData < ProfileDataAction

    def initialize(*args)
      super
      check_printer_arg
    end

    def response
      if @profiler.profiling?
        [400, {'Content-Type' => 'text/plain'}, ["No profiling data available yet.\nVisit to /__stop__ to finish profiling."]]
      else
        @middleware.profiler_data_response(@profiler.data(@data_params))
      end
    end

  end

end
