_ = require 'lodash'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'

class MessageService
  create: ({ message, meshbluAuth, meshbluDevice }, callback) =>
    { rules } = meshbluDevice
    meshblu = new Meshblu meshbluAuth
    async.map rules, async.apply(@_getRule, meshblu), (error, ruleMap) =>
      return callback error if error?
      async.map ruleMap, async.apply(@_doRule, message), (error, results) =>
        return callback error if error?
        commands = _.flatten results
        async.each commands, async.apply(@_doCommand, meshblu), callback

  _getRule: (meshblu, rule, callback) =>
    meshblu.device rule.uuid, callback

  _doRule: (message, config, callback) =>
    engine = new MeshbluRulesEngine config
    engine.run message, callback

  _doCommand: (meshblu, command, callback) =>
    callback new Error 'unknown command type' if command.type != 'meshblu'
    callback new Error 'unsupported operation type' if command.params.operation != 'update'
    callback new Error 'invalid uuid' unless command.params.uuid?
    meshblu.updateDangerously command.params.uuid, command.params.data, callback

module.exports = MessageService
