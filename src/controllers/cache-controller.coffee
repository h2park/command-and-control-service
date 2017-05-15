CachedRequest = require '../helpers/cached-request'
CachedDevice  = require '../helpers/cached-device'

class CacheController
  constructor: ({@redis}) ->
    throw new Error 'Missing redis' unless @redis?
    @cachedRequest = new CachedRequest { @redis }
    @cachedDevice = new CachedDevice { meshblu: true, @redis }

  delete: (request, response) =>
    @cachedRequest.clearCache()
    @cachedDevice.clearCache()
    response.sendStatus 204

module.exports = CacheController
