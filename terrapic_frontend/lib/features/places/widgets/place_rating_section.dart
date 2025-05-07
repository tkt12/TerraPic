import 'package:flutter/material.dart';

class PlaceRatingSection extends StatelessWidget {
  final Map<String, dynamic>? placeDetails;

  const PlaceRatingSection({
    Key? key,
    required this.placeDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (placeDetails == null) return const SizedBox.shrink();

    final rating =
        double.tryParse(placeDetails!['rating']?.toString() ?? '0.0') ?? 0.0;
    final totalReviews = placeDetails!['total_reviews'] ?? 0;

    final Map<String, dynamic>? rawDistribution =
        placeDetails!['rating_distribution'] as Map<String, dynamic>?;
    if (rawDistribution == null) return const SizedBox.shrink();

    final distribution = {
      5: rawDistribution['five_star'] ?? 0.0,
      4: rawDistribution['four_star'] ?? 0.0,
      3: rawDistribution['three_star'] ?? 0.0,
      2: rawDistribution['two_star'] ?? 0.0,
      1: rawDistribution['one_star'] ?? 0.0,
    };

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側の評価スコアと星
          Container(
            width: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isPartialStar =
                        index == rating.floor() && rating % 1 != 0;
                    final partialWidth = rating % 1;

                    return Stack(
                      children: [
                        Icon(
                          Icons.star,
                          size: 20,
                          color: Colors.grey[300],
                        ),
                        if (index < rating.floor())
                          const Icon(
                            Icons.star,
                            size: 20,
                            color: Colors.amber,
                          )
                        else if (isPartialStar)
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: partialWidth,
                              child: const Icon(
                                Icons.star,
                                size: 20,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalReviews reviews',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // 右側のレーティングバー
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final stars = 5 - index;
                final percentage = distribution[stars]?.toDouble() ?? 0.0;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        child: Text(
                          '$stars',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            color: Colors.amber,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
