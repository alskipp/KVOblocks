module KVOblocks

  class Observer

    attr_reader :observee, :path
    
    def initialize(object, path, async, block, opts=0)
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
  
  def add_observer_for_key_path(path, &block)
    (@__observers_array__ ||= []) << Observer.new(self, path, false, block)
  end

  def add_observer_for_key_path(path, async:async, &block)
    (@__observers_array__ ||= []) << Observer.new(self, path, async, block)
  end

  def add_observer_for_key_path(path, async:async, options:opts, &block)
    (@__observers_array__ ||= []) << Observer.new(self, path, async, block, opts)
  end

  def remove_observer_for_key_path(path)
    observer = @__observers_array__.find {|o| o.path == path && o.observee == self} if @__observers_array__
    @__observers_array__.delete(observer) and observer.cancel_observation if observer
  end
  
  def remove_all_observers
    @__observers_array__.each { |e| e.cancel_observation } and @__observers_array__.clear if @__observers_array__
  end

end