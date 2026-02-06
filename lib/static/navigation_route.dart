enum NavigationRoute {
  mainRoute("/"),
  pointCoffeeRoute("/point-coffe"),
  sayBreadRoute("/say-bread"),
  barcodeRoute("/barcode");

  const NavigationRoute(this.name);

  final String name;
}
