/// Ungefährer Standort (ohne Flutter-Abhängigkeit).
library;

/// Ungefährer Standort (auf ~1 km gerundet).
class ApproxLocation {
  const ApproxLocation(this.latitude, this.longitude);

  /// Rundet auf zwei Nachkommastellen: ca. 1,1 km Nord-Süd, in Deutschland
  /// ca. 0,7 km Ost-West. Genauer verlässt der Standort das Gerät nie.
  factory ApproxLocation.rounded(double latitude, double longitude) =>
      ApproxLocation(roundCoordinate(latitude), roundCoordinate(longitude));

  final double latitude;
  final double longitude;

  /// Format für die Spalte `profiles.location` (PostGIS EWKT).
  String toEwkt() => 'SRID=4326;POINT($longitude $latitude)';
}

double roundCoordinate(double value) => (value * 100).round() / 100;
