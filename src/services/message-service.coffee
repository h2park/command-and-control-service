_ = require 'lodash'
request = require 'request'
async = require 'async'
Meshblu = require 'meshblu-http'
MeshbluRulesEngine = require 'meshblu-rules-engine'

class MessageService
  create: ({ message, meshbluAuth, meshbluDevice }, callback) =>
    { rulesets } = meshbluDevice
    meshblu = new Meshblu meshbluAuth
    async.map rulesets, async.apply(@_getRuleset, meshblu), (error, rulesetMaps) =>
      return callback error if error?
      async.map _.flatten(rulesetMaps), async.apply(@_doRule, message), (error, results) =>
        return callback error if error?
        commands = _.flatten results
        async.each commands, async.apply(@_doCommand, meshblu), callback

  _getRuleset: (meshblu, rule, callback) =>
    meshblu.device rule.uuid, (error, device) =>
      return callback error if error?
      async.map device.rules, (rule, next) =>
        request.get rule.url, json: true, (error, response, body) =>
          next error, body
      , callback

  _doRule: (message, config, callback) =>
    engine = new MeshbluRulesEngine config
    engine.run message, callback

  _doCommand: (meshblu, command, callback) =>
    callback new Error 'unknown command type' if command.type != 'meshblu'
    callback new Error 'unsupported operation type' if command.params.operation != 'update'
    callback new Error 'invalid uuid' unless command.params.uuid?
    meshblu.updateDangerously command.params.uuid, command.params.data, callback

module.exports = MessageService
