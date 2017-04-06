enableDestroy      = require 'server-destroy'
octobluExpress     = require 'express-octoblu'
Router             = require './router'
MessageService     = require './services/message-service'
Redis              = require 'ioredis'

class Server
  constructor: ({ @disableLogging, @port, @meshbluConfig, @redisUri })->
    throw new Error 'Missing meshbluConfig' unless @meshbluConfig?

  address: =>
    @server.address()

  run: (callback) =>
    @redis = new Redis @redisUri, keyPrefix: 'command-and-control:', dropBufferSupport: true

    app = octobluExpress({ @disableLogging })

    router = new Router { @redis, @meshbluConfig, MessageService }
    router.route app

    @server = app.listen @port, callback
    enableDestroy @server

  stop: (callback) =>
    @server.close callback

  destroy: =>
    @server.destroy()

module.exports = Server
