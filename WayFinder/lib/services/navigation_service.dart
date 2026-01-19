import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class NavigationService {
  Position? _currentPosition;
  List<NavigationStep> _currentRoute = [];
  int _currentStepIndex = 0;

  Position? get currentPosition => _currentPosition;
  String? _currentCity; // Cached city name from reverse geocoding
  String? _currentCountry;
  
  // Get current location - Optimized for speed
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    // Use standard accuracy for speed check, high for route building
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
    
    return _currentPosition;
  }
  
  // Initialize city detection explicitly (lazy load)
  Future<void> ensureCityDetected() async {
    if (_currentCity != null) return; // Already detected
    if (_currentPosition == null) await getCurrentLocation();
    await _detectCurrentCity();
  }

  /// Detect current city using reverse geocoding
  Future<void> _detectCurrentCity() async {
    if (_currentPosition == null) return;
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _currentCity = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea;
        _currentCountry = place.country;
        print("📍 Detected location: $_currentCity, $_currentCountry");
      }
    } catch (e) {
      print("⚠️ Reverse geocoding failed: $e");
    }
  }

  /// Get current city context string for search
  String get cityContext {
    if (_currentCity != null && _currentCountry != null) {
      return "$_currentCity, $_currentCountry";
    } else if (_currentCity != null) {
      return _currentCity!;
    }
    return "";
  }

  // Smart geocode with Google Places for better address recognition
  Future<Location?> geocodeAddress(String address) async {
    print("🔍 Geocoding: $address");
    
    // 1. Try Google Places Autocomplete first (better for landmarks and streets)
    try {
      final placeResult = await _searchWithPlaces(address);
      if (placeResult != null) return placeResult;
    } catch (e) {
      print("⚠️ Places search failed: $e");
    }
    
    // 2. Fallback to standard geocoding with city context
    try {
      String searchQuery = address;
      if (cityContext.isNotEmpty && !address.toLowerCase().contains(_currentCity?.toLowerCase() ?? '')) {
        searchQuery = "$address, $cityContext";
      }
      print("🔍 Trying geocode: $searchQuery");
      
      List<Location> locations = await locationFromAddress(searchQuery);
      if (locations.isNotEmpty) {
        print("✅ Found via geocoding: ${locations.first.latitude}, ${locations.first.longitude}");
        return locations.first;
      }
    } catch (e) {
      print('⚠️ Standard geocoding error: $e');
    }
    
    // 3. Last resort - try without city context
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
    } catch (e) {
      print('❌ All geocoding failed: $e');
    }
    
    return null;
  }

  /// Search using Google Places API for better landmark/street recognition
  Future<Location?> _searchWithPlaces(String query) async {
    if (_currentPosition == null) return null;
    
    final apiKey = Secrets.googleMapsApiKey;
    
    // Use Places Autocomplete with location bias
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&radius=50000' // 50km radius
      '&language=ru'
      '&key=$apiKey'
    );
    
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && data['predictions'].isNotEmpty) {
        final placeId = data['predictions'][0]['place_id'];
        final description = data['predictions'][0]['description'];
        print("📍 Found place: $description");
        
        // Get place details to get coordinates
        return await _getPlaceDetails(placeId);
      }
    }
    return null;
  }

  /// Get coordinates from place ID
  Future<Location?> _getPlaceDetails(String placeId) async {
    final apiKey = Secrets.googleMapsApiKey;
    
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=geometry'
      '&key=$apiKey'
    );
    
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        return Location(
          latitude: loc['lat'].toDouble(),
          longitude: loc['lng'].toDouble(),
          timestamp: DateTime.now(),
        );
      }
    }
    return null;
  }

  // Build route using OpenRouteService with Google Maps fallback
  Future<List<NavigationStep>> buildRoute(String destinationAddress) async {
    print("🗺️ Building route to: $destinationAddress");
    
    try {
      // Get current location
      final currentPos = await getCurrentLocation();
      if (currentPos == null) {
        throw Exception('Не удалось определить местоположение. Включите GPS.');
      }
      
      // Ensure we know the city for better local search context
      await ensureCityDetected();
      
      print("📍 Current position: ${currentPos.latitude}, ${currentPos.longitude}");

      // Geocode destination
      final destination = await geocodeAddress(destinationAddress);
      if (destination == null) {
        throw Exception('Не удалось найти: $destinationAddress');
      }
      print("🎯 Destination: ${destination.latitude}, ${destination.longitude}");

      // Try OpenRouteService first
      try {
        final steps = await _buildRouteORS(currentPos, destination);
        if (steps.isNotEmpty) return steps;
      } catch (e) {
        print("⚠️ OpenRouteService failed: $e, trying Google...");
      }

      // Fallback to Google Directions API
      try {
        final steps = await _buildRouteGoogle(currentPos, destination);
        if (steps.isNotEmpty) return steps;
      } catch (e) {
        print("⚠️ Google Directions failed: $e");
      }

      throw Exception('Не удалось построить маршрут ни через один сервис');
    } catch (e) {
      print('❌ Route building error: $e');
      rethrow;
    }
  }

  Future<List<NavigationStep>> _buildRouteORS(Position currentPos, Location destination) async {
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
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final steps = _parseRouteSteps(data);
      _currentRoute = steps;
      _currentStepIndex = 0;
      print("✅ ORS route built: ${steps.length} steps");
      return steps;
    } else {
      throw Exception('ORS error: ${response.statusCode}');
    }
  }

  Future<List<NavigationStep>> _buildRouteGoogle(Position currentPos, Location destination) async {
    final apiKey = Secrets.googleMapsApiKey;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${currentPos.latitude},${currentPos.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=walking'
      '&language=ru'
      '&key=$apiKey'
    );
    
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final steps = _parseGoogleSteps(data);
        _currentRoute = steps;
        _currentStepIndex = 0;
        print("✅ Google route built: ${steps.length} steps");
        return steps;
      }
    }
    throw Exception('Google error: ${response.statusCode}');
  }

  List<NavigationStep> _parseGoogleSteps(Map<String, dynamic> data) {
    final steps = <NavigationStep>[];
    try {
      final legs = data['routes'][0]['legs'] as List;
      for (var leg in legs) {
        final legSteps = leg['steps'] as List;
        for (var step in legSteps) {
          // Remove HTML tags from instructions
          String instruction = step['html_instructions'] ?? '';
          instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
          
          steps.add(NavigationStep(
            instruction: instruction,
            distance: (step['distance']['value'] ?? 0).toDouble(),
            duration: (step['duration']['value'] ?? 0).toDouble(),
            type: step['maneuver'] ?? 'straight',
            lat: step['start_location']['lat'].toDouble(),
            lng: step['start_location']['lng'].toDouble(),
          ));
        }
      }
    } catch (e) {
      print('Error parsing Google steps: $e');
    }
    return steps;
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
  // Optional position param avoids re-fetching location if we already have it from stream
  Future<bool> checkStepProgress({Position? position}) async {
    final currentPos = position ?? await getCurrentLocation();
    
    // Update internal position state
    _currentPosition = currentPos;
    
    if (currentPos == null || _currentRoute.isEmpty || _currentStepIndex >= _currentRoute.length - 1) return false;
    
    // Check distance to NEXT step waypoint
    final nextStep = _currentRoute[_currentStepIndex + 1];
    final distanceToNext = calculateDistance(
      currentPos.latitude, 
      currentPos.longitude, 
      nextStep.lat, 
      nextStep.lng
    );

    // If within 15 meters (increased tolerance) of the next step waypoint, advance
    if (distanceToNext < 15) {
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
