import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:petsitter/routes/routes.dart';
import 'package:petsitter/utils/assets.dart';
import 'package:petsitter/utils/custom_color.dart';
import 'package:petsitter/utils/size.dart';
import 'package:petsitter/utils/strings.dart';
import 'package:petsitter/widgets/input/input_field.dart';
import 'package:petsitter/widgets/others/custom_appbar.dart';
import 'package:petsitter/widgets/others/custom_slider_widget.dart';
import '../../controller/request_for_sitting/set_picup_location_controller.dart';
import '../../utils/dimensions.dart';
import '../../widgets/button/primary_button.dart';

class SetPicupLocationScreen extends StatefulWidget {
  const SetPicupLocationScreen({Key? key}) : super(key: key);

  @override
  State<SetPicupLocationScreen> createState() => _SetPicupLocationScreenState();
}

class _SetPicupLocationScreenState extends State<SetPicupLocationScreen> {
  final controller = Get.put(PicUpLocationController());
  
  Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  
  // Ubicación de UPIICSA (Instituto Politécnico Nacional, CDMX)
  static const LatLng _upiccaLocation = LatLng(19.5102, -99.1275);
  
  // Posiciones
  LatLng? _selectedStartPoint;
  LatLng? _selectedDestination;
  
  // Modo de selección
  bool _selectingStartPoint = true;
  bool _selectingDestination = false;
  
  // Textos
  String _startPointText = 'Selecciona punto de partida';
  String _destinationText = 'Selecciona destino';
  
  // Estado de carga
  bool _loadingRoute = false;
  String _routeInfo = '';
  String _estimatedTime = '';
  String _distance = '';
  
  // Tu API Key de Google Maps
  static const String _googleMapsApiKey = 'AIzaSyCds2TqWsrlS-3xJpeBYzf6f76JhuXtb7c';
  
