MeshbluConfig  = require 'meshblu-config'
SigtermHandler = require 'sigterm-handler'
Server         = require './src/server'

class Command
  constructor: ->
    @serverOptions = {
      meshbluConfig:  new MeshbluConfig().toJSON()
      port:           process.env.PORT || 80
      disableLogging: process.env.DISABLE_LOGGING == "true"
      redisUri:       process.env.REDIS_URI
    }

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    @panic(new Error('REDIS_URI is required')) unless @serverOptions.redisUri
    server = new Server @serverOptions
    server.run (error) =>
      return @panic error if error?

      {port} = server.address()
      console.log "CommandAndControlService listening on port: #{port}"

    sigtermHandler = new SigtermHandler { events: ['SIGTERM', 'SIGINT'] }
    sigtermHandler.register server?.stop

command = new Command()
command.run()
