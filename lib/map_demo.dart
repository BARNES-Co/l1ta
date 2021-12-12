import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:l1ta/secrets.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:math';

import 'Constants.dart';

class MapDemoScreen extends StatefulWidget {
  MapDemoScreen({Key? key}) : super(key: key);

  @override
  _MapDemoScreenState createState() => _MapDemoScreenState();
}

class _MapDemoScreenState extends State<MapDemoScreen> {
  late String _nightMapStyle;

  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  Future _loadMapStyles() async {
    _nightMapStyle =
        await rootBundle.loadString('assets/map_styles/night.json');
  }

  late GoogleMapController mapController;

  Map<String, double> products = {"bread": 3, "milk": 16};

  double createOrder(String text) {
    List<String> cart = [];
    double bill = 0;
    if (text.contains("bread")) {
      cart.add("bread");
      bill += 3;
    }
    if (text.contains("milk")) {
      cart.add("milk");
      bill += 16;
    }
    return bill;
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  // Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _lastWords = createOrder(_lastWords).toString();
      destinationAddressController.text = _lastWords;
    });
  }

  @override
  void initState() {
    _loadMapStyles();
    _getCurrentLocation();
    _initSpeech();
    super.initState();
  }

  GlobalKey<SliderMenuContainerState> _key =
      new GlobalKey<SliderMenuContainerState>();

  late Position _currentPosition;
  String _currentAddress = '';

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final destinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String _destinationAddress = '';
  String? _placeDistance;

  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));

  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  Set<Marker> markers = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
        print('CURRENT POS: $_currentPosition');
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
      await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition.latitude, _currentPosition.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  Map<String, Polyline> fullLines = Map<String, Polyline>();
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
          await locationFromAddress(_destinationAddress);
      print(destinationPlacemark.toList());

      // Use the retrieved coordinates of the current position,
      // instead of the address if the start position is user's
      // current position, as it results in better accuracy.
      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = destinationPlacemark[0].latitude;
      double destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      // Start Location Marker
      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude, startLongitude),
        infoWindow: InfoWindow(
          title: 'Start $startCoordinatesString',
          snippet: _startAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Destination Location Marker
      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(
          title: 'Destination $destinationCoordinatesString',
          snippet: _destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Adding the markers to the list
      markers.add(startMarker);
      markers.add(destinationMarker);

      print(
        'START COORDINATES: ($startLatitude, $startLongitude)',
      );
      print(
        'DESTINATION COORDINATES: ($destinationLatitude, $destinationLongitude)',
      );

      // Calculating to check that the position relative
      // to the frame, and pan & zoom the camera accordingly.
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      // Accommodate the two locations within the
      // camera view of the map
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            northeast: LatLng(northEastLatitude, northEastLongitude),
            southwest: LatLng(southWestLatitude, southWestLongitude),
          ),
          100.0,
        ),
      );

      // Calculating the distance between the start and the end positions
      // with a straight path, without considering any route
      // double distanceInMeters = await Geolocator.bearingBetween(
      //   startLatitude,
      //   startLongitude,
      //   destinationLatitude,
      //   destinationLongitude,
      // );

      _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      double totalDistance = 0.0;

      // Calculating the total distance by adding the distance
      // between small segments
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
      });

      return true;
    } catch (e) {
      print(e);
    }
    return false;
  }

  List waypoints = [];
  List polygonArray = [];
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Create the polylines for showing the route between two places
  _createPolylines(
    double startLatitude,
    double startLongitude,
    double destinationLatitude,
    double destinationLongitude,
  ) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      Secrets.API_KEY, // Google Maps API Key
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;

    /* for (var i = 0; i < polylineCoordinates.length - 1; i++) {
      double R = 6378137;
      double pi = 3.14;

      int upper_offset = 100;
      int lower_offset = -100;

      double lat_up = upper_offset / R;
      double lat_down = lower_offset / R;

      double lat_upper = polylineCoordinates[i].latitude + (lat_up * 180) / pi;
      double lat_lower =
          polylineCoordinates[i].latitude + (lat_down * 180) / pi;
      polygonArray
          .add([lat_upper, lat_lower, polylineCoordinates[i].longitude]);
    }

    List<LatLng> upper_bound = [];
    List<LatLng> lower_bound = [];

    for (var i = 0; i < polygonArray.length - 1; i++) {
      upper_bound.add(LatLng(polygonArray[i][0], polygonArray[i][2]));
      upper_bound.add(LatLng(polygonArray[i][1], polygonArray[i][2]));
    }

    List<LatLng> fullPoly = upper_bound;

    fullLines["full"] = Polyline(
        polylineId: PolylineId('poly'),
        points: fullPoly,
        color: Colors.blue,
        width: 10);
    print(fullLines.values.toString()); */
  }

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        focusNode: focusNode,
        decoration: new InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Stack(children: [
          GoogleMap(
            markers: Set<Marker>.from(markers),
            initialCameraPosition: _initialLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            polylines: Set<Polyline>.of(polylines.values),
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
              mapController.setMapStyle(_nightMapStyle);
              mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(
                      _currentPosition.latitude,
                      _currentPosition.longitude,
                    ),
                    zoom: 18.0,
                  ),
                ),
              );
              _getAddress();
              _startAddress = _currentAddress;
            },
          ),

          /* SafeArea(
            child: Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 10),
                      _textField(
                          label: 'Start',
                          hint: 'Choose starting point',
                          prefixIcon: Icon(Icons.looks_one),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.my_location),
                            onPressed: () {},
                          ),
                          controller: startAddressController,
                          focusNode: startAddressFocusNode,
                          width: width,
                          locationCallback: (String value) {
                            setState(() {});
                          }),
                    ],
                  )
                ],
              ),
            ),
          ), */
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.all(
                      Radius.circular(20.0),
                    ),
                  ),
                  width: width * 0.42,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 10.0, right: 10, left: 10, bottom: 10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _textField(
                                label: 'Destination',
                                hint: 'Choose destination',
                                prefixIcon: Icon(Icons.looks_one),
                                controller: destinationAddressController,
                                focusNode: destinationAddressFocusNode,
                                width: width * 0.5 * 0.6,
                                locationCallback: (String value) {
                                  setState(() {
                                    _destinationAddress = value;
                                  });
                                }),
                            SizedBox(width: 15),
                            ElevatedButton(
                              onPressed: (_startAddress != '' &&
                                      _destinationAddress != '')
                                  ? () async {
                                      startAddressFocusNode.unfocus();
                                      destinationAddressFocusNode.unfocus();
                                      setState(() {
                                        if (markers.isNotEmpty) markers.clear();
                                        if (polylines.isNotEmpty)
                                          polylines.clear();
                                        if (polylineCoordinates.isNotEmpty)
                                          polylineCoordinates.clear();
                                        _placeDistance = null;
                                      });

                                      _calculateDistance();
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(
                                  'Show Route',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.0,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                primary: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 30.0, bottom: 20.0),
                    child: ClipOval(
                      child: Material(
                        color: Color.fromRGBO(6, 18, 32, 0.5), // button color
                        child: InkWell(
                          splashColor:
                              Color.fromRGBO(6, 18, 32, 0.5), // inkwell color
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(
                              Icons.call,
                              color: Colors.green,
                            ),
                          ),
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 30.0, bottom: 20.0),
                    child: ClipOval(
                      child: Material(
                        color: Color.fromRGBO(6, 18, 32, 0.5), // button color
                        child: InkWell(
                          splashColor:
                              Color.fromRGBO(6, 18, 32, 0.5), // inkwell color
                          child: SizedBox(
                            width: 67,
                            height: 67,
                            child: Icon(
                                _speechToText.isNotListening
                                    ? Icons.mic_off
                                    : Icons.mic,
                                color: Colors.white,
                                size: 35),
                          ),
                          onTap: _speechToText.isNotListening
                              ? _startListening
                              : _stopListening,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 30.0, bottom: 20.0),
                    child: ClipOval(
                      child: Material(
                        color: Color.fromRGBO(6, 18, 32, 0.5), // button color
                        child: InkWell(
                          splashColor:
                              Color.fromRGBO(6, 18, 32, 0.5), // inkwell color
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(
                              Icons.shopping_basket,
                              color: Colors.orange,
                            ),
                          ),
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                  padding: const EdgeInsets.only(
                      left: 650.0, bottom: 150.0, right: 15, top: 15),
                  child: Card(
                    elevation: 0.7,
                    child: Column(
                      children: [
                        SizedBox(
                            height: 50,
                            width: 50,
                            child: Card(
                              color: Color.fromRGBO(5, 100, 98, 0.95),
                              child: Text("Your Cart"),
                            )),
                        SizedBox(
                            height: 50,
                            child: Card(
                              color: Color.fromRGBO(5, 100, 98, 0.95),
                              child: Text("Bread"),
                            )),
                        SizedBox(
                            height: 50,
                            child: Card(
                              color: Color.fromRGBO(5, 100, 98, 0.95),
                              child: Text("Bread"),
                            )),
                        SizedBox(height: 50, child: Card()),
                        TextButton(onPressed: () {}, child: Container())
                      ],
                    ),
                  )),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10.0, bottom: 10.0),
                child: ClipOval(
                  child: Material(
                    color: Color.fromRGBO(6, 18, 32, 0.8), // button color
                    child: InkWell(
                      splashColor:
                          Color.fromRGBO(6, 18, 32, 1), // inkwell color
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          Icons.my_location,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () {
                        mapController.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(
                                _currentPosition.latitude,
                                _currentPosition.longitude,
                              ),
                              zoom: 18.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
