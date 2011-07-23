module Rack::PerftoolsProfiler

  class ProfilerArgumentError < RuntimeError; end;

  class ProfilerMiddleware
    include Rack::Utils

    PRINTER_CONTENT_TYPE = {
      :text => 'text/plain',
      :gif => 'image/gif',
      :pdf => 'application/pdf',
      :callgrind => 'text/plain',
      :raw => 'application/octet-stream'
    }
    
    PRINTERS = PRINTER_CONTENT_TYPE.keys
    
    def initialize(app, options = {})
      @app = app
      @profiler = Profiler.new(@app, options.clone)
    end

    def call(env)
      @env = env.clone
      action = Action.for_env(@env, @profiler, self)
      action.act
      action.response
    rescue ProfilerArgumentError => err
      @env['rack.errors'].write(err.message)
      [400, {'Content-Type' => 'text/plain'}, [err.message]]
    rescue ProfilingError => err
      @env['rack.errors'].write(err.message + "\n" + err.stderr)
      [500, {'Content-Type' => 'text/plain'}, [err.message+"\n\n", "Standard error:\n"+err.stderr+"\n"]]
    end

    def call_app(env)
      @app.call(env)
    end

    def force_stop
      @profiler.stop
    end

    def profiler_data_response(profiling_data)
      format, body = profiling_data
      body = Array(body)
      if format==:none
        message = 'No profiling data available. Visit /__stop__ and then visit /__data__'
        [404, {'Content-Type' => 'text/plain'}, [message]]
      else
        [200, headers(format, body), Array(body)]
       end
    end

    private

    def headers(printer, body)
      headers = { 
        'Content-Type' => PRINTER_CONTENT_TYPE[printer],
        'Content-Length' => content_length(body)
      }
      if printer==:pdf || printer ==:raw
        filetype = printer
        filename='profile_data'
        headers['Content-Disposition'] = %(attachment; filename="#{filename}.#{filetype}")
      end
      headers
    end

    def content_length(body)
      body.inject(0) { |len, part| len + bytesize(part) }.to_s
    end

  end

end
