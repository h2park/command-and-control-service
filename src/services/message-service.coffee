_ = require 'lodash'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'
cachedRequest = require '../helpers/cached-request'
debug = require('debug')('command-and-control:message-service')
debugError = require('debug')('command-and-control:user-errors')

class MessageService
  constructor: ({ @data, @device, @meshbluAuth }) ->
    { commandAndControl={} } = @device
    { @rulesets=@device.rulesets, @errorDeviceId } = commandAndControl
    @meshblu = new Meshblu @meshbluAuth

  process: (callback) =>
    debug 'messageService.create'
    done = (error) => return callback @_errorHandler(error)

    async.map @rulesets, @_getRuleset, (error, rulesMap) =>
      return done error if error?
      async.map _.flatten(rulesMap), @_doRule, (error, results) =>
        return done error if error?
        commands = _.flatten results
        commands = @_mergeCommands commands
        async.each commands, @_doCommand, done

  _mergeCommands: (commands) =>
    allUpdates = []
    mergedUpdates = {}
    _.each commands, (command) =>
      type = command.type
      uuid = command.params.uuid
      as = command.params.as
      operation = command.params.operation
      if type == 'meshblu' && operation != 'update'
        allUpdates.push command
        return

      key = _.compact([uuid, as, type, operation]).join('-')
      currentUpdate = mergedUpdates[key] ? command
      oldData = currentUpdate.params.data
      currentUpdate.params.data = _.merge oldData, command.params.data
      mergedUpdates[key] = currentUpdate

    return _.union allUpdates, _.values(mergedUpdates)

  _getRuleset: (ruleset, callback) =>
    @meshblu.device ruleset.uuid, (error, device) =>
      debug ruleset.uuid, error.message if error?.code == 404
      return callback @_addErrorContext(error, {ruleset}) if error?
      async.mapSeries device.rules, (rule, next) =>
        cachedRequest rule.url, (error, data) =>
          return next @_addErrorContext(error, {rule}), data
      , (error, rules) =>
        return callback error, _.flatten rules

  _doRule: (rulesConfig, callback) =>
    context = {@data, @device}
    engine = new MeshbluRulesEngine {meshbluConfig: @meshbluAuth, rulesConfig}
    engine.run context, (error, data) =>
      return callback @_addErrorContext(error, {rulesConfig, @data, @device}), data

  _doCommand: (command, callback) =>
    done = (error) => return callback @_addErrorContext(error, { command })
    return done new Error('unsupported command type') if command.type != 'meshblu'

    { params={} } = command
    options = {}
    options.as = params.as if params.as?
    { operation } = params

    return @_meshbluUpdate params, options, done if operation == 'update'
    return @_meshbluMessage params, options, done if operation == 'message'
    return done new Error('unsupported operation type')

  _meshbluUpdate: (params, options, callback) =>
    { uuid, data } = params
    return callback new Error('undefined uuid') unless uuid?
    return @meshblu.updateDangerously uuid, data, options, callback

  _meshbluMessage: (params, options, callback) =>
    { message } = params
    return callback new Error('undefined message') unless message?
    return @meshblu.message message, options, callback

  _addErrorContext: (error, context) =>
    return unless error?
    error.context ?= {}
    error.context = _.merge error.context, context
    return error

  _errorHandler: (error) =>
    return unless error?
    @_sendError error
    error.code = 422
    return error

  _sendError: (error) =>
    errorMessage =
      devices: [ @errorDeviceId ]
      error:
        stack: error.stack?.split('\n')
        context: error.context
        code: error.code
      input: {@data, deviceUuid: @device.uuid}

    debugError JSON.stringify({errorMessage},null,2)
    return unless @errorDeviceId?
    errorMessage.input = {@data, @device}

    @meshblu.message errorMessage, (error) =>
      return unless error?
      debug 'could not forward error message to meshblu'

module.exports = MessageService
