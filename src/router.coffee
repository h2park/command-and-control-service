MeshbluAuth        = require 'express-meshblu-auth'
CacheController = require './controllers/cache-controller'
MessageController = require './controllers/message-controller'

class Router
  constructor: ({ @meshbluConfig, @MessageService, @redis }) ->
    throw new Error 'Missing MessageService' unless @MessageService?
    throw new Error 'Missing meshbluConfig' unless @meshbluConfig?
    throw new Error 'Missing redis' unless @redis?

  route: (app) =>
    meshbluAuth = new MeshbluAuth @meshbluConfig
    cacheController = new CacheController { @redis }
    messageController = new MessageController { @MessageService, @redis }

    # Unauthenticated requests
    app.delete '/cache', cacheController.delete

    # Authenticated requests
    app.use meshbluAuth.get()
    app.use meshbluAuth.gateway()
    app.post '/v1/messages', messageController.create

module.exports = Router
