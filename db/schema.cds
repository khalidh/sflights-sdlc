namespace sflight;

using { sflight.common.BusinessObject, sflight.common.Currency, sflight.common.TravelStatus, sflight.common.BookingStatus } from './common';

entity Agencies : BusinessObject {
  agencyNumber : String(8) not null @assert.unique;
  name         : String(80) not null;
  street       : String(80);
  postalCode   : String(10);
  city         : String(40);
  countryCode  : String(3);
  phone        : String(30);
  email        : String(255);
  travels      : Association to many Travels on travels.agency = $self;
}

entity Customers : BusinessObject {
  customerNumber : String(8) not null @assert.unique;
  firstName      : String(40) not null;
  lastName       : String(40) not null;
  email          : String(255);
  phone          : String(30);
  street         : String(80);
  postalCode     : String(10);
  city           : String(40);
  countryCode    : String(3);
  travels        : Association to many Travels on travels.customer = $self;
}

entity Airports : BusinessObject {
  airportCode : String(3) not null @assert.unique;
  name        : String(80) not null;
  city        : String(40) not null;
  countryCode : String(3) not null;
}

entity Carriers : BusinessObject {
  carrierCode : String(3) not null @assert.unique;
  name        : String(80) not null;
  currency    : Currency not null;
  connections : Association to many Connections on connections.carrier = $self;
}

entity Connections : BusinessObject {
  connectionNumber : String(4) not null;
  carrier           : Association to one Carriers not null;
  departureAirport  : Association to one Airports not null;
  destinationAirport: Association to one Airports not null;
  departureTime     : Time;
  arrivalTime       : Time;
  distanceKm        : Integer;
  flights           : Association to many Flights on flights.connection = $self;
}

entity Flights : BusinessObject {
  connection      : Association to one Connections not null;
  flightDate      : Date not null;
  price           : Decimal(15,2) not null;
  currency        : Currency not null;
  planeType       : String(20);
  maximumSeats    : Integer;
  occupiedSeats   : Integer default 0;
  bookings        : Association to many Bookings on bookings.flight = $self;
}

entity Supplements : BusinessObject {
  supplementCode : String(10) not null @assert.unique;
  name           : String(80) not null;
  price          : Decimal(15,2) not null;
  currency       : Currency not null;
}

entity Travels : BusinessObject {
  travelNumber    : Integer not null @assert.unique;
  agency          : Association to one Agencies not null;
  customer        : Association to one Customers not null;
  beginDate       : Date not null;
  endDate         : Date not null;
  bookingFee      : Decimal(15,2) default 0;
  totalPrice      : Decimal(15,2) default 0;
  currency        : Currency not null;
  description     : String(255);
  status          : TravelStatus default 'O';
  bookings        : Composition of many Bookings on bookings.travel = $self;
}

entity Bookings : BusinessObject {
  travel             : Association to one Travels not null;
  bookingNumber      : Integer not null;
  bookingDate        : Date not null;
  customer           : Association to one Customers not null;
  flight             : Association to one Flights not null;
  flightPrice        : Decimal(15,2) default 0;
  currency           : Currency not null;
  status             : BookingStatus default 'N';
  supplements        : Composition of many BookingSupplements on supplements.booking = $self;
}

entity BookingSupplements : BusinessObject {
  booking          : Association to one Bookings not null;
  itemNumber       : Integer not null;
  supplement       : Association to one Supplements not null;
  price            : Decimal(15,2) default 0;
  currency         : Currency not null;
}
