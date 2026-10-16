/// Sector + industry option lists for the fundamentals Sector / Industry
/// multiselect filters. Fetched once from `/scans/fundamental/categories`
/// and cached by [fundamentalCategoriesProvider].
class FundamentalCategories {
  final List<String> sectors;
  final List<String> industries;

  const FundamentalCategories({
    required this.sectors,
    required this.industries,
  });

  factory FundamentalCategories.fromJson(Map<String, dynamic> j) =>
      FundamentalCategories(
        sectors: ((j['sectors'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        industries: ((j['industries'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  static const empty = FundamentalCategories(sectors: [], industries: []);
}