  // Control del panel desplegable
  double _panelPosition = 0.25;
  bool _isPanelExpanded = false;
  final double _panelMinHeight = 0.25;
  final double _panelMaxHeight = 0.7;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setInitialLocations();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _selectedStartPoint = LatLng(position.latitude, position.longitude);
        _startPointText = 'Mi ubicación actual';
        _updateStartMarker(_selectedStartPoint!);
      });
      
      final GoogleMapController googleMapController = await _controller.future;
      googleMapController.animateCamera(
        CameraUpdate.newLatLng(_selectedStartPoint!),
      );
      
      if (_selectedDestination != null) {
        _getRoute();
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  void _setInitialLocations() {
    setState(() {
      _selectedDestination = _upiccaLocation;
      _destinationText = 'UPIICSA - Instituto Politécnico Nacional';
    });
    
    _addDestinationMarker(_selectedDestination!);
  }

  void _addDestinationMarker(LatLng position) {
    _markers.removeWhere((marker) => marker.markerId.value == 'destination_marker');
    
    _markers.add(
      Marker(
        markerId: MarkerId('destination_marker'),
        position: position,
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: _destinationText,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        draggable: true,
        onDragEnd: (newPosition) {
          _updateDestination(newPosition);
        },
      ),
    );
    
    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  void _onMapTap(LatLng position) {
    if (_selectingStartPoint) {
      _setStartPoint(position);
    } else if (_selectingDestination) {
      _setDestination(position);
    }
  }

  void _setStartPoint(LatLng position) {
    setState(() {
      _selectedStartPoint = position;
      _startPointText = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      _selectingStartPoint = false;
    });
    
    _updateStartMarker(position);
    _getRoute();
  }

  void _setDestination(LatLng position) {
    setState(() {
      _selectedDestination = position;
      _destinationText = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      _selectingDestination = false;
    });
    
    _addDestinationMarker(position);
    _getRoute();
  }

  void _updateStartMarker(LatLng position) {
    _markers.removeWhere((marker) => marker.markerId.value == 'startpoint_marker');
    
    _markers.add(
      Marker(
        markerId: MarkerId('startpoint_marker'),
        position: position,
        infoWindow: InfoWindow(
          title: 'Punto de partida',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        draggable: true,
        onDragEnd: (newPosition) {
          _setStartPoint(newPosition);
        },
      ),
    );
    
    setState(() {});
  }

  void _updateDestination(LatLng position) {
    setState(() {
      _selectedDestination = position;
      _destinationText = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
    });
    
    _addDestinationMarker(position);
    _getRoute();
  }

  Future<void> _getRoute() async {
    if (_selectedStartPoint == null || _selectedDestination == null) return;
    
    setState(() {
      _loadingRoute = true;
      _routeInfo = 'Calculando ruta...';
    });
    
    try {
      // Primero calcular la distancia en línea recta para tener una estimación
      double straightDistance = _calculateDistance(
        _selectedStartPoint!.latitude,
        _selectedStartPoint!.longitude,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
      );
      
      // Estimar tiempo basado en distancia a pie (promedio 5 km/h)
      int estimatedMinutes = (straightDistance / 0.083).toInt(); // 5 km/h = 0.083 km/min
      if (estimatedMinutes < 1) estimatedMinutes = 1;
      
      // Mostrar estimación inicial
      setState(() {
        _distance = '${straightDistance.toStringAsFixed(2)} km';
        _estimatedTime = '$estimatedMinutes min';
        _routeInfo = 'Distancia: $_distance • Tiempo a pie: ~$_estimatedTime';
      });
      
      // Intentar obtener la ruta real de Google Maps para caminar
      try {
        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          _googleMapsApiKey,
          PointLatLng(_selectedStartPoint!.latitude, _selectedStartPoint!.longitude),
          PointLatLng(_selectedDestination!.latitude, _selectedDestination!.longitude),
          travelMode: TravelMode.walking, // Cambiado de driving a walking
        );
        
        if (result.points.isNotEmpty) {
          _polylineCoordinates.clear();
          for (var point in result.points) {
            _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
          
          // Calcular distancia total de la ruta real
          double routeDistance = _calculateRouteDistance(_polylineCoordinates);
          
          // Recalcular tiempo estimado basado en distancia real para caminar
          int routeMinutes = (routeDistance / 0.083).toInt(); // 5 km/h = 0.083 km/min
          if (routeMinutes < 1) routeMinutes = 1;
          
          setState(() {
            _distance = '${routeDistance.toStringAsFixed(2)} km';
            _estimatedTime = '$routeMinutes min';
            _routeInfo = 'Distancia: $_distance • Tiempo a pie: ~$_estimatedTime';
          });
          
          _updateRoute();
        } else {
          // Si no hay puntos, usar línea recta
          _drawStraightRoute();
        }
      } catch (apiError) {
        print('Error de API de Google: $apiError');
        // En caso de error de API, usar línea recta
        _drawStraightRoute();
      }
    } catch (e) {
      print('Error obteniendo ruta: $e');
      _drawStraightRoute();
    } finally {
      setState(() {
        _loadingRoute = false;
      });
    }
  }

  double _calculateRouteDistance(List<LatLng> points) {
    double totalDistance = 0.0;
    
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _calculateDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    
    return totalDistance;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radio de la Tierra en kilómetros
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _updateRoute() {
    _polylines.clear();
    
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        color: CustomColor.primaryColor,
        width: 4,
        points: _polylineCoordinates,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
    
    _fitBounds();
  }

  void _drawStraightRoute() {
    _polylines.clear();
    
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        color: CustomColor.primaryColor.withOpacity(0.7),
        width: 3,
        points: [_selectedStartPoint!, _selectedDestination!],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
    
    _fitBounds();
  }

  void _fitBounds() {
    if (_selectedStartPoint != null && _selectedDestination != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _selectedStartPoint!.latitude < _selectedDestination!.latitude 
            ? _selectedStartPoint!.latitude 
            : _selectedDestination!.latitude,
          _selectedStartPoint!.longitude < _selectedDestination!.longitude 
            ? _selectedStartPoint!.longitude 
            : _selectedDestination!.longitude,
        ),
        northeast: LatLng(
          _selectedStartPoint!.latitude > _selectedDestination!.latitude 
            ? _selectedStartPoint!.latitude 
            : _selectedDestination!.latitude,
          _selectedStartPoint!.longitude > _selectedDestination!.longitude 
            ? _selectedStartPoint!.longitude 
            : _selectedDestination!.longitude,
        ),
      );
      
      _controller.future.then((googleMapController) {
        googleMapController.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      });
    }
  }

  void _enableStartPointSelection() {
    setState(() {
      _selectingStartPoint = true;
      _selectingDestination = false;
    });
    
    Get.snackbar(
      'Selección activada',
      'Toca en el mapa para seleccionar el punto de partida',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
    );
  }

  void _enableDestinationSelection() {
    setState(() {
      _selectingDestination = true;
      _selectingStartPoint = false;
    });
    
    Get.snackbar(
      'Selección activada',
      'Toca en el mapa para seleccionar el destino',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
    );
  }

  void _swapLocations() {
    if (_selectedStartPoint != null && _selectedDestination != null) {
      setState(() {
        final temp = _selectedStartPoint;
        _selectedStartPoint = _selectedDestination;
        _selectedDestination = temp;
        
        final tempText = _startPointText;
        _startPointText = _destinationText;
        _destinationText = tempText;
      });
      
      _updateStartMarker(_selectedStartPoint!);
      _addDestinationMarker(_selectedDestination!);
      _getRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: CustomAppBar(title: Strings.setPicupLocation),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _upiccaLocation,
              zoom: 13,
            ),
            onMapCreated: _onMapCreated,
            markers: _markers,
            polylines: _polylines,
            onTap: _onMapTap,
            myLocationEnabled: false, // Cambiado a false para quitar el símbolo verde
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
          //_bodyWidget(context),
          _selectionIndicator(),
          if (_loadingRoute) _loadingIndicator(),
          // Panel desplegable
          _buildDraggablePanel(context),
          // Indicador rápido de selección
          _buildQuickSelectionIndicator(),
        ],
      ),
    );
  }

  Widget _buildQuickSelectionIndicator() {
    if (_selectingStartPoint || _selectingDestination) {
      return Positioned(
        top: 50,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: CustomColor.primaryColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectingStartPoint ? Icons.place : Icons.location_on,
                color: Colors.white,
              ),
              SizedBox(width: 3),
              Text(
                _selectingStartPoint 
                  ? 'Toca en el mapa para seleccionar punto de partida'
                  : 'Toca en el mapa para seleccionar destino',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildDraggablePanel(BuildContext context) {
    return Positioned.fill(
      top: MediaQuery.of(context).size.height * (1 - _panelPosition),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _panelPosition -= details.delta.dy / MediaQuery.of(context).size.height;
            _panelPosition = _panelPosition.clamp(_panelMinHeight, _panelMaxHeight);
            _isPanelExpanded = _panelPosition > _panelMinHeight + 0.1;
          });
        },
        onVerticalDragEnd: (details) {
          setState(() {
            // Ajustar a posiciones predefinidas
            if (_panelPosition > (_panelMaxHeight + _panelMinHeight) / 2) {
              _panelPosition = _panelMaxHeight;
              _isPanelExpanded = true;
            } else {
              _panelPosition = _panelMinHeight;
              _isPanelExpanded = false;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: CustomColor.secondearyColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de arrastre
              Container(
                height: 40,
                child: Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              // Contenido del panel
              Expanded(
                child: _isPanelExpanded 
                    ? _buildExpandedPanel(context)
                    : _buildCollapsedPanel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedPanel(BuildContext context) {
    return Column(
      children: [
        // Punto de partida y destino (vista compacta)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Punto de partida
                _buildCompactLocationCard(
                  title: 'Punto de partida',
                  subtitle: _startPointText,
                  color: Colors.blue,
                  onTap: _enableStartPointSelection,
                ),
                SizedBox(height: 10),
                // Destino
                _buildCompactLocationCard(
                  title: 'Destino',
                  subtitle: _destinationText,
                  color: Colors.red,
                  onTap: _enableDestinationSelection,
                ),
                // Información de ruta resumida
                if (_selectedStartPoint != null && _selectedDestination != null && _routeInfo.isNotEmpty)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CustomColor.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CustomColor.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_walk, color: CustomColor.primaryColor, size: 16),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _routeInfo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Botón para expandir
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _panelPosition = _panelMaxHeight;
                    _isPanelExpanded = true;
                  });
                },
                icon: Icon(Icons.expand_less, color: CustomColor.primaryColor),
              ),
              Expanded(
                child: Text(
                  'Desliza hacia arriba para más opciones',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _panelPosition = _panelMaxHeight;
                    _isPanelExpanded = true;
                  });
                },
                icon: Icon(Icons.expand_less, color: CustomColor.primaryColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedPanel(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: EdgeInsets.all(Dimensions.marginSize),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón para colapsar
            Center(
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _panelPosition = _panelMinHeight;
                    _isPanelExpanded = false;
                  });
                },
                icon: Icon(Icons.expand_more, color: CustomColor.primaryColor),
              ),
            ),
            
            // Botón para intercambiar ubicaciones
            if (_selectedStartPoint != null && _selectedDestination != null)
              Align(
                alignment: Alignment.center,
                child: IconButton(
                  onPressed: _swapLocations,
                  icon: Icon(Icons.swap_vert, color: CustomColor.primaryColor),
                ),
              ),
            
            // Punto de partida
            _buildLocationCard(
              title: 'Punto de partida',
              subtitle: _startPointText,
              color: Colors.blue,
              onTap: _enableStartPointSelection,
              icon: Icons.place,
            ),
            
            SizedBox(height: Dimensions.heightSize),
            
            // Destino
            _buildLocationCard(
              title: 'Destino',
              subtitle: _destinationText,
              color: Colors.red,
              onTap: _enableDestinationSelection,
              icon: Icons.location_on,
            ),
            
            SizedBox(height: Dimensions.heightSize * 1.5),
            
            // Información detallada de la ruta
            if (_selectedStartPoint != null && _selectedDestination != null && _routeInfo.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomColor.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CustomColor.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_walk, color: CustomColor.primaryColor),
                        SizedBox(width: 10),
                        Text(
                          'Ruta a pie',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildRouteInfoItem(
                          icon: Icons.straighten,
                          title: 'Distancia',
                          value: _distance,
                          color: Colors.green,
                        ),
                        _buildRouteInfoItem(
                          icon: Icons.timer,
                          title: 'Tiempo a pie',
                          value: _estimatedTime,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Nota: El tiempo es estimado para caminar (5 km/h)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            
            SizedBox(height: Dimensions.heightSize),
            
            // Botón para usar mi ubicación
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: Icon(Icons.my_location, size: 20),
              label: Text('Usar mi ubicación actual'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CustomColor.primaryColor,
                minimumSize: Size(double.infinity, 45),
                side: BorderSide(color: CustomColor.primaryColor),
              ),
            ),
            
            SizedBox(height: Dimensions.heightSize),
            
            // Botón principal (Establecer ubicación)
            PrimaryButtonWidget(
              text: Strings.setPicupLocation,
              onPressed: () {
                if (_selectedStartPoint == null || _selectedDestination == null) {
                  Get.snackbar(
                    'Completa la información',
                    'Por favor selecciona tanto el punto de partida como el destino',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
                
                // Pasar datos a PreviewScreen
                Get.toNamed(Routes.previewScreen, arguments: {
                  'startPoint': _selectedStartPoint,
                  'destination': _selectedDestination,
                  'polylineCoordinates': _polylineCoordinates,
                  'startAddress': _startPointText,
                  'destinationAddress': _destinationText,
                  'routeInfo': _routeInfo,
                });
              },
            ),
            
            SizedBox(height: Dimensions.heightSize * 1.3),
            
            // Botón de ubicación guardada
            PrimaryButtonWidget(
              text: Strings.savedLocation,
              borderColor: CustomColor.primaryColor,
              backgroundColor: CustomColor.transparent,
              textColor: CustomColor.primaryColor,
              onPressed: () {
                Get.toNamed(Routes.requestSettingSavedLocationScreen);
              },
            ),
            
            SizedBox(height: 20), // Espacio adicional al final
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLocationCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ListTile(
          dense: true,
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            Icons.touch_app,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.marginSize, 
        vertical: Dimensions.marginSize * 0.6,
      ),
      child: Column(
        children: [
          CustomSliderWidget(value: 45, text: Strings.setPicupLocation),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height / 4.4,
              right: MediaQuery.of(context).size.height / 6,
            ),
            child: SvgPicture.asset(
              Assets.locate,
              height: Dimensions.heightSize * 3,
            ),
          ),
          Spacer(),
          // Botón para centrar en ruta
          if (_selectedStartPoint != null && _selectedDestination != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(
                  right: Dimensions.widthSize,
                  bottom: Dimensions.heightSize * 2,
                ),
                child: FloatingActionButton(
                  backgroundColor: CustomColor.primaryColor,
                  onPressed: _fitBounds,
                  child: Icon(Icons.zoom_out_map, color: Colors.white),
                ),
              ),
            ),
          // Botones de selección rápida
          if (!_selectingStartPoint && !_selectingDestination)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: Dimensions.heightSize * 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.small(
                      backgroundColor: Colors.blue,
                      onPressed: _enableStartPointSelection,
                      child: Icon(Icons.place, color: Colors.white),
                      heroTag: 'start_button',
                    ),
                    SizedBox(width: 20),
                    FloatingActionButton.small(
                      backgroundColor: Colors.red,
                      onPressed: _enableDestinationSelection,
                      child: Icon(Icons.location_on, color: Colors.white),
                      heroTag: 'dest_button',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionIndicator() {
    if (_selectingStartPoint || _selectingDestination) {
      return Positioned(
        top: 5,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: CustomColor.primaryColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              _selectingStartPoint 
                ? 'Toca en el mapa para seleccionar el punto de partida'
                : 'Toca en el mapa para seleccionar el destino',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _loadingIndicator() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Calculando ruta a pie...'),
            SizedBox(height: 5),
            Text(
              'Obteniendo información de Google Maps',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}