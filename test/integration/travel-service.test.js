const cds = require('@sap/cds')

describe('TravelService', () => {
  const { GET, POST, PATCH, DELETE } = cds.test(__dirname + '/../..')
  const processor = { auth: { username: 'processor', password: 'processor' } }
  const reviewer = { auth: { username: 'reviewer', password: 'reviewer' } }

  test('expose un point de santé', async () => {
    const response = await GET('/health')
    expect(response.status).toBe(200)
    expect(response.data).toEqual({ status: 'UP' })
  })

  test('expose les voyages et leurs données de référence', async () => {
    const response = await GET('/odata/v4/travel/Travels?$expand=agency,customer', processor)
    expect(response.status).toBe(200)
    expect(response.data.value.length).toBeGreaterThan(0)
    expect(response.data.value[0].agency.name).toBeDefined()
  })

  test('refuse une période incohérente dans un brouillon', async () => {
    const { data } = await GET('/odata/v4/travel/Travels?$filter=travelNumber eq 1', processor)
    const ID = data.value[0].ID
    await POST(
      `/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=true)/TravelService.draftEdit`,
      { PreserveChanges: false },
      processor
    )
    await PATCH(
      `/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=false)`,
      { beginDate: '2026-10-10', endDate: '2026-10-01' },
      processor
    )
    await expect(
      POST(`/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=false)/TravelService.draftActivate`, {}, processor)
    ).rejects.toMatchObject({ status: 400 })
    await DELETE(`/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=false)`, processor)
  })

  test('un reviewer peut accepter un voyage ouvert', async () => {
    const { data } = await GET('/odata/v4/travel/Travels?$filter=travelNumber eq 1', reviewer)
    const ID = data.value[0].ID
    const response = await POST(
      `/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=true)/TravelService.accept`,
      {},
      reviewer
    )
    expect(response.status).toBe(200)
    expect(response.data.status).toBe('A')
  })

  test('un processor ne peut pas accepter un voyage', async () => {
    const { data } = await GET('/odata/v4/travel/Travels?$filter=travelNumber eq 3', processor)
    await expect(
      POST(`/odata/v4/travel/Travels(ID=${data.value[0].ID},IsActiveEntity=true)/TravelService.accept`, {}, processor)
    ).rejects.toMatchObject({ status: 403 })
  })

  test('applique une remise puis permet au reviewer de rejeter le voyage', async () => {
    const { data } = await GET('/odata/v4/travel/Travels?$filter=travelNumber eq 3', processor)
    const ID = data.value[0].ID
    const discounted = await POST(
      `/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=true)/TravelService.applyDiscount`,
      { percent: 10 },
      processor
    )
    expect(discounted.data.totalPrice).toBe(90)

    const rejected = await POST(
      `/odata/v4/travel/Travels(ID=${ID},IsActiveEntity=true)/TravelService.rejectTravel`,
      {},
      reviewer
    )
    expect(rejected.data.status).toBe('X')
  })

  test('refuse une remise hors limites', async () => {
    const { data } = await GET('/odata/v4/travel/Travels?$filter=travelNumber eq 2', processor)
    await expect(
      POST(
        `/odata/v4/travel/Travels(ID=${data.value[0].ID},IsActiveEntity=true)/TravelService.applyDiscount`,
        { percent: 101 },
        processor
      )
    ).rejects.toMatchObject({ status: 400 })
  })
})
