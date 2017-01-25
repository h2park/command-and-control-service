_ = require 'lodash'
request = require 'request'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'

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
        request.get rule.url, json: true, (error, response, body) =>
          next error, body
      , (error, rules) =>
        return callback error if error?
        return callback null, _.flatten rules

  _doRule: (context, meshbluConfig, rulesConfig, callback) =>
    engine = new MeshbluRulesEngine {meshbluConfig, rulesConfig}
    engine.run context, callback

  _doCommand: (meshblu, command, callback) =>
    return callback @_createError('unknown command type', 422) if command.type != 'meshblu'
    return callback @_createError('unsupported operation type', 422) if command.params.operation != 'update'
    return callback @_createError('invalid uuid', 422) unless command.params.uuid?
    options = {}
    options.as = command.params.as if command.params.as?
    meshblu.updateDangerously command.params.uuid, command.params.data, options, callback
  
  _createError: (message, code=500) =>
    error = new Error message
    error.code = code
    return error

module.exports = MessageService
