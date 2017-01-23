MessageController = require './controllers/message-controller'

class Router
  constructor: ({ @messageService }) ->
    throw new Error 'Missing messageService' unless @messageService?

  route: (app) =>
    messageController = new MessageController { @messageService }

    app.post '/v1/messages', messageController.create

module.exports = Router
