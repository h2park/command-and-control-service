request   = require 'request'
NodeCache = require 'node-cache'
debug     = require('debug')('command-and-control:cache-request')
cache  = new NodeCache {
  stdTTL:      3600,
  checkperiod: 1800,
}

class CachedDevice
  constructor: (options={}) ->
    { @meshblu } = options
    @_cache = cache

  get: (uuid, callback) =>
    debug @stats()
    @_cache.get uuid, (error, result) =>
      return callback error if error?
      return callback null, result if result?
      @_get uuid, (error, device) =>
        return callback error if error?
        @_cache.set uuid, device, (error) =>
          callback error, device

  clearCache: =>
    @_cache.flushAll()

  stats: =>
    @_cache.getStats()

  _get: (uuid, callback) =>
    @meshblu.device uuid, (error, device) =>
      return callback error if error?
      callback null, device

module.exports = CachedDevice
