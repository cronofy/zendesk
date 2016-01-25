class DelayedJobLogger
  include Hatchet

  [:debug, :info, :warn, :error, :fatal].each do |level|
    define_method(level) do |message|
      log.add(level, message)
    end
  end
end

Delayed::Worker.logger = DelayedJobLogger.new
