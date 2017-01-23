_ = require 'lodash'
request = require 'request'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'

class MessageService
  create: ({ message, meshbluAuth, meshbluDevice }, callback) =>
    { rulesets } = meshbluDevice
    meshblu = new Meshblu meshbluAuth
    async.map rulesets, async.apply(@_getRuleset, meshblu), (error, rulesMap) =>
      return callback error if error?
      async.map _.flatten(rulesMap), async.apply(@_doRule, message), (error, results) =>
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

  _doRule: (message, config, callback) =>
    engine = new MeshbluRulesEngine config
    engine.run message, callback

  _doCommand: (meshblu, command, callback) =>
    return callback new Error 'unknown command type' if command.type != 'meshblu'
    return callback new Error 'unsupported operation type' if command.params.operation != 'update'
    return callback new Error 'invalid uuid' unless command.params.uuid?
    options = {}
    options.as = command.params.as if command.params.as?
    meshblu.updateDangerously command.params.uuid, command.params.data, options, callback

module.exports = MessageService
