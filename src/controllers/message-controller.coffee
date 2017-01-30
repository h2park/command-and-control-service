debug = require('debug')('command-and-control:message-controller')

class MessageController
  constructor: ({@messageService}) ->
    throw new Error 'Missing messageService' unless @messageService?

  create: (request, response) =>
    debug 'messageController.create'
    data = request.body
    { meshbluAuth, meshbluDevice } = request
    @messageService.create { meshbluAuth, data, device: meshbluDevice }, (error) =>
      debug 'done messageController.create'
      return response.sendError(error) if error?
      response.sendStatus(200)

module.exports = MessageController
