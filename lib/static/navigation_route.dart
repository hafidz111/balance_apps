enum NavigationRoute {
  mainRoute("/"),
  coffeeRoute("/coffee"),
  breadRoute("/bread"),
  barcodeRoute("/barcode");

  const NavigationRoute(this.name);

  final String name;
}
