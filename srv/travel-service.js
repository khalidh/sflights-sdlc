const cds = require('@sap/cds')

module.exports = class TravelService extends cds.ApplicationService {
  async init() {
    const { Travels, Bookings, BookingSupplements, Supplements } = this.entities

    this.before('*', (req) => {
      if (req.target?.name.startsWith(Travels.name) && ['CREATE', 'UPDATE', 'PATCH', 'SAVE'].includes(req.event)) {
        return validateTravel(req.data, req)
      }
    })
    this.before(['CREATE', 'UPDATE'], Bookings, validateBooking)
    this.before(['CREATE', 'UPDATE'], BookingSupplements, validateBookingSupplement)

    this.on('accept', Travels, setStatus('A'))
    this.on('rejectTravel', Travels, setStatus('X'))
    this.on('applyDiscount', Travels, applyDiscount)
    this.after('READ', Travels, (rows) => {
      for (const row of Array.isArray(rows) ? rows : [rows]) {
        if (row) {
          row.statusCriticality = row.status === 'A' ? 3 : row.status === 'X' ? 1 : 2
        }
      }
    })

    this.after(['CREATE', 'UPDATE', 'DELETE'], Bookings, (_, req) => recalculateTravel(req.data.travel_ID))
    this.after(['CREATE', 'UPDATE', 'DELETE'], BookingSupplements, async (_, req) => {
      const booking = await SELECT.one.from(Bookings).columns('travel_ID').where({ ID: req.data.booking_ID })
      if (booking) {
        await recalculateTravel(booking.travel_ID)
      }
    })

    async function validateTravel(data, req) {
      if (data.beginDate && data.endDate && data.endDate < data.beginDate) {
        req.error(400, 'La date de fin doit être postérieure ou égale à la date de début', 'endDate')
      }
      for (const field of ['bookingFee', 'totalPrice']) {
        if (data[field] != null && Number(data[field]) < 0) {
          req.error(400, `${field} ne peut pas être négatif`, field)
        }
      }
    }

    async function validateBooking(data, req) {
      if (data.flightPrice != null && Number(data.flightPrice) < 0) {
        req.error(400, 'Le prix du vol ne peut pas être négatif', 'flightPrice')
      }
      if (data.travel_ID) {
        const travel = await SELECT.one.from(Travels).columns('status').where({ ID: data.travel_ID })
        if (travel && travel.status !== 'O') {
          req.error(409, 'Les réservations ne sont modifiables que pour un voyage ouvert')
        }
      }
    }

    async function validateBookingSupplement(data, req) {
      if (data.price != null && Number(data.price) < 0) {
        req.error(400, 'Le prix du supplément ne peut pas être négatif', 'price')
      }
      if (data.supplement_ID && data.price == null) {
        const supplement = await SELECT.one.from(Supplements).where({ ID: data.supplement_ID })
        if (supplement) {
          data.price = supplement.price
          data.currency = supplement.currency
        }
      }
    }

    function setStatus(status) {
      return async (req) => {
        const ID = req.params[0].ID
        const travel = await SELECT.one.from(Travels).where({ ID })
        if (!travel) {
          return req.reject(404)
        }
        if (travel.status !== 'O') {
          return req.reject(409, 'Seul un voyage ouvert peut changer de statut')
        }
        await UPDATE(Travels).set({ status }).where({ ID })
        return SELECT.one.from(Travels).where({ ID })
      }
    }

    async function applyDiscount(req) {
      const ID = req.params[0].ID
      const percent = Number(req.data.percent)
      if (!Number.isFinite(percent) || percent <= 0 || percent > 100) {
        return req.reject(400, 'La remise doit être comprise entre 0 et 100')
      }
      const travel = await SELECT.one.from(Travels).where({ ID })
      if (!travel) {
        return req.reject(404)
      }
      if (travel.status !== 'O') {
        return req.reject(409, 'Une remise ne peut être appliquée qu’à un voyage ouvert')
      }
      const totalPrice = Math.round(Number(travel.totalPrice) * (1 - percent / 100) * 100) / 100
      await UPDATE(Travels).set({ totalPrice }).where({ ID })
      return SELECT.one.from(Travels).where({ ID })
    }

    async function recalculateTravel(travelID) {
      if (!travelID) {
        return
      }
      const travel = await SELECT.one.from(Travels).columns('bookingFee').where({ ID: travelID })
      if (!travel) {
        return
      }
      const bookings = await SELECT.from(Bookings).columns('ID', 'flightPrice').where({ travel_ID: travelID })
      let total = Number(travel.bookingFee || 0)
      for (const booking of bookings) {
        total += Number(booking.flightPrice || 0)
        const items = await SELECT.from(BookingSupplements).columns('price').where({ booking_ID: booking.ID })
        total += items.reduce((sum, item) => sum + Number(item.price || 0), 0)
      }
      await UPDATE(Travels)
        .set({ totalPrice: Math.round(total * 100) / 100 })
        .where({ ID: travelID })
    }

    return super.init()
  }
}
