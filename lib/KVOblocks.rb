module KVOblocks

  class Observer
    attr_reader :observee, :path

    def initialize(object, path, async, opts, block)
      @observee = object
      @path = path
      @async = async
      @block = block		  
    end

    def observeValueForKeyPath(path, ofObject:object, change:change, context:context)
      if @async
        Dispatch::Queue.concurrent.async { @block.call(object, change) } 
      else
        @block.call(object, change) 
      end
    end
  end


  class ObjectObserver < Observer

    def initialize(object, path, async, opts, block)
      super
      @observee.addObserver(self, forKeyPath:path, options:opts, context:nil)
    end

    def cancel_observation
      @observee.removeObserver(self, forKeyPath:@path)
    end
  end


  class ArrayObserver < Observer

    def initialize(object, indexes, path, async, opts, block)
      super(object, path, async, opts, block)
      @observee.addObserver(self, toObjectsAtIndexes:indexes, forKeyPath:path, options:opts, context:nil)
    end

    def cancel_observation_for_objects_at_indexes(indexes)
      @observee.removeObserver(self, fromObjectsAtIndexes:indexes, forKeyPath:@path)
    end
  end


  SERIAL_QUEUE = Dispatch::Queue.new("serial_queue.kvoblocks")

  module ObserveObject

    # opts hash can contain the following keys and values:
    # key, :async – should the block be run syncronously or asyncronously? true or false
    # key, :options – key value observing options
    # NSKeyValueObservingOptions are defined here: http://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Protocols/NSKeyValueObserving_Protocol/Reference/Reference.html
    def add_observer_for_key_path(path, opts={}, &block)
      SERIAL_QUEUE.sync do
        (@__observers_array__ ||= []) << ObjectObserver.new(self, path, opts[:async], opts[:options]||0, block)
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

  module ObserveArrayContents

    # in addition to the hash opts explained above in ObserveObject module, there is a :range option
    # the value of the :range key must be a Range or NSRange object
    # it specifies which objects of the array will be observed
    # if no value is given, all objects will be observed

    def add_observer_to_objects_for_key_path(path, opts={}, &block)
      SERIAL_QUEUE.sync do
        range = if opts[:range].nil?
          NSRange.new(0,size)
        elsif opts[:range].is_a?(Range)
          opts[:range].NSRange_for_array(self)
        else
          opts[:range]
        end
        indexes = NSIndexSet.indexSetWithIndexesInRange(range)
        (@__observers_array__ ||= []) << ArrayObserver.new(self, indexes, path, opts[:async], opts[:options]||0, block)
      end
    end
    
    def remove_observer_for_key_path(path, range = NSRange.new(0, size))
      SERIAL_QUEUE.sync do
        indexes = NSIndexSet.indexSetWithIndexesInRange(range.is_a?(Range) ? range.NSRange_for_array(self) : range)
        observer = @__observers_array__.find {|o| o.path == path && o.observee == self} if @__observers_array__
        @__observers_array__.delete(observer) and observer.cancel_observation_for_objects_at_indexes(indexes) if observer
      end
    end

    def remove_all_observers(range = NSRange.new(0, size))
      SERIAL_QUEUE.sync do
        if @__observers_array__
          indexes = NSIndexSet.indexSetWithIndexesInRange(range.is_a?(Range) ? range.NSRange_for_array(self) : range)
          @__observers_array__.each { |e| e.cancel_observation_for_objects_at_indexes(indexes) } and @__observers_array__.clear
        end
      end
    end
  end
  
  
  module RangeToNSRange
    def NSRange_for_array(array)
      length = last < 0 ? array.size-first+last : last-first
      NSRange.new(first, exclude_end? ? length : length+1)
    end
  end

end


class Range
  include KVOblocks::RangeToNSRange
end

class Object
  include KVOblocks::ObserveObject
end

class Array
  include KVOblocks::ObserveArrayContents
end