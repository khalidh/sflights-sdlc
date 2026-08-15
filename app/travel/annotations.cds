using TravelService as service from '../../srv/travel-service';

annotate service.Travels with @(
  UI.HeaderInfo: {
    TypeName: 'Voyage', TypeNamePlural: 'Voyages',
    Title: { Value: travelNumber },
    Description: { Value: description }
  },
  UI.SelectionFields: [travelNumber, agency_ID, customer_ID, status, beginDate, endDate],
  UI.LineItem: [
    { Value: travelNumber, Label: 'N° voyage' },
    { Value: agency.name, Label: 'Agence' },
    { Value: customer.lastName, Label: 'Client' },
    { Value: beginDate, Label: 'Début' },
    { Value: endDate, Label: 'Fin' },
    { Value: totalPrice, Label: 'Prix total' },
    { Value: currency, Label: 'Devise' },
    { Value: status, Label: 'Statut', Criticality: statusCriticality },
    { $Type: 'UI.DataFieldForAction', Action: 'TravelService.accept', Label: 'Accepter' },
    { $Type: 'UI.DataFieldForAction', Action: 'TravelService.rejectTravel', Label: 'Rejeter' },
    { $Type: 'UI.DataFieldForAction', Action: 'TravelService.applyDiscount', Label: 'Appliquer une remise' }
  ],
  UI.Facets: [
    { $Type: 'UI.ReferenceFacet', Label: 'Informations générales', Target: '@UI.FieldGroup#General' },
    { $Type: 'UI.ReferenceFacet', Label: 'Réservations', Target: 'bookings/@UI.LineItem' }
  ],
  UI.FieldGroup#General: { Data: [
    { Value: travelNumber }, { Value: agency_ID }, { Value: customer_ID },
    { Value: beginDate }, { Value: endDate }, { Value: bookingFee },
    { Value: totalPrice }, { Value: currency }, { Value: status }, { Value: description }
  ] }
);

annotate service.Travels with {
  agency @Common.ValueList: {
    CollectionPath: 'Agencies', Parameters: [
      { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: agency_ID, ValueListProperty: 'ID' },
      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'name' }
    ]
  };
  customer @Common.ValueList: {
    CollectionPath: 'Customers', Parameters: [
      { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: customer_ID, ValueListProperty: 'ID' },
      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'lastName' }
    ]
  };
  totalPrice @readonly;
};

annotate service.Bookings with @UI.LineItem: [
  { Value: bookingNumber, Label: 'N° réservation' },
  { Value: bookingDate, Label: 'Date' },
  { Value: flight.connection.connectionNumber, Label: 'Vol' },
  { Value: flightPrice, Label: 'Prix' },
  { Value: currency, Label: 'Devise' },
  { Value: status, Label: 'Statut' }
];

annotate service.Bookings with @UI.Facets: [
  { $Type: 'UI.ReferenceFacet', Label: 'Suppléments', Target: 'supplements/@UI.LineItem' }
];

annotate service.BookingSupplements with @UI.LineItem: [
  { Value: itemNumber, Label: 'Poste' },
  { Value: supplement.name, Label: 'Supplément' },
  { Value: price, Label: 'Prix' },
  { Value: currency, Label: 'Devise' }
];
