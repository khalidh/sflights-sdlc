const cds = require('@sap/cds')

cds.on('bootstrap', (app) => {
  app.get('/health', (_, res) => res.status(200).json({ status: 'UP' }))
})

module.exports = cds.server
