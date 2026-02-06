extension ShortMillion on int {
  String toMillion() {
    return (this / 1000000).toStringAsFixed(1);
  }
}
