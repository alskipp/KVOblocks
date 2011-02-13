module KVOblocks

  class Observer

    attr_reader :observee, :path

    def initialize(object, path, async, opts, block)
      @observee = object
      @path = path
      @async = async
      @block = block		  
      @observee.addObserver(self, forKeyPath:path, options:opts, context:nil)
    end

    def observeValueForKeyPath(path, ofObject:object, change:change, context:context)
      if @async
        Dispatch::Queue.concurrent.async { @block.call(object, change) } 
      else
        @block.call(object, change) 
      end
    end

    def cancel_observation
      @observee.removeObserver(self, forKeyPath:@path)
    end
  end

  SERIAL_QUEUE = Dispatch::Queue.new("serial_queue.kvoblocks")

  def add_observer_for_key_path(path, opts={}, &block)
    SERIAL_QUEUE.sync do
      (@__observers_array__ ||= []) << Observer.new(self, path, opts[:async], opts[:options]||0, block)
    end
  end

  def remove_observer_for_key_path(path)
    SERIAL_QUEUE.sync do
      observer = @__observers_array__.find {|o| o.path == path && o.observee == self} if @__observers_array__
      @__observers_array__.delete(observer) and observer.cancel_observation if observer
    end
  end

  def remove_all_observers
    SERIAL_QUEUE.sync do
      @__observers_array__.each { |e| e.cancel_observation } and @__observers_array__.clear if @__observers_array__
    end
  end

end