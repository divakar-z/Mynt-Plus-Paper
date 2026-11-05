import 'ipo_order_book_model.dart';

class MenuData {
  String flow;
  String type;
  String symbol;
  String category;
  String name;
  String applicationNumber;
  List<BidReference> respBid;
  // Bids of the application being cancelled (from My Bids). BSE cancel sends
  // them in full; the backend rejected the bare {"actioncode": "d"}.
  List<BidDetail> cancelBids;

  MenuData({
    required this.flow,
    required this.type,
    required this.symbol,
    required this.category,
    required this.name,
    required this.applicationNumber,
    required this.respBid,
    this.cancelBids = const [],
  });
}

class BidReference {
  String bidReferenceNumber;

  BidReference({required this.bidReferenceNumber});
}

class IposBid {
  bool bitis;
  int qty;
  bool cutoff;
  double price;
  double total;

  IposBid({
    required this.bitis,
    required this.qty,
    required this.cutoff,
    required this.price,
    required this.total,
  });
}

class ModifyInput {
  int lotsize;
  double bidprice;
  List<Quantiy> quantity;

  ModifyInput({
    required this.lotsize,
    required this.bidprice,
    required this.quantity,
  });
}

class Quantiy {
  int qty;

  Quantiy({required this.qty});
}
