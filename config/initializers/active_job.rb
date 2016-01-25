class ActiveJobLogger
  include Hatchet

  [:debug, :info, :warn, :error, :fatal].each do |level|
    define_method(level) do |message|
      log.add(level, message)
    end
  end
end

ActiveJob::Base.logger = ActiveJobLogger.new
