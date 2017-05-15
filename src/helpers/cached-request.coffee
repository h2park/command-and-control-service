_         = require 'lodash'
request   = require 'request'
debug     = require('debug')('command-and-control:cache-request')

class CachedRequest
  constructor: (options={}) ->
    { @redis } = options
    throw new Error 'CachedRequest requires redis' unless @redis?

  get: (url, callback) =>
    @redis.get "cache:url:#{url}", (error, result) =>
      return callback error if error?
      return callback null, JSON.parse(result) if result?
      @_get url, (error, body) =>
        return callback error if error?
        @redis.setex "cache:url:#{url}", 300, JSON.stringify(body), (error) =>
          callback error, body

  clearCache: =>
    @redis.keys 'command-and-control:cache:url:*', (error, keys) =>
      console.error error if error?
      return if _.isEmpty keys
      @redis.del keys

  _get: (url, callback) =>
    request.get url, { gzip: true, json: true }, (error, response, body) =>
      return callback error if error?
      if response.statusCode > 299
        error = new Error "Unexpected non 2xx status code: #{response.statusCode}"
        error.code = response.statusCode
        return callback error
      callback null, body

module.exports = CachedRequest
