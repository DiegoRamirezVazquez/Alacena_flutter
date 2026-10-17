import 'package:flutter/material.dart';

import '../database/alacena_db.dart';

import '../widgets/app_bar_comun.dart';
import '../widgets/menu_lateral.dart';
import '../widgets/barra_navegacion.dart';

import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/screens/notificaciones_screen.dart';

// =============================================================
// 1. PANTALLA PRINCIPAL
// =============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ===========================================================
  // 2. VARIABLES
  // ===========================================================

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  int paginaSeleccionada = 0;

  int totalProductos = 0;
  int stockBajo = 0;
  int porCaducar = 0;
  int enCarrito = 0;

  // ===========================================================
  // 3. INICIALIZACIÓN
  // ===========================================================

  @override
  void initState() {
    super.initState();
    cargarResumen();
  }

  // ===========================================================
  // 4. CARGAR RESUMEN DE LA ALACENA Y CARRITO
  // ===========================================================

  Future<void> cargarResumen() async {
    try {
      final db = await AlacenaDB().database;

      final resultadoProductos = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM PRODUCTOS',
      );

      final resultadoStock = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM (
          SELECT
            p.id_producto,
            p.stock_minimo,
            COALESCE(SUM(l.cantidad), 0) AS cantidad_total
          FROM PRODUCTOS p
          LEFT JOIN LOTES l
            ON l.producto_id = p.id_producto
          GROUP BY p.id_producto, p.stock_minimo
        ) AS inventario
        WHERE cantidad_total <= stock_minimo
      ''');

      final resultadoCaducidad = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM LOTES
        WHERE fecha_caducidad <= date('now', '+5 days')
          AND cantidad > 0
      ''');

      final resultadoCarrito = await db.rawQuery('''
        SELECT COALESCE(SUM(cantidad), 0) AS total
        FROM CARRITO
      ''');

      if (!mounted) return;

      setState(() {
        totalProductos =
            (resultadoProductos.first['total'] as num?)?.toInt() ?? 0;

        stockBajo =
            (resultadoStock.first['total'] as num?)?.toInt() ?? 0;

        porCaducar =
            (resultadoCaducidad.first['total'] as num?)?.toInt() ?? 0;

        enCarrito =
            (resultadoCarrito.first['total'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      debugPrint('Error al cargar el resumen: $e');
    }
  }

  // ===========================================================
  // 5. NAVEGACIÓN A OTRAS PANTALLAS
  // ===========================================================

  Future<void> abrirPantalla(Widget pantalla) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => pantalla,
      ),
    );

    if (!mounted) return;

    await cargarResumen();
  }

  // ===========================================================
  // 5.1. ABRIR NOTIFICACIONES
  // ===========================================================

  Future<void> abrirNotificaciones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificacionesScreen(),
      ),
    );

    if (!mounted) return;

    await cargarResumen();
  }

  void mostrarMensaje(String seccion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$seccion: próximamente'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================
  // 6. ABRIR ACCESOS DEL MENÚ
  // ===========================================================

  void seleccionarAcceso(String opcion) {
    switch (opcion) {
      case 'productos':
        abrirPantalla(const ProductosScreen());
        break;

      case 'categorias':
        abrirPantalla(const CategoriaScreen());
        break;

      case 'tiendas':
        abrirPantalla(const TiendasScreen());
        break;

      case 'lotes':
        abrirPantalla(const LotesScreen());
        break;

      case 'carrito':
        abrirPantalla(const CarritoScreen());
        break;

      case 'historial':
        abrirPantalla(const HistorialCompraScreen());
        break;
    }
  }

  Future<void> abrirCarrito() async {
    await abrirPantalla(const CarritoScreen());
  }

  void volverAInicio() {
    Navigator.popUntil(context, (route) => route.isFirst);

    if (!mounted) return;

    setState(() {
      paginaSeleccionada = 0;
    });

    cargarResumen();
  }

  Future<void> cambiarSeccionPrincipal(int indice) async {
    if (indice == 0) {
      volverAInicio();
      return;
    }

    final Widget pantalla = indice == 1
        ? const AlacenaScreen()
        : const CalendarioScreen();

    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => pantalla,
      ),
      (route) => route.isFirst,
    );

    if (!mounted) return;

    await cargarResumen();
  }

  void cerrarMenuYAbrir(Future<void> Function() accion) {
    Navigator.pop(context);
    accion();
  }

  // ===========================================================
  // 7. CONSTRUIR LA INTERFAZ
  // ===========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // Barra superior compartida.
      appBar: AppBarComun(
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificaciones: abrirNotificaciones,
        onCarrito: abrirCarrito,
        cantidadCarrito: enCarrito,
      ),

      // Menú lateral.
      drawer: MenuLateral(
        onInicio: () {
          Navigator.pop(context);
          volverAInicio();
        },
        onProductos: () => cerrarMenuYAbrir(() async {
          await abrirPantalla(const ProductosScreen());
        }),
        onCategorias: () => cerrarMenuYAbrir(() async {
          await abrirPantalla(const CategoriaScreen());
        }),
        onTiendas: () => cerrarMenuYAbrir(() async {
          await abrirPantalla(const TiendasScreen());
        }),
        onLotes: () => cerrarMenuYAbrir(() async {
          await abrirPantalla(const LotesScreen());
        }),
        onAlacena: () {
          Navigator.pop(context);
          cambiarSeccionPrincipal(1);
        },
        onCalendario: () {
          Navigator.pop(context);
          cambiarSeccionPrincipal(2);
        },
        onCarrito: () => cerrarMenuYAbrir(() async {
          await abrirPantalla(const CarritoScreen());
        }),
        onHistorial: () => cerrarMenuYAbrir(() async {
          await abrirPantalla(const HistorialCompraScreen());
        }),
      ),

      // =======================================================
      // 7.1. CONTENIDO PRINCIPAL
      // =======================================================

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '¡Hola!',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Para mantener tu alacena organizada.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 22),

            // Tarjeta de bienvenida.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF397653),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu alacena, organizada.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Organiza tus productos y evita '
                          'desperdiciar alimentos.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(
                    Icons.kitchen,
                    color: Colors.white,
                    size: 62,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // Resumen de la alacena.
            const Text(
              'Resumen de tu alacena',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.65,
              children: [
                tarjetaResumen(
                  'Productos',
                  '$totalProductos',
                  Icons.inventory_2_outlined,
                  const Color(0xFFE1EFDF),
                ),
                tarjetaResumen(
                  'Stock bajo',
                  '$stockBajo',
                  Icons.warning_amber_rounded,
                  const Color(0xFFFFEBCB),
                ),
                tarjetaResumen(
                  'Por caducar',
                  '$porCaducar',
                  Icons.event_busy_outlined,
                  const Color(0xFFFFDFDA),
                ),
                tarjetaResumen(
                  'En carrito',
                  '$enCarrito',
                  Icons.shopping_cart_outlined,
                  const Color(0xFFE7E0F7),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // Consejo del día.
            const Text(
              'Consejo del día',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE2E8DD),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF397653),
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Coloca al frente los alimentos que '
                      'caducan antes para utilizarlos primero '
                      'y reducir el desperdicio.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // =======================================================
      // 7.2. BOTÓN PARA REGISTRAR UNA COMPRA
      // =======================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          abrirPantalla(
            const HistorialCompraScreen(
              abrirFormularioAlEntrar: true,
            ),
          );
        },
        backgroundColor: const Color(0xFF397653),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_basket_outlined),
        label: const Text('Registrar compra'),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,

      // =======================================================
      // 7.3. BARRA INFERIOR
      // =======================================================

      bottomNavigationBar: BarraNavegacion(
        indiceSeleccionado: 0,
        alSeleccionar: cambiarSeccionPrincipal,
      ),
    );
  }

  // ===========================================================
  // 8. TARJETAS DEL RESUMEN
  // ===========================================================

  Widget tarjetaResumen(
    String titulo,
    String cantidad,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icono,
                size: 24,
                color: const Color(0xFF315B40),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF234B35),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            cantidad,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: Color(0xFF234B35),
            ),
          ),
        ],
      ),
    );
  }
}