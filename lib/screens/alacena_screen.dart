import 'dart:io';

import 'package:flutter/material.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';
import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/dao/lotes_dao.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/notificaciones_screen.dart';

class AlacenaScreen extends StatefulWidget {
  const AlacenaScreen({super.key});

  @override
  State<AlacenaScreen> createState() => _AlacenaScreenState();
}

class _AlacenaScreenState extends State<AlacenaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LotesDB lotesDB = LotesDB();
  int enCarrito = 0;

  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> lotesPorCaducar = [];

  bool cargando = true;
  String busqueda = '';
  String categoriaSeleccionada = 'Todas';
  final Set<int> consumosEnProceso = {};

  static const Color verde = Color(0xFF397653);
  static const Color verdeOscuro = Color(0xFF234B35);
  static const Color verdeClaro = Color(0xFFE1EFDF);
  static const Color fondo = Color(0xFFF7F8F4);
  static const Color rojo = Color(0xFFB42318);
  static const Color amarillo = Color(0xFF9A6700);

  @override
  void initState() {
    super.initState();
    cargarProductos();
    cargarCantidadCarrito();
  }

  Future<void> cargarCantidadCarrito() async {
    try {
      final db = await AlacenaDB().database;
      final resultado = await db.rawQuery(
        'SELECT COALESCE(SUM(cantidad), 0) AS total FROM CARRITO',
      );
      if (!mounted) return;
      setState(() {
        enCarrito = (resultado.first['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // El contador no debe impedir que se abra la alacena.
    }
  }

  Future<void> cargarProductos() async {
    if (mounted) setState(() => cargando = true);

    try {
      final db = await AlacenaDB().database;
      final resultado = await lotesDB.SELECT_INVENTARIO();

      final alertas = await db.rawQuery('''
        SELECT
          p.id_producto,
          p.nombre AS nombre_producto,
          p.imagen,
          c.nombre AS nombre_categoria,
          l.id_lote,
          l.cantidad AS cantidad_lote,
          l.fecha_caducidad,
          p.dias_alerta_caducidad,
          CAST(
            julianday(date(l.fecha_caducidad)) -
            julianday(date('now', 'localtime'))
            AS INTEGER
          ) AS dias_restantes
        FROM LOTES l
        INNER JOIN PRODUCTOS p
          ON p.id_producto = l.producto_id
        INNER JOIN CATEGORIA c
          ON c.id_categoria = p.categoria_id
        WHERE l.cantidad > 0
          AND l.alarma_habilitada = 1
          AND date(l.fecha_caducidad) IS NOT NULL
          AND date(l.fecha_caducidad) <= date(
            'now', 'localtime',
            '+' || COALESCE(p.dias_alerta_caducidad, 5) || ' days'
          )
        ORDER BY date(l.fecha_caducidad) ASC
      ''');

      if (!mounted) return;

      setState(() {
        productos = resultado;
        lotesPorCaducar = alertas;
        cargando = false;

        if (!categorias.contains(categoriaSeleccionada)) {
          categoriaSeleccionada = 'Todas';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar la alacena: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<String> get categorias {
    final lista = productos
        .map((p) => p['nombre_categoria']?.toString() ?? '')
        .where((nombre) => nombre.isNotEmpty)
        .toSet()
        .toList();

    lista.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return ['Todas', ...lista];
  }

  bool coincideFiltro(Map<String, dynamic> producto) {
    final nombre =
        (producto['nombre_producto'] ?? '').toString().toLowerCase();
    final categoria =
        (producto['nombre_categoria'] ?? '').toString();

    return nombre.contains(busqueda.trim().toLowerCase()) &&
        (categoriaSeleccionada == 'Todas' ||
            categoria == categoriaSeleccionada);
  }

  List<Map<String, dynamic>> get productosFiltrados =>
      productos.where(coincideFiltro).toList();

  List<Map<String, dynamic>> get productosPorAgotarse =>
      productosFiltrados.where((p) {
        final cantidad = (p['cantidad_total'] as num?)?.toInt() ?? 0;
        final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 1;
        return cantidad <= minimo;
      }).toList();

  List<Map<String, dynamic>> get lotesCaducidadFiltrados =>
      lotesPorCaducar.where(coincideFiltro).toList();

  int cantidad(Map<String, dynamic> producto) =>
      (producto['cantidad_total'] as num?)?.toInt() ?? 0;

  int stockMinimo(Map<String, dynamic> producto) =>
      (producto['stock_minimo'] as num?)?.toInt() ?? 1;

  // CONSULTAR EXISTENCIAS QUE PUEDEN CONSUMIRSE.
  // Los lotes caducados no se consideran disponibles para consumo.
  Future<int> _consultarDisponible(int idProducto) async {
    final db = await AlacenaDB().database;

    final resultado = await db.rawQuery('''
      SELECT COALESCE(SUM(cantidad), 0) AS disponible
      FROM LOTES
      WHERE producto_id = ?
        AND cantidad > 0
        AND date(fecha_caducidad) >= date('now', 'localtime')
    ''', [idProducto]);

    return (resultado.first['disponible'] as num?)?.toInt() ?? 0;
  }

  
Future<void> _mostrarDialogoConsumo(
  Map<String, dynamic> producto,
) async {
  final idProducto = (producto['id_producto'] as num).toInt();

  if (consumosEnProceso.contains(idProducto)) return;

  final disponible = await _consultarDisponible(idProducto);

  if (!mounted) return;

  if (disponible <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No hay unidades disponibles en lotes vigentes para consumir.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Ya no utilizamos TextEditingController.
  // Esto evita que el TextField intente usar un controlador destruido.
  String textoUnidades = '';
  String? error;

  final unidades = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (contextDialogo, actualizarDialogo) {
          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('Registrar consumo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre_producto']?.toString() ?? 'Producto',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: verdeOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Disponibles para consumir: $disponible'),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (valor) {
                    textoUnidades = valor;
                    if (error != null) {
                      actualizarDialogo(() {
                        error = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Unidades utilizadas',
                    hintText: 'Ej. 2',
                    prefixIcon: const Icon(
                      Icons.remove_circle_outline,
                      color: verde,
                    ),
                    errorText: error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Se descontarán primero las unidades del lote '
                  'con la fecha de caducidad más próxima.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: verde,
                ),
                onPressed: () {
                  final valor = int.tryParse(textoUnidades.trim());

                  if (valor == null || valor <= 0) {
                    actualizarDialogo(() {
                      error = 'Ingresa un entero mayor que cero.';
                    });
                    return;
                  }

                  if (valor > disponible) {
                    actualizarDialogo(() {
                      error =
                          'Solo tienes $disponible unidades disponibles.';
                    });
                    return;
                  }

                  Navigator.pop(dialogContext, valor);
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirmar'),
              ),
            ],
          );
        },
      );
    },
  );

  // Si se cancela el diálogo, no se modifica el inventario.
  if (unidades == null || !mounted) return;

  await _registrarConsumo(idProducto, unidades);
}


  // Agrega el producto a la lista de compra.
  // Si ya existe en el carrito, incrementa su cantidad en una unidad.
  Future<void> _agregarAlCarrito(Map<String, dynamic> producto) async {
    final idProducto = (producto['id_producto'] as num).toInt();
    final nombre = producto['nombre_producto']?.toString() ?? 'Producto';

    try {
      final db = await AlacenaDB().database;
      final ahora = DateTime.now().toIso8601String();

      await db.rawInsert(
        '''
        INSERT INTO CARRITO (producto_id, cantidad, fecha_agregado)
        VALUES (?, 1, ?)
        ON CONFLICT(producto_id)
        DO UPDATE SET cantidad = cantidad + 1
        ''',
        [idProducto, ahora],
      );

      await cargarCantidadCarrito();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nombre se agregó a la lista de compra.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: verdeOscuro,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo agregar al carrito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // DESCONTAR AUTOMÁTICAMENTE POR FEFO DENTRO DE UNA TRANSACCIÓN.
  Future<void> _registrarConsumo(
    int idProducto,
    int unidades,
  ) async {
    if (consumosEnProceso.contains(idProducto)) return;

    setState(() => consumosEnProceso.add(idProducto));

    try {
      final db = await AlacenaDB().database;

      await db.transaction((txn) async {
        final lotes = await txn.rawQuery('''
          SELECT id_lote, cantidad, fecha_caducidad
          FROM LOTES
          WHERE producto_id = ?
            AND cantidad > 0
            AND date(fecha_caducidad) >= date('now', 'localtime')
          ORDER BY date(fecha_caducidad) ASC, id_lote ASC
        ''', [idProducto]);

        final disponible = lotes.fold<int>(
          0,
          (total, lote) =>
              total + ((lote['cantidad'] as num?)?.toInt() ?? 0),
        );

        if (unidades > disponible) {
          throw Exception(
            'Las existencias cambiaron. Actualiza la pantalla e inténtalo de nuevo.',
          );
        }

        var pendiente = unidades;

        for (final lote in lotes) {
          if (pendiente == 0) break;

          final idLote = (lote['id_lote'] as num).toInt();
          final cantidadLote =
              (lote['cantidad'] as num).toInt();

          final descontar =
              pendiente < cantidadLote ? pendiente : cantidadLote;

          final nuevaCantidad = cantidadLote - descontar;

          final filas = await txn.update(
            'LOTES',
            {'cantidad': nuevaCantidad},
            where: 'id_lote = ? AND cantidad = ?',
            whereArgs: [idLote, cantidadLote],
          );

          if (filas != 1) {
            throw Exception(
              'No se pudo actualizar el lote $idLote.',
            );
          }

          pendiente -= descontar;
        }

        if (pendiente != 0) {
          throw Exception('No se pudo completar el consumo.');
        }
      });

      if (!mounted) return;

      await cargarProductos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Consumo registrado: $unidades ${unidades == 1 ? 'unidad' : 'unidades'}.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: verdeOscuro,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el consumo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => consumosEnProceso.remove(idProducto));
      }
    }
  }

  // ===========================================================
  // NAVEGACIÓN A LAS PANTALLAS DEL MENÚ PRINCIPAL
  // ===========================================================

  Future<void> abrirPantalla(Widget pantalla) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );

    if (!mounted) return;

    await cargarProductos();
    await cargarCantidadCarrito();
  }

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
      case 'calendario':
        abrirPantalla(const CalendarioScreen());
        break;
      case 'carrito':
        abrirPantalla(const CarritoScreen());
        break;
      case 'historial':
        abrirPantalla(const HistorialCompraScreen());
        break;
    }
  }

  Future<void> _seleccionarNavegacion(int indice) async {
    if (indice == 1) return;
    if (indice == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CalendarioScreen()),
      (route) => route.isFirst,
    );
  }

  void _cerrarMenu() => Navigator.pop(context);

  void _irAInicioDesdeMenu() {
    _cerrarMenu();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _irASeccionDesdeMenu(Widget pantalla) {
    _cerrarMenu();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
      (route) => route.isFirst,
    );
  }

  void _abrirDesdeMenu(Widget pantalla) {
    _cerrarMenu();
    abrirPantalla(pantalla);
  }

  @override
  Widget build(BuildContext context) {
    final totalUnidades = productos.fold<int>(
      0,
      (total, p) => total + cantidad(p),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: fondo,
      appBar: AppBarComun(
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificaciones: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificacionesScreen(),
            ),
          );
        },
        onCarrito: () => abrirPantalla(const CarritoScreen()),
        cantidadCarrito: enCarrito,
      ),

      // =======================================================
      // 7.2. MENÚ LATERAL DERECHO
      // Se abre desde la derecha hacia el interior.
      // =======================================================
      drawer: MenuLateral(
        onInicio: _irAInicioDesdeMenu,
        onProductos: () => _abrirDesdeMenu(const ProductosScreen()),
        onCategorias: () => _abrirDesdeMenu(const CategoriaScreen()),
        onTiendas: () => _abrirDesdeMenu(const TiendasScreen()),
        onLotes: () => _abrirDesdeMenu(const LotesScreen()),
        onAlacena: _cerrarMenu,
        onCalendario: () => _irASeccionDesdeMenu(const CalendarioScreen()),
        onCarrito: () => _abrirDesdeMenu(const CarritoScreen()),
        onHistorial: () => _abrirDesdeMenu(const HistorialCompraScreen()),
      ),

      // =======================================================
      // 7.3. CONTENIDO PRINCIPAL
      // =======================================================

      body: SafeArea(
        child: cargando
            ? const Center(
                child: CircularProgressIndicator(color: verde),
              )
            : RefreshIndicator(
                onRefresh: cargarProductos,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Mi alacena',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: verdeOscuro,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$totalUnidades unidades registradas',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      onChanged: (valor) {
                        setState(() => busqueda = valor);
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: verde,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Filtrar por categoría',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: categorias.contains(categoriaSeleccionada)
                          ? categoriaSeleccionada
                          : 'Todas',
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          color: verde,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: categorias.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria,
                          child: Text(categoria),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        if (valor != null) {
                          setState(() {
                            categoriaSeleccionada = valor;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    _encabezadoSeccion(
                      'Por agotarse',
                      productosPorAgotarse.length,
                      rojo,
                      Icons.warning_amber_rounded,
                    ),
                    const SizedBox(height: 10),

                    if (productosPorAgotarse.isEmpty)
                      _mensajeVacio(
                        'No hay productos por agotarse.',
                        Icons.check_circle_outline,
                      )
                    else
                      ...productosPorAgotarse.map(
                        (p) => _tarjetaProducto(
                          producto: p,
                          estado: 'Stock bajo',
                          colorEstado: rojo,
                          iconoEstado: Icons.warning_amber_rounded,
                          detalle:
                              'Disponibles: ${cantidad(p)} · Mínimo: ${stockMinimo(p)}',
                        ),
                      ),

                    const SizedBox(height: 22),

                    _encabezadoSeccion(
                      'Próximos a caducar',
                      lotesCaducidadFiltrados.length,
                      amarillo,
                      Icons.calendar_month_outlined,
                    ),
                    const SizedBox(height: 10),

                    if (lotesCaducidadFiltrados.isEmpty)
                      _mensajeVacio(
                        'No hay lotes próximos a caducar.',
                        Icons.event_available_outlined,
                      )
                    else
                      ...lotesCaducidadFiltrados.map((lote) {
                        final dias =
                            (lote['dias_restantes'] as num?)?.toInt() ?? 0;

                        final caducado = dias < 0;
                        final estado = caducado
                            ? 'Caducado'
                            : dias == 0
                                ? 'Caduca hoy'
                                : 'Caduca en $dias ${dias == 1 ? 'día' : 'días'}';

                        return _tarjetaProducto(
                          producto: lote,
                          estado: estado,
                          colorEstado: caducado ? rojo : amarillo,
                          iconoEstado: caducado
                              ? Icons.event_busy
                              : Icons.calendar_month,
                          detalle:
                              'Lote: ${lote['cantidad_lote']} unidades · ${lote['fecha_caducidad']}',
                        );
                      }),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Mis productos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: verdeOscuro,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: verdeClaro,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${productosFiltrados.length}',
                            style: const TextStyle(
                              color: verdeOscuro,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (productosFiltrados.isEmpty)
                      _mensajeVacio(
                        'No hay productos para mostrar.',
                        Icons.kitchen_outlined,
                      )
                    else
                      ...productosFiltrados.map(
                        (p) => _tarjetaProducto(producto: p),
                      ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: BarraNavegacion(
        indiceSeleccionado: 1,
        alSeleccionar: _seleccionarNavegacion,
      ),
    );
  }

  Widget _encabezadoSeccion(
    String titulo,
    int total,
    Color color,
    IconData icono,
  ) {
    return Row(
      children: [
        Icon(icono, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: verdeOscuro,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$total',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaProducto({
    required Map<String, dynamic> producto,
    String? estado,
    Color? colorEstado,
    IconData? iconoEstado,
    String? detalle,
  }) {
    final nombre =
        producto['nombre_producto']?.toString() ?? 'Sin nombre';
    final categoria =
        producto['nombre_categoria']?.toString() ?? 'Sin categoría';
    final imagen = producto['imagen']?.toString();
    final idProducto =
        (producto['id_producto'] as num).toInt();

    final cantidadVisible = producto.containsKey('cantidad_total')
        ? cantidad(producto)
        : (producto['cantidad_lote'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorEstado?.withValues(alpha: 0.35) ??
              const Color(0xFFE2E8DD),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 58,
                  height: 58,
                  color: verdeClaro,
                  child: imagen != null &&
                          imagen.isNotEmpty &&
                          File(imagen).existsSync()
                      ? Image.file(
                          File(imagen),
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.fastfood_outlined,
                            color: verde,
                            size: 30,
                          ),
                        )
                      : const Icon(
                          Icons.fastfood_outlined,
                          color: verde,
                          size: 30,
                        ),
                ),
              ),
              title: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: verdeOscuro,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(categoria),
                    if (detalle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        detalle,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (estado != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorEstado!.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconoEstado,
                              color: colorEstado,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                estado,
                                style: TextStyle(
                                  color: colorEstado,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$cantidadVisible',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                  const Text(
                    'unidades',
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // Acciones compactas con el mismo estilo visual.
            const Divider(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: consumosEnProceso.contains(idProducto)
                          ? null
                          : () => _mostrarDialogoConsumo(producto),
                      icon: consumosEnProceso.contains(idProducto)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.remove_circle_outline),
                      label: Text(
                        consumosEnProceso.contains(idProducto)
                            ? 'Registrando...'
                            : 'Registrar consumo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: verdeOscuro,
                        side: const BorderSide(color: verdeClaro),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _agregarAlCarrito(producto),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text(
                        'Carrito',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: verdeOscuro,
                        side: const BorderSide(color: verdeClaro),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajeVacio(String texto, IconData icono) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: verde, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
