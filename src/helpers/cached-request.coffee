request   = require 'request'
NodeCache = require 'node-cache'
debug     = require('debug')('command-and-control:cache-request')

class CacheRequest
  constructor: ->
    @_cache  = new NodeCache {
      stdTTL:      360,
      checkperiod: 180,
    }

  get: (url, callback) =>
    debug @stats()
    @_cache.get url, (error, result) =>
      return callback error if error?
      return callback null, result if result?
      @_get url, (error, body) =>
        return callback error if error?
        @_cache.set url, body, (error) =>
          callback error, body

  clearCache: =>
    @_cache.flushAll()

  stats: =>
    @_cache.getStats()

  _get: (url, callback) =>
    request.get url, { gzip: true, json: true }, (error, response, body) =>
      return callback error if error?
      if response.statusCode > 299
        error = new Error "Unexpected non 2xx status code: #{response.statusCode}"
        error.code = response.statusCode
        return callback error
      callback null, body

module.exports = new CacheRequest
