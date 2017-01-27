request = require 'request'

CACHE = {
  responses: {}
}

cachedRequest = (url, callback) =>
  return callback null, CACHE.responses[url] if CACHE.responses[url]?

  request.get url, json: true, (error, response, body) =>
    return callback error if error?
    return callback new Error "Unexpected non 2xx status code: #{response.statusCode}" unless response.statusCode < 300
    CACHE.responses[url] = body
    return callback error, body

cachedRequest.clearCache = -> CACHE.responses = {}
module.exports = cachedRequest
