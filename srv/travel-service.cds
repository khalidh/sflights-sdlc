using { sflight as db } from '../db/schema';

service TravelService @(requires: 'authenticated-user') {
  @odata.draft.enabled
  entity Travels as projection on db.Travels {
    *,
    virtual null as statusCriticality : Integer
  } actions {
    @requires: 'TravelReviewer' action accept() returns Travels;
    @requires: 'TravelReviewer' action rejectTravel() returns Travels;
    @requires: 'TravelProcessor' action applyDiscount(percent: Decimal(5,2)) returns Travels;
  };

  entity Bookings as projection on db.Bookings;
  entity BookingSupplements as projection on db.BookingSupplements;

  @readonly entity Agencies as projection on db.Agencies;
  @readonly entity Customers as projection on db.Customers;
  @readonly entity Airports as projection on db.Airports;
  @readonly entity Carriers as projection on db.Carriers;
  @readonly entity Connections as projection on db.Connections;
  @readonly entity Flights as projection on db.Flights;
  @readonly entity Supplements as projection on db.Supplements;
}

annotate TravelService.Travels with @(restrict: [
  { grant: 'READ', to: ['TravelProcessor', 'TravelReviewer', 'Administrator'] },
  { grant: ['CREATE', 'UPDATE', 'DELETE'], to: ['TravelProcessor', 'Administrator'], where: (status = 'O') },
  { grant: ['accept', 'rejectTravel'], to: ['TravelReviewer', 'Administrator'] },
  { grant: 'applyDiscount', to: ['TravelProcessor', 'Administrator'] }
]);

annotate TravelService.Bookings with @(restrict: [
  { grant: 'READ', to: ['TravelProcessor', 'TravelReviewer', 'Administrator'] },
  { grant: ['CREATE', 'UPDATE', 'DELETE'], to: ['TravelProcessor', 'Administrator'] }
]);

annotate TravelService.BookingSupplements with @(restrict: [
  { grant: 'READ', to: ['TravelProcessor', 'TravelReviewer', 'Administrator'] },
  { grant: ['CREATE', 'UPDATE', 'DELETE'], to: ['TravelProcessor', 'Administrator'] }
]);
