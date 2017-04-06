_ = require 'lodash'

class CachedDevice
  constructor: (options={}) ->
    { @meshblu, @redis } = options
    throw new Error 'CachedDevice requires meshblu' unless @meshblu?
    throw new Error 'CachedDevice requires redis' unless @redis?

  get: (uuid, callback) =>
    @redis.get "cache:device:#{uuid}", (error, result) =>
      return callback error if error?
      return callback null, JSON.parse(result) if result?
      @_get uuid, (error, device) =>
        return callback error if error?
        @redis.setex "device:#{uuid}", 300, JSON.stringify(device), (error) =>
          callback error, device

  clearCache: =>
    @redis.keys 'command-and-control:cache:device:*', (error, keys) =>
      console.error error if error?
      return if _.isEmpty keys
      @redis.del keys

  _get: (uuid, callback) =>
    @meshblu.device uuid, (error, device) =>
      return callback error if error?
      callback null, device

module.exports = CachedDevice
