{clearCache} = require '../helpers/cached-request'

class CacheController
  delete: (req, res) =>
    clearCache()
    res.sendStatus 204

module.exports = CacheController
