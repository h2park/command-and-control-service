debug           = require('debug')('command-and-control:message-controller')
SimpleBenchmark = require 'simple-benchmark'

class MessageController
  constructor: ({@MessageService, @redis}) ->
    throw new Error 'Missing MessageService' unless @MessageService?
    throw new Error 'Missing redis' unless @redis?

  create: (request, response) =>
    debug 'messageController.create'
    data = request.body
    { timestampPath } = request.query
    { meshbluAuth, meshbluDevice } = request
    messageService = new @MessageService { meshbluAuth, data, device: meshbluDevice, timestampPath, @redis }
    benchmark = new SimpleBenchmark { label: 'process:total' }
    messageService.process { benchmark }, (error) =>
      debug 'done messageController.create'
      return response.sendError(error) if error?
      response.sendStatus(200)

module.exports = MessageController
