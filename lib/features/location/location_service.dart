import 'package:geolocator/geolocator.dart';

import 'approx_location.dart';

export 'approx_location.dart';

enum LocationProblem { serviceDisabled, denied, deniedForever, failed }

class LocationException implements Exception {
  const LocationException(this.problem);

  final LocationProblem problem;

  String get message => switch (problem) {
    LocationProblem.serviceDisabled =>
      'Die Standortdienste sind ausgeschaltet. Schalte sie in den '
          'Einstellungen ein.',
    LocationProblem.denied =>
      'Ohne Standort können wir dir niemanden in '
          'deiner Nähe zeigen.',
    LocationProblem.deniedForever =>
      'Der Standortzugriff ist gesperrt. Du kannst ihn in den '
          'Einstellungen deines Handys erlauben.',
    LocationProblem.failed => 'Standort konnte nicht ermittelt werden.',
  };
}

abstract interface class LocationService {
  /// Fragt bei Bedarf nach der Berechtigung. Wirft [LocationException].
  Future<ApproxLocation> currentApproxLocation();
}

/// Echter Standort über das Gerät, nur grob genau.
class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  @override
  Future<ApproxLocation> currentApproxLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationProblem.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationProblem.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationProblem.deniedForever);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return ApproxLocation.rounded(position.latitude, position.longitude);
    } on Exception {
      throw const LocationException(LocationProblem.failed);
    }
  }
}

/// Demo und Tests: immer Leipzig-Zentrum.
class FakeLocationService implements LocationService {
  const FakeLocationService({this.fail});

  final LocationProblem? fail;

  @override
  Future<ApproxLocation> currentApproxLocation() async {
    if (fail != null) throw LocationException(fail!);
    return ApproxLocation.rounded(51.3397, 12.3731);
  }
}
