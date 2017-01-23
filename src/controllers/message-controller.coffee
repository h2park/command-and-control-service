class MessageController
  constructor: ({@messageService}) ->
    throw new Error 'Missing messageService' unless @messageService?

  create: (request, response) =>
    message = request.body
    { meshbluAuth, meshbluDevice } = request
    @messageService.create { meshbluAuth, meshbluDevice, message }, (error) =>
      return response.sendError(error) if error?
      response.sendStatus(200)

module.exports = MessageController
