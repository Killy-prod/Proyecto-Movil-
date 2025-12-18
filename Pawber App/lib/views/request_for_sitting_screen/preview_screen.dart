// ignore_for_file: must_be_immutable

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:petsitter/utils/assets.dart';
import 'package:petsitter/utils/custom_color.dart';
import 'package:petsitter/utils/dimensions.dart';
import 'package:petsitter/utils/size.dart';
import 'package:petsitter/utils/strings.dart';
import 'package:petsitter/widgets/button/primary_button.dart';
import 'package:petsitter/widgets/others/custom_appbar.dart';
import 'package:petsitter/widgets/others/custom_slider_widget.dart';

import '../../controller/request_for_sitting/preview_controller.dart';
import '../../utils/custom_style.dart';

class PreviewScreen extends StatefulWidget {
  PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final controller = Get.put(PreviewController());
  
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Variables para la ruta - inicializadas con valores por defecto
  LatLng _startPoint = const LatLng(19.4326, -99.1332); // Zócalo por defecto
  LatLng _destination = const LatLng(19.5102, -99.1275); // UPIICSA por defecto
  List<LatLng> _polylineCoordinates = [];
  String _startAddress = 'Punto de partida';
  String _destinationAddress = 'UPIICSA - Instituto Politécnico Nacional';
  String _routeInfo = 'Distancia: -- km • Tiempo: -- min';
  
