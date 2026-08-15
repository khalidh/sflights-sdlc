namespace sflight.common;

using { cuid, managed } from '@sap/cds/common';

type Currency : String(3);
type TravelStatus : String(1) enum {
  open     = 'O';
  accepted = 'A';
  rejected = 'X';
};
type BookingStatus : String(1) enum {
  new       = 'N';
  booked    = 'B';
  cancelled = 'X';
};

aspect BusinessObject : cuid, managed {}
