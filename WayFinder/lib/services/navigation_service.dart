import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class NavigationService {
  Position? _currentPosition;
  List<NavigationStep> _currentRoute = [];
  int _currentStepIndex = 0;
  
  // Get current location
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return null;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
    return _currentPosition;
  }

  // Geocode address to coordinates
  Future<Location?> geocodeAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  // Build route using OpenRouteService (free alternative to Google)
  // You can also use 2GIS API if you have access
  Future<List<NavigationStep>> buildRoute(String destinationAddress) async {
    try {
      // Get current location
      final currentPos = await getCurrentLocation();
      if (currentPos == null) {
        throw Exception('Cannot get current location');
      }

      // Geocode destination
      final destination = await geocodeAddress(destinationAddress);
      if (destination == null) {
        throw Exception('Cannot find destination: $destinationAddress');
      }

      // For now, we'll use OpenRouteService API (you need to get a free API key)
      // Alternative: Use 2GIS API or Google Directions API
      final apiKey = Secrets.openRouteServiceApiKey;
      
      final url = Uri.parse('https://api.openrouteservice.org/v2/directions/foot-walking');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinates': [
            [currentPos.longitude, currentPos.latitude],
            [destination.longitude, destination.latitude],
          ],
          'instructions': true,
          'language': 'ru',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final steps = _parseRouteSteps(data);
        _currentRoute = steps;
        _currentStepIndex = 0;
        return steps;
      } else {
        throw Exception('Failed to build route: ${response.statusCode}');
      }
    } catch (e) {
      print('Route building error: $e');
      rethrow;
    }
  }

  List<NavigationStep> _parseRouteSteps(Map<String, dynamic> data) {
    final steps = <NavigationStep>[];
    
    try {
      final route = data['routes'][0];
      final segments = route['segments'] as List;
      final geometry = route['geometry'] as String;
      
      // Decode the polyline geometry to get actual coordinates
      final fullPath = _decodePolyline(geometry);
      
      for (var segment in segments) {
        final stepsList = segment['steps'] as List;
        for (var step in stepsList) {
          final stepWaypoints = step['way_points'] as List;
          final startPointIdx = stepWaypoints[0] as int;
          
          // Get the actual lat/lng for the start of this step
          final startPoint = fullPath[startPointIdx];
          
          steps.add(NavigationStep(
            instruction: step['instruction'] ?? '',
            distance: (step['distance'] ?? 0).toDouble(),
            duration: (step['duration'] ?? 0).toDouble(),
            type: step['type']?.toString() ?? 'straight',
            lat: startPoint[0],
            lng: startPoint[1],
          ));
        }
      }
    } catch (e) {
      print('Error parsing route steps: $e');
    }
    
    return steps;
  }

  // Helper to decode Google/ORS Polyline format
  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([lat / 1E5, lng / 1E5]);
    }
    return points;
  }

  // Get current navigation instruction
  String getCurrentInstruction() {
    if (_currentRoute.isEmpty || _currentStepIndex >= _currentRoute.length) {
      return 'Вы прибыли к месту назначения';
    }
    
    final step = _currentRoute[_currentStepIndex];
    return _formatInstruction(step);
  }

  String _formatInstruction(NavigationStep step) {
    final distanceInt = step.distance.toInt();
    if (distanceInt < 5) return step.instruction;
    
    String distStr;
    if (distanceInt < 1000) {
      distStr = 'через $distanceInt метров';
    } else {
      final km = (step.distance / 1000).toStringAsFixed(1);
      distStr = 'через $km километра';
    }
    
    return '$distStr ${step.instruction}';
  }

  // Move to next step
  void nextStep() {
    if (_currentStepIndex < _currentRoute.length - 1) {
      _currentStepIndex++;
    }
  }

  // Check if we should move to next step based on location
  Future<bool> checkStepProgress() async {
    final currentPos = await getCurrentLocation();
    if (currentPos == null || _currentRoute.isEmpty || _currentStepIndex >= _currentRoute.length - 1) return false;
    
    // Check distance to NEXT step waypoint
    final nextStep = _currentRoute[_currentStepIndex + 1];
    final distanceToNext = calculateDistance(
      currentPos.latitude, 
      currentPos.longitude, 
      nextStep.lat, 
      nextStep.lng
    );

    // If within 10 meters of the next step waypoint, advance
    if (distanceToNext < 10) {
      _currentStepIndex++;
      return true;
    }
    return false;
  }

  double getBearingToNextStep(double currentLat, double currentLng) {
    if (_currentRoute.isEmpty || _currentStepIndex >= _currentRoute.length - 1) return 0;
    
    final nextStep = _currentRoute[_currentStepIndex + 1];
    return Geolocator.bearingBetween(currentLat, currentLng, nextStep.lat, nextStep.lng);
  }


  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Listen to location updates for turn-by-turn navigation
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  void reset() {
    _currentRoute = [];
    _currentStepIndex = 0;
  }

  List<NavigationStep> get currentRoute => _currentRoute;
  int get currentStepIndex => _currentStepIndex;
}

class NavigationStep {
  final String instruction;
  final double distance;
  final double duration;
  final String type;
  final double lat;
  final double lng;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.type,
    required this.lat,
    required this.lng,
  });
}