  // Variable para controlar si ya se procesaron los datos
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _processRouteData();
  }

  void _processRouteData() {
    // Obtener datos pasados desde SetPicupLocationScreen
    final arguments = Get.arguments;
    
    if (arguments != null && arguments is Map) {
      print('Datos recibidos en PreviewScreen: $arguments');
      
      // Actualizar los datos con los recibidos
      if (arguments['startPoint'] != null) {
        _startPoint = arguments['startPoint'];
      }
      
      if (arguments['destination'] != null) {
        _destination = arguments['destination'];
      }
      
      if (arguments['polylineCoordinates'] != null) {
        _polylineCoordinates = List<LatLng>.from(arguments['polylineCoordinates']);
      }
      
      if (arguments['startAddress'] != null) {
        _startAddress = arguments['startAddress'];
      }
      
      if (arguments['destinationAddress'] != null) {
        _destinationAddress = arguments['destinationAddress'];
      }
      
      if (arguments['routeInfo'] != null) {
        _routeInfo = arguments['routeInfo'];
      }
      
      print('Ruta procesada:');
      print('- Inicio: $_startPoint');
      print('- Destino: $_destination');
      print('- Puntos de ruta: ${_polylineCoordinates.length}');
      print('- Dirección inicio: $_startAddress');
      print('- Dirección destino: $_destinationAddress');
    } else {
      print('No se recibieron datos de ruta, usando valores por defecto');
      // Si no hay datos, generar una ruta de ejemplo entre los puntos por defecto
      _polylineCoordinates = _generateCurvedRoute(_startPoint, _destination);
    }
    
    // Añadir marcadores y ruta
    _addMarkers();
    _addRoute();
    
    setState(() {
      _dataLoaded = true;
    });
  }

  List<LatLng> _generateCurvedRoute(LatLng start, LatLng end) {
    // Generar una ruta curvada más realista
    List<LatLng> route = [];
    const int steps = 20;
    
    // Calcular diferencias
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;
    
    // Añadir punto inicial
    route.add(start);
    
    // Generar puntos intermedios con una leve curva
    for (int i = 1; i < steps; i++) {
      double t = i / steps;
      
      // Interpolación lineal con un pequeño desplazamiento sinusoidal para la curva
      double curveFactor = sin(t * pi) * 0.0005; // Factor de curva pequeño
      
      double lat = start.latitude + (latDiff * t) + curveFactor;
      double lng = start.longitude + (lngDiff * t) - curveFactor;
      
      route.add(LatLng(lat, lng));
    }
    
    // Añadir punto final
    route.add(end);
    
    return route;
  }

  void _addMarkers() {
    // Limpiar marcadores anteriores
    _markers.clear();
    
    // Marcador de inicio
    _markers.add(
      Marker(
        markerId: const MarkerId('start_marker'),
        position: _startPoint,
        infoWindow: InfoWindow(
          title: 'Punto de partida',
          snippet: _startAddress.length > 30 ? '${_startAddress.substring(0, 30)}...' : _startAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    
    // Marcador de destino
    _markers.add(
      Marker(
        markerId: const MarkerId('destination_marker'),
        position: _destination,
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: _destinationAddress.length > 30 ? '${_destinationAddress.substring(0, 30)}...' : _destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void _addRoute() {
    // Limpiar rutas anteriores
    _polylines.clear();
    
    List<LatLng> routePoints = _polylineCoordinates;
    
    // Si no hay puntos de ruta, crear una ruta básica
    if (routePoints.isEmpty || routePoints.length < 2) {
      routePoints = [LatLng(_startPoint.latitude - 0.001, _startPoint.longitude - 0.001),
                    _startPoint,
                    LatLng((_startPoint.latitude + _destination.latitude) / 2, 
                          (_startPoint.longitude + _destination.longitude) / 2),
                    _destination,
                    LatLng(_destination.latitude + 0.001, _destination.longitude + 0.001)];
    }
    
    // Añadir la ruta
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        color: CustomColor.primaryColor,
        width: 4,
        points: routePoints,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Ajustar la cámara después de un breve delay para asegurar que el mapa esté listo
    Future.delayed(const Duration(milliseconds: 300), () {
      _fitBounds();
    });
  }

  void _fitBounds() {
    if (_startPoint != null && _destination != null) {
      // Calcular los límites para incluir ambos puntos
      double minLat = _startPoint.latitude < _destination.latitude 
          ? _startPoint.latitude 
          : _destination.latitude;
      double maxLat = _startPoint.latitude > _destination.latitude 
          ? _startPoint.latitude 
          : _destination.latitude;
      double minLng = _startPoint.longitude < _destination.longitude 
          ? _startPoint.longitude 
          : _destination.longitude;
      double maxLng = _startPoint.longitude > _destination.longitude 
          ? _startPoint.longitude 
          : _destination.longitude;
      
      // Añadir un padding para que los marcadores no queden en los bordes
      double padding = 0.01;
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - padding, minLng - padding),
        northeast: LatLng(maxLat + padding, maxLng + padding),
      );
      
      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: CustomAppBar(title: Strings.preview),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      children: [
        _buildMapWidget(context),
        _buildRouteInfoWidget(context),
        _buildDetailsWidget(context),
      ],
    );
  }

  Widget _buildMapWidget(BuildContext context) {
    if (!_dataLoaded) {
      return Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CustomColor.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CustomColor.primaryColor.withOpacity(0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: CustomColor.primaryColor),
              SizedBox(height: 10),
              Text('Cargando ruta...', style: TextStyle(color: CustomColor.primaryColor)),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: 300,
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.defaultPaddingSize * 0.8,
        vertical: Dimensions.defaultPaddingSize * 0.5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (_startPoint.latitude + _destination.latitude) / 2,
              (_startPoint.longitude + _destination.longitude) / 2,
            ),
            zoom: 12,
          ),
          onMapCreated: _onMapCreated,
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  Widget _buildRouteInfoWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.defaultPaddingSize * 0.8,
        vertical: Dimensions.defaultPaddingSize * 0.3,
      ),
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.8),
      decoration: BoxDecoration(
        color: CustomColor.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CustomColor.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: CustomColor.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Ruta establecida',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CustomColor.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Punto de partida
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punto de partida',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _startAddress,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Línea vertical
          Container(
            margin: EdgeInsets.only(left: 3.5),
            width: 1,
            height: 20,
            color: Colors.grey[300],
          ),
          SizedBox(height: 12),
          // Destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destino',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _destinationAddress,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Información de la ruta
          if (_routeInfo.isNotEmpty)
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _routeInfo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Dimensions.defaultPaddingSize * 0.8,
      ),
      child: Column(
        children: [
          _buildLocationDetails(context),
          const Divider(
            color: CustomColor.secondaryTextColor,
            thickness: 1,
          ),
          _buildPetInfoWidget(context),
          const Divider(
            color: CustomColor.secondaryTextColor,
            thickness: 1,
          ),
          _buildSittingChargeWidget(context),
          const Divider(
            color: CustomColor.secondaryTextColor,
            thickness: 1,
          ),
          _buildPaymentMethodWidget(context),
          _buildContinueButton(context),
          _buildCustomSlider(context),
        ],
      ),
    );
  }

  Widget _buildLocationDetails(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimensions.defaultPaddingSize * 0.3,
        top: Dimensions.defaultPaddingSize * 1.2,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SvgPicture.asset(
                Assets.dogSetting,
                color: CustomColor.secondaryTextColor,
              ),
              SizedBox(width: Dimensions.widthSize * 1.7),
              Text(
                Strings.dogSitting,
                style: CustomStyle.previewSubtitleTextStyle,
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize * 1.5),
          Row(
            children: [
              SvgPicture.asset(Assets.calender),
              SizedBox(width: Dimensions.widthSize * 1.7),
              Text(
                Strings.onepetsdate,
                style: CustomStyle.previewSubtitleTextStyle,
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize * 1.5),
          Row(
            children: [
              SvgPicture.asset(
                Assets.location,
                color: CustomColor.secondaryTextColor,
              ),
              SizedBox(width: Dimensions.widthSize * 1.7),
              Expanded(
                child: Text(
                  _destinationAddress,
                  style: CustomStyle.previewSubtitleTextStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize * 1.5),
          Row(
            children: [
              SvgPicture.asset(Assets.clock),
              SizedBox(width: Dimensions.widthSize * 1.7),
              Text(
                Strings.times,
                style: CustomStyle.previewSubtitleTextStyle,
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize * 1.5),
        ],
      ),
    );
  }

  Widget _buildPetInfoWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimensions.defaultPaddingSize * 0.3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: Dimensions.heightSize),
          Text(
            Strings.petsInfo,
            style: CustomStyle.requestSittingTextTitle,
          ),
          SizedBox(height: Dimensions.heightSize),
          Row(
            children: [
              Container(
                height: 100,
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radius),
                  image: const DecorationImage(
                    image: AssetImage(Assets.minidog),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: Dimensions.widthSize * 1.4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${Strings.name}: ',
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                      Text(
                        Strings.grigioCham,
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${Strings.breed}: ',
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                      Text(
                        Strings.abyssinian,
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${Strings.age}: ',
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                      Text(
                        Strings.onetoyear,
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${Strings.weight}: ',
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                      Text(
                        Strings.onefivekg,
                        style: CustomStyle.previewSubtitleTextStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize * 2),
        ],
      ),
    );
  }

  Widget _buildSittingChargeWidget(BuildContext context) {
    // Extraer distancia de _routeInfo para calcular costo de viaje
    double travelCost = 5.0; // Costo base por defecto
    
    try {
      if (_routeInfo.contains('Distancia:')) {
        final parts = _routeInfo.split('•');
        if (parts.isNotEmpty) {
          final distancePart = parts[0].replaceAll('Distancia:', '').replaceAll('km', '').trim();
          final distance = double.tryParse(distancePart.split(' ').first) ?? 0;
          if (distance > 0) {
            travelCost = distance * 2.5; // $2.50 por km
          }
        }
      }
    } catch (e) {
      print('Error calculando costo de viaje: $e');
    }
    
    final total = 50.0 + travelCost;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Dimensions.defaultPaddingSize * 0.3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: Dimensions.heightSize),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Strings.sittingCharge,
                style: CustomStyle.requestSittingTextTitle,
              ),
              Text(
                Strings.viewOurCharges,
                style: CustomStyle.appbarActionTextStyle,
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize * 2),
          _buildChargeRow(Strings.sittingCharge, '\$50.00'),
          SizedBox(height: Dimensions.heightSize),
          _buildChargeRow(Strings.breedCharge, '\$10.00'),
          SizedBox(height: Dimensions.heightSize),
          _buildChargeRow(Strings.travellingCharges, '\$${travelCost.toStringAsFixed(2)}'),
          SizedBox(height: Dimensions.heightSize),
          Divider(color: CustomColor.secondaryTextColor),
          SizedBox(height: Dimensions.heightSize),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: CustomStyle.previewTotalTextStyle,
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: CustomStyle.previewTotalTextStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRow(String title, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: CustomStyle.previewSubtitleTextStyle),
        Text(amount, style: CustomStyle.previewSubtitleTextStyle),
      ],
    );
  }

  Widget _buildPaymentMethodWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Dimensions.defaultPaddingSize * 0.3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: Dimensions.heightSize),
          Text(
            Strings.paymentMethod,
            style: CustomStyle.requestSittingTextTitle,
          ),
          SizedBox(height: Dimensions.heightSize * 2),
          Obx(() {
            final selectedIndex = controller.methodIndex.value;
            return Column(
              children: List.generate(
                controller.paymentMethodList.length,
                (index) {
                  final isSelected = selectedIndex == index;
                  return _buildPaymentMethodItem(
                    controller.paymentMethodList[index],
                    isSelected,
                    () => controller.methodIndex.value = index,
                  );
                },
              ),
            );
          }),
          SizedBox(height: Dimensions.heightSize * 3),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem(
    String title,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: Dimensions.defaultPaddingSize * 0.2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: CustomStyle.previewSubtitleTextStyle),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? CustomColor.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? CustomColor.primaryColor
                      : CustomColor.secondaryTextColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dimensions.defaultPaddingSize),
      child: PrimaryButtonWidget(
        text: Strings.continues,
        onPressed: () => controller.onPressedPreviewContinue(),
      ),
    );
  }

  Widget _buildCustomSlider(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: Dimensions.marginSize),
      child: CustomSliderWidget(value: 60, text: Strings.preview),
    );
  }
}