
import 'package:flutter/material.dart';

import '../database/alacena_db.dart';
import '../widgets/app_bar_comun.dart';
import '../widgets/menu_lateral.dart';
import '../widgets/barra_navegacion.dart';

import 'main_screen.dart';
import 'alacena_screen.dart';
import 'calendario_screen.dart';
import 'productos_screen.dart';
import 'categorias_screen.dart';
import 'tiendas_screen.dart';
import 'lotes_screen.dart';
import 'carrito_screen.dart';
import 'historial_compra_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() =>
      _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  static const Color verde = Color(0xFF397653);
  static const Color verdeOscuro = Color(0xFF234B35);
  static const Color verdeClaro = Color(0xFFE1EFDF);
  static const Color fondo = Color(0xFFF7F8F4);
  static const Color rojo = Color(0xFFB42318);
  static const Color amarillo = Color(0xFF9A6700);

  List<Map<String, dynamic>> notificaciones = [];
  int enCarrito = 0;
  bool cargando = true;
  String filtro = 'Activas';

  @override
  void initState() {
    super.initState();
    cargarNotificaciones();
  }

  // La tabla se crea sin modificar la versión de la base de datos.
  Future<void> _crearTablaNotificaciones() async {
    final db = await AlacenaDB().database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS NOTIFICACIONES (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clave_activa TEXT UNIQUE,
        tipo TEXT NOT NULL,
        titulo TEXT NOT NULL,
        mensaje TEXT NOT NULL,
        producto_id INTEGER,
        lote_id INTEGER,
        fecha_creacion TEXT NOT NULL
          DEFAULT (datetime('now', 'localtime')),
        leida INTEGER NOT NULL DEFAULT 0,
        vigente INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _actualizarContadorCarrito() async {
    final db = await AlacenaDB().database;
    final resultado = await db.rawQuery('''
      SELECT COALESCE(SUM(cantidad), 0) AS total
      FROM CARRITO
    ''');

    enCarrito =
        (resultado.first['total'] as num?)?.toInt() ?? 0;
  }

  // Obtiene las alertas actuales directamente de PRODUCTOS y LOTES.
  Future<List<Map<String, dynamic>>> _obtenerAlertasActuales() async {
    final db = await AlacenaDB().database;

    final alertas = <Map<String, dynamic>>[];

    // 1. Productos con existencias bajas.
    final productosBajos = await db.rawQuery('''
      SELECT
        p.id_producto,
        p.nombre,
        p.stock_minimo,
        COALESCE(SUM(l.cantidad), 0) AS cantidad_total
      FROM PRODUCTOS p
      LEFT JOIN LOTES l
        ON l.producto_id = p.id_producto
      GROUP BY
        p.id_producto,
        p.nombre,
        p.stock_minimo
      HAVING COALESCE(SUM(l.cantidad), 0) <= p.stock_minimo
    ''');

    for (final producto in productosBajos) {
      final id = (producto['id_producto'] as num).toInt();
      final cantidad =
          (producto['cantidad_total'] as num?)?.toInt() ?? 0;

      alertas.add({
        'clave_activa': 'stock:$id',
        'tipo': 'stock',
        'titulo': 'Stock bajo: ${producto['nombre']}',
        'mensaje':
            'Tienes $cantidad unidades. El mínimo configurado '
            'es ${producto['stock_minimo']}.',
        'producto_id': id,
        'lote_id': null,
      });
    }

    // 2. Lotes caducados o próximos a caducar.
    final lotes = await db.rawQuery('''
      SELECT
        l.id_lote,
        l.producto_id,
        l.fecha_caducidad,
        p.nombre AS nombre_producto,
        p.dias_alerta_caducidad,
        CAST(
          julianday(date(l.fecha_caducidad)) -
          julianday(date('now', 'localtime'))
          AS INTEGER
        ) AS dias_restantes
      FROM LOTES l
      INNER JOIN PRODUCTOS p
        ON p.id_producto = l.producto_id
      WHERE l.cantidad > 0
        AND l.alarma_habilitada = 1
        AND date(l.fecha_caducidad) IS NOT NULL
        AND date(l.fecha_caducidad) <= date(
          'now',
          'localtime',
          '+' || p.dias_alerta_caducidad || ' days'
        )
      ORDER BY date(l.fecha_caducidad) ASC
    ''');

    for (final lote in lotes) {
      final idLote = (lote['id_lote'] as num).toInt();
      final idProducto =
          (lote['producto_id'] as num).toInt();
      final dias =
          (lote['dias_restantes'] as num?)?.toInt() ?? 0;
      final caducado = dias < 0;
      final fecha = lote['fecha_caducidad'];

      alertas.add({
        'clave_activa': 'caducidad:$idLote',
        'tipo': caducado ? 'caducado' : 'caducidad',
        'titulo': caducado
            ? 'Producto caducado: ${lote['nombre_producto']}'
            : 'Próximo a caducar: ${lote['nombre_producto']}',
        'mensaje': caducado
            ? 'Este lote caducó el $fecha. Revisa el producto '
                'antes de consumirlo.'
            : dias == 0
                ? 'Este lote caduca hoy ($fecha).'
                : 'Este lote caduca en $dias días ($fecha).',
        'producto_id': idProducto,
        'lote_id': idLote,
      });
    }

    return alertas;
  }

  // Conserva las alertas anteriores y evita duplicar las que siguen activas.
  Future<void> _sincronizarHistorial(
    List<Map<String, dynamic>> alertas,
  ) async {
    final db = await AlacenaDB().database;

    await db.transaction((txn) async {
      final actuales = await txn.query(
        'NOTIFICACIONES',
        columns: ['id', 'clave_activa'],
        where: 'vigente = 1',
      );

      final clavesActuales = alertas
          .map((a) => a['clave_activa'] as String)
          .toSet();

      // Las alertas que desaparecieron pasan al historial.
      for (final anterior in actuales) {
        final clave = anterior['clave_activa'] as String?;

        if (clave != null && !clavesActuales.contains(clave)) {
          await txn.update(
            'NOTIFICACIONES',
            {
              'clave_activa': null,
              'vigente': 0,
            },
            where: 'id = ?',
            whereArgs: [anterior['id']],
          );
        }
      }

      for (final alerta in alertas) {
        final clave = alerta['clave_activa'] as String;

        final existentes = await txn.query(
          'NOTIFICACIONES',
          where: 'clave_activa = ? AND vigente = 1',
          whereArgs: [clave],
          limit: 1,
        );

        if (existentes.isNotEmpty) {
          await txn.update(
            'NOTIFICACIONES',
            {
              'titulo': alerta['titulo'],
              'mensaje': alerta['mensaje'],
              'tipo': alerta['tipo'],
              'producto_id': alerta['producto_id'],
              'lote_id': alerta['lote_id'],
            },
            where: 'id = ?',
            whereArgs: [existentes.first['id']],
          );
        } else {
          await txn.insert('NOTIFICACIONES', alerta);
        }
      }
    });
  }

  Future<void> cargarNotificaciones() async {
    if (mounted) setState(() => cargando = true);

    try {
      await _crearTablaNotificaciones();

      final alertas = await _obtenerAlertasActuales();
      await _sincronizarHistorial(alertas);
      await _actualizarContadorCarrito();

      final db = await AlacenaDB().database;
      final datos = await db.query(
        'NOTIFICACIONES',
        orderBy: 'vigente DESC, leida ASC, fecha_creacion DESC',
      );

      if (!mounted) return;

      setState(() {
        notificaciones = datos;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron cargar las alertas: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _marcarLeida(int id) async {
    final db = await AlacenaDB().database;

    await db.update(
      'NOTIFICACIONES',
      {'leida': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    await cargarNotificaciones();
  }

  Future<void> _marcarTodasLeidas() async {
    final db = await AlacenaDB().database;

    await db.update(
      'NOTIFICACIONES',
      {'leida': 1},
      where: 'leida = 0',
    );

    await cargarNotificaciones();
  }

  Future<void> _abrirPantalla(Widget pantalla) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );

    if (mounted) cargarNotificaciones();
  }

  void _volverAInicio() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _irASeccionPrincipal(Widget pantalla) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  void _seleccionarBarraInferior(int indice) {
    if (indice == 0) {
      _volverAInicio();
    } else if (indice == 1) {
      _irASeccionPrincipal(const AlacenaScreen());
    } else if (indice == 2) {
      _irASeccionPrincipal(const CalendarioScreen());
    }
  }

  Widget _construirMenuComun() {
    return MenuLateral(
      onInicio: () {
        Navigator.pop(context);
        _volverAInicio();
      },
      onProductos: () {
        Navigator.pop(context);
        _abrirPantalla(const ProductosScreen());
      },
      onCategorias: () {
        Navigator.pop(context);
        _abrirPantalla(const CategoriaScreen());
      },
      onTiendas: () {
        Navigator.pop(context);
        _abrirPantalla(const TiendasScreen());
      },
      onLotes: () {
        Navigator.pop(context);
        _abrirPantalla(const LotesScreen());
      },
      onAlacena: () {
        Navigator.pop(context);
        _irASeccionPrincipal(const AlacenaScreen());
      },
      onCalendario: () {
        Navigator.pop(context);
        _irASeccionPrincipal(const CalendarioScreen());
      },
      onCarrito: () {
        Navigator.pop(context);
        _abrirPantalla(const CarritoScreen());
      },
      onHistorial: () {
        Navigator.pop(context);
        _abrirPantalla(const HistorialCompraScreen());
      },
    );
  }

  List<Map<String, dynamic>> get notificacionesFiltradas {
    if (filtro == 'Activas') {
      return notificaciones
          .where((n) => n['vigente'] == 1)
          .toList();
    }

    if (filtro == 'Historial') {
      return notificaciones
          .where((n) => n['vigente'] == 0)
          .toList();
    }

    return notificaciones;
  }

  int get totalActivas =>
      notificaciones.where((n) => n['vigente'] == 1).length;

  int get totalSinLeer =>
      notificaciones.where((n) => n['leida'] == 0).length;

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'caducado':
        return Icons.error_outline;
      case 'caducidad':
        return Icons.calendar_month_outlined;
      case 'stock':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'caducado':
        return rojo;
      case 'caducidad':
        return amarillo;
      case 'stock':
        return verde;
      default:
        return verdeOscuro;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = notificacionesFiltradas;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: fondo,

      appBar: AppBarComun(
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificaciones: cargarNotificaciones,
        onCarrito: () => _abrirPantalla(const CarritoScreen()),
        cantidadCarrito: enCarrito,
      ),

      drawer: _construirMenuComun(),

      bottomNavigationBar: BarraNavegacion(
        indiceSeleccionado: 0,
        alSeleccionar: _seleccionarBarraInferior,
      ),

      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: verde),
            )
          : RefreshIndicator(
              onRefresh: cargarNotificaciones,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: verdeClaro,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: verde,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notificaciones',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: verdeOscuro,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Mantén tu alacena bajo control.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: cargarNotificaciones,
                        icon: const Icon(
                          Icons.refresh,
                          color: verde,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Resumen de alertas.
                  Row(
                    children: [
                      Expanded(
                        child: _resumen(
                          'Activas',
                          totalActivas,
                          Icons.notifications_active_outlined,
                          verde,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _resumen(
                          'Sin revisar',
                          totalSinLeer,
                          Icons.mark_email_unread_outlined,
                          amarillo,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tus alertas',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: verdeOscuro,
                          ),
                        ),
                      ),
                      if (totalSinLeer > 0)
                        TextButton(
                          onPressed: _marcarTodasLeidas,
                          child: const Text(
                            'Marcar revisadas',
                            style: TextStyle(color: verde),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    children: ['Activas', 'Historial', 'Todas']
                        .map(
                          (opcion) => ChoiceChip(
                            label: Text(opcion),
                            selected: filtro == opcion,
                            selectedColor: verdeClaro,
                            onSelected: (_) {
                              setState(() => filtro = opcion);
                            },
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 14),

                  if (lista.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            filtro == 'Historial'
                                ? Icons.history
                                : Icons.check_circle_outline,
                            size: 55,
                            color: verde,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            filtro == 'Historial'
                                ? 'Todavía no hay alertas anteriores'
                                : '¡Todo en orden!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: verdeOscuro,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            filtro == 'Historial'
                                ? 'Aquí aparecerán las alertas que se resuelvan.'
                                : 'No encontramos alertas para mostrar.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...lista.map(_crearTarjeta),
                ],
              ),
            ),
    );
  }

  Widget _resumen(
    String titulo,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearTarjeta(Map<String, dynamic> notificacion) {
    final tipo = notificacion['tipo'] as String;
    final color = _colorTipo(tipo);
    final vigente = notificacion['vigente'] == 1;
    final leida = notificacion['leida'] == 1;
    final id = (notificacion['id'] as num).toInt();

    return Card(
      elevation: 0,
      color: leida ? Colors.white : const Color(0xFFF0F6EF),
      margin: const EdgeInsets.only(bottom: 11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(
          color: leida ? const Color(0xFFE7EBE4) : verdeClaro,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => _mostrarDetalle(notificacion),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _iconoTipo(tipo),
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificacion['titulo'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: verdeOscuro,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notificacion['mensaje'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _etiqueta(
                          vigente ? 'Vigente' : 'Resuelta',
                          vigente ? verde : Colors.grey,
                        ),
                        if (!leida) _etiqueta('Nueva', amarillo),
                        if (leida) _etiqueta('Revisada', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (opcion) {
                  if (opcion == 'revisar') {
                    _marcarLeida(id);
                  }
                },
                itemBuilder: (_) => [
                  if (!leida)
                    const PopupMenuItem(
                      value: 'revisar',
                      child: Text('Marcar como revisada'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _mostrarDetalle(
    Map<String, dynamic> notificacion,
  ) async {
    final id = (notificacion['id'] as num).toInt();

    await _marcarLeida(id);

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notificacion['titulo'] as String),
        content: Text(notificacion['mensaje'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: verde),
            ),
          ),
        ],
      ),
    );
  }
}
