import 'dart:io';

import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:alacena_practica/database/alacena_db.dart';

import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';

class AlertaCalendario {
  final DateTime fecha;
  final int idProducto;
  final String nombre;
  final String categoria;
  final String? imagen;
  final String estado;
  final String detalle;
  final int cantidad;

  const AlertaCalendario({
    required this.fecha,
    required this.idProducto,
    required this.nombre,
    required this.categoria,
    required this.imagen,
    required this.estado,
    required this.detalle,
    required this.cantidad,
  });

  Color get color {
    switch (estado) {
      case 'Caducado':
      case 'Sin existencia':
        return const Color(0xFFB42318);
      case 'Próximo a caducar':
      case 'Por agotarse':
        return const Color(0xFFB86A00);
      default:
        return const Color(0xFF397653);
    }
  }

  IconData get icono {
    switch (estado) {
      case 'Caducado':
        return Icons.event_busy_rounded;
      case 'Sin existencia':
        return Icons.inventory_2_outlined;
      case 'Próximo a caducar':
        return Icons.calendar_month_rounded;
      case 'Por agotarse':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const Color verde = Color(0xFF397653);
  static const Color verdeOscuro = Color(0xFF234B35);
  static const Color fondo = Color(0xFFF7F8F4);

  DateTime diaEnfocado = DateTime.now();
  DateTime diaSeleccionado = DateTime.now();
  List<AlertaCalendario> alertas = [];
  bool cargando = true;
  int enCarrito = 0;

  DateTime soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  @override
  void initState() {
    super.initState();
    diaEnfocado = soloFecha(DateTime.now());
    diaSeleccionado = soloFecha(DateTime.now());
    cargarAlertas();
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
    } catch (e) {
      debugPrint('Error al cargar el contador del carrito: $e');
    }
  }

  Future<void> abrirCarrito() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CarritoScreen()),
    );

    if (!mounted) return;
    await cargarCantidadCarrito();
  }

  Future<void> cargarAlertas() async {
    if (mounted) setState(() => cargando = true);

    try {
      final db = await AlacenaDB().database;
      final hoy = soloFecha(DateTime.now());

      final productos = await db.rawQuery('''
        SELECT
          p.id_producto,
          p.nombre AS nombre_producto,
          p.imagen,
          p.stock_minimo,
          c.nombre AS nombre_categoria,
          COALESCE(SUM(l.cantidad), 0) AS cantidad_total
        FROM PRODUCTOS p
        INNER JOIN CATEGORIA c ON c.id_categoria = p.categoria_id
        LEFT JOIN LOTES l ON l.producto_id = p.id_producto
        GROUP BY p.id_producto, p.nombre, p.imagen,
                 p.stock_minimo, c.nombre
        ORDER BY p.nombre COLLATE NOCASE
      ''');

      final lotes = await db.rawQuery('''
        SELECT
          l.id_lote,
          l.producto_id,
          l.cantidad,
          l.fecha_caducidad,
          l.alarma_habilitada,
          p.nombre AS nombre_producto,
          p.imagen,
          p.dias_alerta_caducidad,
          c.nombre AS nombre_categoria
        FROM LOTES l
        INNER JOIN PRODUCTOS p ON p.id_producto = l.producto_id
        INNER JOIN CATEGORIA c ON c.id_categoria = p.categoria_id
        WHERE l.cantidad > 0 AND l.alarma_habilitada = 1
        ORDER BY date(l.fecha_caducidad)
      ''');

      final nuevasAlertas = <AlertaCalendario>[];

      // El stock es el estado actual del inventario; por eso estas alertas
      // se muestran en el día de hoy, no se predicen para días futuros.
      for (final producto in productos) {
        final id = (producto['id_producto'] as num).toInt();
        final cantidad = (producto['cantidad_total'] as num?)?.toInt() ?? 0;
        final minimo = (producto['stock_minimo'] as num?)?.toInt() ?? 1;
        final nombre = producto['nombre_producto'].toString();
        final categoria = producto['nombre_categoria'].toString();
        final imagen = producto['imagen']?.toString();

        if (cantidad <= 0) {
          nuevasAlertas.add(AlertaCalendario(
            fecha: hoy,
            idProducto: id,
            nombre: nombre,
            categoria: categoria,
            imagen: imagen,
            estado: 'Sin existencia',
            detalle: 'No hay unidades disponibles.',
            cantidad: 0,
          ));
        } else if (cantidad <= minimo) {
          nuevasAlertas.add(AlertaCalendario(
            fecha: hoy,
            idProducto: id,
            nombre: nombre,
            categoria: categoria,
            imagen: imagen,
            estado: 'Por agotarse',
            detalle: 'Disponibles: $cantidad · Stock mínimo: $minimo',
            cantidad: cantidad,
          ));
        }
      }

      // Los lotes aparecen en cada día de su periodo de alerta.
      // Si ya caducaron, la alerta se muestra desde hoy en adelante.
      for (final lote in lotes) {
        final fechaTexto = lote['fecha_caducidad']?.toString();
        if (fechaTexto == null) continue;
        final fechaParseada = DateTime.tryParse(fechaTexto);
        if (fechaParseada == null) continue;

        final caducidad = soloFecha(fechaParseada);
        final id = (lote['producto_id'] as num).toInt();
        final diasAlerta =
            (lote['dias_alerta_caducidad'] as num?)?.toInt() ?? 5;
        final cantidad = (lote['cantidad'] as num?)?.toInt() ?? 0;
        final nombre = lote['nombre_producto'].toString();
        final categoria = lote['nombre_categoria'].toString();
        final imagen = lote['imagen']?.toString();

        if (caducidad.isBefore(hoy)) {
          nuevasAlertas.add(AlertaCalendario(
            fecha: hoy,
            idProducto: id,
            nombre: nombre,
            categoria: categoria,
            imagen: imagen,
            estado: 'Caducado',
            detalle: 'Lote caducó el $fechaTexto · $cantidad unidades',
            cantidad: cantidad,
          ));
          continue;
        }

        final inicioAlerta = caducidad.subtract(Duration(days: diasAlerta));
        var dia = inicioAlerta.isBefore(hoy) ? hoy : inicioAlerta;

        while (!dia.isAfter(caducidad)) {
          nuevasAlertas.add(AlertaCalendario(
            fecha: dia,
            idProducto: id,
            nombre: nombre,
            categoria: categoria,
            imagen: imagen,
            estado: 'Próximo a caducar',
            detalle: 'Caduca el $fechaTexto · $cantidad unidades',
            cantidad: cantidad,
          ));
          dia = dia.add(const Duration(days: 1));
        }
      }

      if (!mounted) return;
      setState(() {
        alertas = nuevasAlertas;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar calendario: $e')),
      );
    }
  }

  List<AlertaCalendario> alertasDelDia(DateTime dia) {
    return alertas.where((alerta) => isSameDay(alerta.fecha, dia)).toList();
  }

  void seleccionarHoy() {
    final hoy = soloFecha(DateTime.now());
    setState(() {
      diaSeleccionado = hoy;
      diaEnfocado = hoy;
    });
  }

  Future<void> _mostrarAlertasDia(DateTime dia) async {
    final alertasDia = alertasDelDia(dia);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: fondo,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_rounded, color: verdeOscuro),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.calendar_month_rounded, color: verde, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alertas del día',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: verdeOscuro),
                            ),
                            Text(
                              fechaCortaBonita(dia),
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: alertasDia.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_available_outlined, size: 54, color: verde),
                                SizedBox(height: 12),
                                Text('No hay alertas para este día.', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: alertasDia.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 2),
                          itemBuilder: (_, index) => _tarjetaAlerta(alertasDia[index]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String fechaLarga(DateTime fecha) {
    const dias = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${dias[fecha.weekday - 1]} ${fecha.day} de '
        '${meses[fecha.month - 1]} de ${fecha.year}';
  }

  Future<void> _seleccionarNavegacion(int indice) async {
    if (indice == 2) return;
    if (indice == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AlacenaScreen()),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla)).then((_) {
      if (mounted) cargarCantidadCarrito();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hoy = soloFecha(DateTime.now());
    final alertasDeHoy = alertasDelDia(hoy);

    return Scaffold(
      backgroundColor: fondo,
      key: _scaffoldKey,
      appBar: AppBarComun(
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
       onNotificaciones: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificacionesScreen(),
          ),
        );
      },
        onCarrito: abrirCarrito,
        cantidadCarrito: enCarrito,
      ),
      drawer: MenuLateral(
        onInicio: _irAInicioDesdeMenu,
        onProductos: () => _abrirDesdeMenu(const ProductosScreen()),
        onCategorias: () => _abrirDesdeMenu(const CategoriaScreen()),
        onTiendas: () => _abrirDesdeMenu(const TiendasScreen()),
        onLotes: () => _abrirDesdeMenu(const LotesScreen()),
        onAlacena: () => _irASeccionDesdeMenu(const AlacenaScreen()),
        onCalendario: _cerrarMenu,
        onCarrito: () => _abrirDesdeMenu(const CarritoScreen()),
        onHistorial: () => _abrirDesdeMenu(const HistorialCompraScreen()),
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : RefreshIndicator(
              onRefresh: cargarAlertas,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Calendario de alertas',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: verdeOscuro,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona un día para consultar sus artículos.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TableCalendar<AlertaCalendario>(
                        locale: 'es_MX',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: diaEnfocado,
                        calendarFormat: CalendarFormat.month,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        availableGestures: AvailableGestures.all,
                        selectedDayPredicate: (dia) =>
                            isSameDay(diaSeleccionado, dia),
                        eventLoader: alertasDelDia,
                        rowHeight: 58,
                        daysOfWeekHeight: 32,
                        onDaySelected: (seleccionado, enfocado) {
                          final fecha = soloFecha(seleccionado);
                          setState(() {
                            diaSeleccionado = fecha;
                            diaEnfocado = enfocado;
                          });
                          _mostrarAlertasDia(fecha);
                        },
                        onPageChanged: (enfocado) {
                          diaEnfocado = enfocado;
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          leftChevronIcon: Icon(Icons.chevron_left, color: verde),
                          rightChevronIcon: Icon(Icons.chevron_right, color: verde),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: verdeOscuro,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendStyle: TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        calendarStyle: const CalendarStyle(
                          outsideDaysVisible: false,
                          cellMargin: EdgeInsets.all(2),
                          cellPadding: EdgeInsets.zero,
                        ),
                        calendarBuilders: CalendarBuilders<AlertaCalendario>(
                          defaultBuilder: (context, dia, focusedDay) =>
                              _celdaDia(dia, false, false, alertasDelDia(dia)),
                          todayBuilder: (context, dia, focusedDay) =>
                              _celdaDia(dia, true, false, alertasDelDia(dia)),
                          selectedBuilder: (context, dia, focusedDay) =>
                              _celdaDia(dia, false, true, alertasDelDia(dia)),
                          markerBuilder: (context, dia, eventos) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Significado de los iconos',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: verdeOscuro),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: const [
                            _LeyendaIcono(icono: Icons.event_busy_rounded, color: Color(0xFFB42318), texto: 'Caducado'),
                            _LeyendaIcono(icono: Icons.inventory_2_outlined, color: Color(0xFFB42318), texto: 'Sin existencia'),
                            _LeyendaIcono(icono: Icons.calendar_month_rounded, color: Color(0xFFB86A00), texto: 'Próximo a caducar'),
                            _LeyendaIcono(icono: Icons.warning_amber_rounded, color: Color(0xFFB86A00), texto: 'Por agotarse'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alertas para hoy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: verdeOscuro,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              fechaCortaBonita(hoy),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: seleccionarHoy,
                        icon: const Icon(Icons.today, size: 18),
                        label: const Text('Hoy'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (alertasDeHoy.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.event_available_outlined, size: 42, color: verde),
                          SizedBox(height: 8),
                          Text(
                            'No hay alertas para este día.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...alertasDeHoy.map(_tarjetaAlerta),
                ],
              ),
            ),
      bottomNavigationBar: BarraNavegacion(
        indiceSeleccionado: 2,
        alSeleccionar: _seleccionarNavegacion,
      ),
    );
  }

  String fechaCortaBonita(DateTime fecha) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final diaSemana = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ][fecha.weekday - 1];
    final capitalizado = '${diaSemana[0].toUpperCase()}${diaSemana.substring(1)}';
    return '$capitalizado ${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }

  Widget _celdaDia(
    DateTime dia,
    bool esHoy,
    bool seleccionado,
    List<AlertaCalendario> eventos,
  ) {
    // Mostrar iconos de los tipos de alerta presentes en esta fecha,
    // sin añadir una guía explicativa debajo del calendario.
    final iconosPorEstado = <String, AlertaCalendario>{};
    for (final evento in eventos) {
      iconosPorEstado.putIfAbsent(evento.estado, () => evento);
    }
    final iconos = iconosPorEstado.values.toList();

    final Color fondoCelda = seleccionado
        ? verde
        : esHoy
            ? const Color(0xFFDDEBDD)
            : Colors.transparent;
    final Color colorTexto = seleccionado ? Colors.white : verdeOscuro;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: fondoCelda,
        borderRadius: BorderRadius.circular(10),
        border: esHoy && !seleccionado
            ? Border.all(color: verde, width: 1.3)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${dia.day}',
            style: TextStyle(
              color: colorTexto,
              fontWeight: seleccionado || esHoy ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: iconos.take(3).map((evento) => Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Icon(
                    evento.icono,
                    size: iconos.length >= 3 ? 11 : 14,
                    color: seleccionado ? Colors.white : evento.color,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAlerta(AlertaCalendario alerta) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: alerta.color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 62,
                height: 62,
                color: const Color(0xFFE1EFDF),
                child: alerta.imagen != null &&
                        alerta.imagen!.isNotEmpty &&
                        File(alerta.imagen!).existsSync()
                    ? Image.file(
                        File(alerta.imagen!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alerta.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: verdeOscuro,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alerta.categoria,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(alerta.detalle, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: alerta.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: alerta.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            alerta.estado,
                            style: TextStyle(
                              color: alerta.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  '${alerta.cantidad}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                const Text('unidades', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _LeyendaIcono extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;

  const _LeyendaIcono({
    required this.icono,
    required this.color,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Color(0xFF234B35)),
            ),
          ),
        ],
      ),
    );
  }
}
