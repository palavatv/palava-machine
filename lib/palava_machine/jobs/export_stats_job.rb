require 'set'
require 'redis'
require 'mongo'

class ExportStatsJob
  class StatsExporter
    STATS_NAMESPACE = "store:stats"

    def initialize(redis_address, mongo_address)
      @redis = Redis.new(host: 'localhost', port: 6379)
      @mongo = Mongo::MongoClient.new#(mongo_address)
      @times = Set.new
    end

    def import_timestamps!(ns)
      redis_pattern = "#{STATS_NAMESPACE}:#{ns}:*"
      offset = redis_pattern.size - 1
      @times.merge @redis.keys(redis_pattern).map{ |key|
        key[offset..-1].to_i
      }
    end

    # remove timestamps which are not closed (+ grace time)
    def prune_timestamps!
      limit = Time.now.utc.to_i - 3660
      @times.select!{ |time| time < limit }
      puts "Transfering #{@times.length} timespans"
    end

    def store_in_mongo!
      collection = @mongo.db("plv_stats").collection("rtc")

      @times.each { |time|
        collection.insert(
          "c_at"            => time,
          "connection_time" => get_and_delete_from_redis("connection_time", time),
          "room_peaks"      => get_and_delete_from_redis("room_peaks",      time),
        )
      }
    end

    def get_and_delete_from_redis(ns, time)
      key = "#{STATS_NAMESPACE}:#{ns}:#{time}"
      data = @redis.hgetall(key) || {}
      @redis.del(key)
      data
    end
  end

  class << self
    def perform(redis_address = 'localhost:6379', mongo_address = 'localhost:27017')
      se = StatsExporter.new(redis_address, mongo_address)
      se.import_timestamps! "room_peaks"
      se.import_timestamps! "connection_time"
      se.prune_timestamps!
      se.store_in_mongo!
    end
  end
end
