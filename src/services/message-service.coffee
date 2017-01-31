_ = require 'lodash'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'
debug = require('debug')('command-and-control:message-service')
cachedRequest = require '../helpers/cached-request'

class MessageService
  create: ({ data, meshbluAuth, device }, callback) =>
    debug 'messageService.create'
    debug { data, device }
    { rulesets } = device
    meshblu = new Meshblu meshbluAuth
    async.map rulesets, async.apply(@_getRuleset, meshblu), (error, rulesMap) =>
      return callback error if error?
      async.map _.flatten(rulesMap), async.apply(@_doRule, {data, device}, meshbluAuth), (error, results) =>
        return callback error if error?
        commands = _.flatten results
        commands = @_mergeCommands commands
        async.each commands, async.apply(@_doCommand, meshblu), callback

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

  _getRuleset: (meshblu, rule, callback) =>
    meshblu.device rule.uuid, (error, device) =>
      return callback error if error?
      async.mapSeries device.rules, (rule, next) =>
        cachedRequest rule.url, next
      , (error, rules) =>
        return callback error if error?
        return callback null, _.flatten rules

  _doRule: (context, meshbluConfig, rulesConfig, callback) =>
    engine = new MeshbluRulesEngine {meshbluConfig, rulesConfig}
    engine.run context, callback

  _doCommand: (meshblu, command, callback) =>
    return callback @_createError('unknown command type', command, 422) if command.type != 'meshblu'

    options = {}
    options.as = command.params.as if command.params.as?

    if command.params.operation == 'update'
      return callback @_createError('invalid uuid', command, 422) unless command.params.uuid?
      debug 'sending meshblu update'
      return meshblu.updateDangerously command.params.uuid, command.params.data, options, (error) =>
        debug 'done meshblu update'
        debug {error} if error?
        callback error

    if command.params.operation == 'message'
      debug 'sending meshblu message'
      return meshblu.message command.params.message, options, (error) =>
        debug 'done meshblu message'
        debug {error} if error?
        callback error

    return callback @_createError('unsupported operation type', command, 422)

  _createError: (message, command, code=500) =>
    debug message
    debug JSON.stringify(command, null, 2)
    error = new Error message
    error.code = code
    return error

module.exports = MessageService
