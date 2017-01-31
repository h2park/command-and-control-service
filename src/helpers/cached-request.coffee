request = require 'request'

CACHE = {
  responses: {}
}

cachedRequest = (url, callback) =>
  # return callback null, CACHE.responses[url] if CACHE.responses[url]?

  request.get url, json: true, (error, response, body) =>
    return callback error if error?
    if response.statusCode > 299
      error = new Error "Unexpected non 2xx status code: #{response.statusCode}"
      error.code = response.statusCode
      return callback error
    CACHE.responses[url] = body
    return callback error, body

cachedRequest.clearCache = -> CACHE.responses = {}
module.exports = cachedRequest
