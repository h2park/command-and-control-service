_ = require 'lodash'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'
debug = require('debug')('command-and-control:message-service')
cachedRequest = require '../helpers/cached-request'

class MessageService
  create: ({ data, meshbluAuth, device }, callback) =>
    { rulesets } = device
    meshblu = new Meshblu meshbluAuth
    async.map rulesets, async.apply(@_getRuleset, meshblu), (error, rulesMap) =>
      return callback error if error?
      async.map _.flatten(rulesMap), async.apply(@_doRule, {data, device}, meshbluAuth), (error, results) =>
        return callback error if error?
        commands = _.flatten results
        async.each commands, async.apply(@_doCommand, meshblu), callback

  _getRuleset: (meshblu, rule, callback) =>
    meshblu.device rule.uuid, (error, device) =>
      return callback error if error?
      async.map device.rules, (rule, next) =>
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
      return meshblu.updateDangerously command.params.uuid, command.params.data, options, callback

    if command.params.operation == 'message'
      return meshblu.message command.params.message, options, callback

    return callback @_createError('unsupported operation type', command, 422)

  _createError: (message, command, code=500) =>
    debug message
    debug JSON.stringify(command, null, 2)
    error = new Error message
    error.code = code
    return error

module.exports = MessageService
