module Rack::PerftoolsProfiler

  class ProfileDataAction < Action
    
    def check_printer_arg
      request = Rack::Request.new(@env)
      printer = request.GET['printer']
      self.class.check_printer(printer, @env)
    end

    def self.check_printer(printer, env=nil)
      if printer != nil && !ProfilerMiddleware::PRINTERS.member?(printer.to_sym)
        message = "Invalid printer type: #{printer}. Valid printer values are #{ProfilerMiddleware::PRINTERS.join(", ")}" 
        raise ProfilerArgumentError, message
      end
    end

  end

end
