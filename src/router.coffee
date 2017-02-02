MessageController = require './controllers/message-controller'

class Router
  constructor: ({ @MessageService }) ->
    throw new Error 'Missing MessageService' unless @MessageService?

  route: (app) =>
    messageController = new MessageController { @MessageService }
    app.post '/v1/messages', messageController.create

module.exports = Router
