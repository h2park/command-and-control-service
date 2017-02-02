debug = require('debug')('command-and-control:message-controller')

class MessageController
  constructor: ({@MessageService}) ->
    throw new Error 'Missing MessageService' unless @MessageService?

  create: (request, response) =>
    debug 'messageController.create'
    data = request.body
    { meshbluAuth, meshbluDevice } = request
    messageService = new @MessageService { meshbluAuth, data, device: meshbluDevice }
    messageService.process (error) =>
      debug 'done messageController.create'
      return response.sendError(error) if error?
      response.sendStatus(200)

module.exports = MessageController
