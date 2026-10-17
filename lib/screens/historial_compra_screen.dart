
import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';

import '../dao/historial_compra_dao.dart';
import '../dao/productos_dao.dart';
import '../dao/tienda_dao.dart';


import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';

class HistorialCompraScreen extends StatefulWidget {
  final bool abrirFormularioAlEntrar;

  const HistorialCompraScreen({
    super.key,
    this.abrirFormularioAlEntrar = false,
  });

  @override
  State<HistorialCompraScreen> createState() =>
      _HistorialCompraScreenState();
}

class _HistorialCompraScreenState
    extends State<HistorialCompraScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int enCarrito = 0;

  final HistorialCompraDB historialDB = HistorialCompraDB();
  final ProductosDB productosDB = ProductosDB();
  final TiendaDB tiendaDB = TiendaDB();

  List<HistorialCompraDAO> compras = [];
  List<ProductosDAO> productos = [];
  List<TiendaDAO> tiendas = [];

  bool cargando = true;

  static const Color verde = Color(0xFF176B45);
  static const Color verdeClaro = Color(0xFFD8F5E3);

  @override
  void initState() {
    super.initState();
    _cargarCantidadCarrito();

    if (widget.abrirFormularioAlEntrar) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await cargarDatos();
        if (!mounted || cargando) return;
        await abrirFormularioCompra();
      });
    } else {
      cargarDatos();
    }
  }

  Future<void> cargarDatos() async {
    try {
      final resultados = await Future.wait([
        historialDB.SELECT(),
        productosDB.SELECT(),
        tiendaDB.SELECT(),
      ]);

      if (!mounted) return;

      setState(() {
        compras = resultados[0] as List<HistorialCompraDAO>;
        productos = resultados[1] as List<ProductosDAO>;
        tiendas = resultados[2] as List<TiendaDAO>;
        cargando = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR AL CARGAR HISTORIAL: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() => cargando = false);
      mostrarMensaje('No se pudo cargar el historial: $e');
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  String fechaParaBD(DateTime fecha) {
    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return '$anio-$mes-$dia';
  }

  String fechaVisible(String? fecha) {
    if (fecha == null || fecha.isEmpty) {
      return 'Sin fecha';
    }

    final partes = fecha.split('-');

    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }

    return fecha;
  }

  String fechaTituloGrupo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 'Fecha no disponible';

    final partes = fecha.split('-');
    if (partes.length != 3) return fecha;

    final anio = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);

    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];

    if (anio == null || mes == null || dia == null || mes < 1 || mes > 12) {
      return fecha;
    }

    return '$dia de ${meses[mes - 1]} del $anio';
  }

  Map<String, List<HistorialCompraDAO>> _agruparComprasPorFecha() {
    final agrupadas = <String, List<HistorialCompraDAO>>{};

    for (final compra in compras) {
      final fecha = (compra.fecha_compra == null ||
              compra.fecha_compra!.isEmpty)
          ? 'sin_fecha'
          : compra.fecha_compra!;
      agrupadas.putIfAbsent(fecha, () => []).add(compra);
    }

    final fechas = agrupadas.keys.toList()
      ..sort((a, b) {
        if (a == 'sin_fecha') return 1;
        if (b == 'sin_fecha') return -1;
        return b.compareTo(a);
      });

    return {
      for (final fecha in fechas) fecha: agrupadas[fecha]!,
    };
  }

  String nombreProducto(int? id) {
    for (final producto in productos) {
      if (producto.id_producto == id) {
        return producto.nombre ?? 'Sin nombre';
      }
    }

    return 'Producto no disponible';
  }

  String nombreTienda(int? id) {
    for (final tienda in tiendas) {
      if (tienda.id_tienda == id) {
        return tienda.nombre ?? 'Sin nombre';
      }
    }

    return 'Tienda no disponible';
  }

  Future<DateTime?> elegirFecha(
    BuildContext contexto,
    DateTime inicial,
  ) {
    return showDatePicker(
      context: contexto,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<void> abrirFormularioCompra() async {
    final formKey = GlobalKey<FormState>();

    int? productoId = productos.isNotEmpty ? productos.first.id_producto : null;
    int? tiendaId = tiendas.isNotEmpty ? tiendas.first.id_tienda : null;

    DateTime fechaCompra = DateTime.now();
    DateTime fechaCaducidad =
        DateTime.now().add(const Duration(days: 30));

    int cantidadComprada = 1;
    int alarmaHabilitada = 1;

    bool guardandoDialogo = false;
    bool compraGuardada = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (contexto, actualizarDialogo) => AlertDialog(
          title: const Text('Registrar compra'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: productos.any((p) => p.id_producto == productoId)
                          ? productoId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Producto',
                        hintText: 'Selecciona un producto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      items: productos
                          .where((p) => p.id_producto != null)
                          .map((p) => DropdownMenuItem<int>(
                                value: p.id_producto!,
                                child: Text(p.nombre ?? 'Producto sin nombre',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: guardandoDialogo || productos.isEmpty
                          ? null
                          : (valor) => actualizarDialogo(() => productoId = valor),
                      validator: (valor) => valor == null
                          ? 'Crea o selecciona un producto'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: guardandoDialogo ? null : () async {
                          final idsAntes = productos.map((p) => p.id_producto).toSet();
                          await Navigator.of(contexto).push(
                            MaterialPageRoute(builder: (_) => const ProductosScreen()),
                          );
                          if (!mounted || !contexto.mounted) return;
                          final listaActualizada = await productosDB.SELECT();
                          final nuevos = listaActualizada.where((p) => !idsAntes.contains(p.id_producto));
                          final nuevo = nuevos.isNotEmpty ? nuevos.last : null;
                          setState(() => productos = listaActualizada);
                          actualizarDialogo(() {
                            if (nuevo?.id_producto != null) productoId = nuevo!.id_producto;
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Crear producto'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: tiendas.any((t) => t.id_tienda == tiendaId) ? tiendaId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tienda',
                        hintText: 'Selecciona una tienda',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      items: tiendas
                          .where((t) => t.id_tienda != null)
                          .map((t) => DropdownMenuItem<int>(
                                value: t.id_tienda!,
                                child: Text(t.nombre ?? 'Tienda sin nombre',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: guardandoDialogo || tiendas.isEmpty
                          ? null
                          : (valor) => actualizarDialogo(() => tiendaId = valor),
                      validator: (valor) => valor == null
                          ? 'Crea o selecciona una tienda'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: guardandoDialogo ? null : () async {
                          final idsAntes = tiendas.map((t) => t.id_tienda).toSet();
                          await Navigator.of(contexto).push(
                            MaterialPageRoute(builder: (_) => const TiendasScreen()),
                          );
                          if (!mounted || !contexto.mounted) return;
                          final listaActualizada = await tiendaDB.SELECT();
                          final nuevos = listaActualizada.where((t) => !idsAntes.contains(t.id_tienda));
                          final nuevo = nuevos.isNotEmpty ? nuevos.last : null;
                          setState(() => tiendas = listaActualizada);
                          actualizarDialogo(() {
                            if (nuevo?.id_tienda != null) tiendaId = nuevo!.id_tienda;
                          });
                        },
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Crear tienda'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: '1',
                      enabled: !guardandoDialogo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad comprada',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (valor) {
                        final numero = int.tryParse(valor ?? '');

                        if (numero == null || numero <= 0) {
                          return 'Ingresa una cantidad mayor que cero';
                        }

                        return null;
                      },
                      onSaved: (valor) {
                        cantidadComprada = int.parse(valor!);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fecha de compra',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: guardandoDialogo
                          ? null
                          : () async {
                              final fecha = await elegirFecha(
                                contexto,
                                fechaCompra,
                              );

                              if (fecha != null && contexto.mounted) {
                                actualizarDialogo(
                                  () => fechaCompra = fecha,
                                );
                              }
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        fechaVisible(fechaParaBD(fechaCompra)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fecha de caducidad',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: guardandoDialogo
                          ? null
                          : () async {
                              final fecha = await elegirFecha(
                                contexto,
                                fechaCaducidad,
                              );

                              if (fecha != null && contexto.mounted) {
                                actualizarDialogo(
                                  () => fechaCaducidad = fecha,
                                );
                              }
                            },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        fechaVisible(fechaParaBD(fechaCaducidad)),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alerta de caducidad'),
                      subtitle: const Text(
                        'Activar la alerta para este lote',
                      ),
                      value: alarmaHabilitada == 1,
                      onChanged: guardandoDialogo
                          ? null
                          : (valor) => actualizarDialogo(
                                () => alarmaHabilitada = valor ? 1 : 0,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardandoDialogo
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: guardandoDialogo
                  ? null
                  : () async {
                      final formulario = formKey.currentState;

                      if (formulario == null ||
                          !formulario.validate()) {
                        return;
                      }

                      if (productoId == null || tiendaId == null) {
                        mostrarMensaje(
                          'Selecciona el producto y la tienda.',
                        );
                        return;
                      }

                      if (fechaCaducidad.isBefore(fechaCompra)) {
                        mostrarMensaje(
                          'La caducidad no puede ser anterior a la compra.',
                        );
                        return;
                      }

                      formulario.save();

                      actualizarDialogo(
                        () => guardandoDialogo = true,
                      );

                      try {
                        await historialDB.REGISTRAR_COMPRA(
                          productoId: productoId!,
                          tiendaId: tiendaId!,
                          cantidad: cantidadComprada,
                          fechaCompra: fechaParaBD(fechaCompra),
                          fechaCaducidad:
                              fechaParaBD(fechaCaducidad),
                          alarmaHabilitada: alarmaHabilitada,
                        );

                        compraGuardada = true;

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e, stackTrace) {
                        debugPrint('ERROR AL REGISTRAR COMPRA: $e');
                        debugPrint('$stackTrace');

                        if (contexto.mounted) {
                          actualizarDialogo(
                            () => guardandoDialogo = false,
                          );
                        }

                        if (mounted) {
                          mostrarMensaje(
                            'No se pudo registrar la compra: $e',
                          );
                        }
                      }
                    },
              icon: guardandoDialogo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                guardandoDialogo ? 'Guardando...' : 'Guardar compra',
              ),
            ),
          ],
        ),
      ),
    );

    if (compraGuardada && mounted) {
      await cargarDatos();

      if (!mounted) return;

      mostrarMensaje('Compra registrada y lote creado correctamente.');
    }
  }

  Widget _crearDetalle(
    IconData icono,
    String texto, {
    Color color = Colors.black54,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearTarjeta(HistorialCompraDAO compra) {
    final tieneLote = compra.id_lote != null;
    final alarmaActiva = compra.alarma_habilitada == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: verde.withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('compra_${compra.id}'),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        leading: CircleAvatar(
          radius: 23,
          backgroundColor: verdeClaro,
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: verde,
          ),
        ),
        title: Text(
          nombreProducto(compra.producto_id),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${nombreTienda(compra.tienda_id)}'
            ' · ${compra.cantidad ?? 0} unidades',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        children: [
          const Divider(height: 12),
          _crearDetalle(
            Icons.calendar_today_outlined,
            'Fecha de compra: ${fechaVisible(compra.fecha_compra)}',
          ),
          _crearDetalle(
            Icons.inventory_2_outlined,
            tieneLote
                ? 'Lote relacionado: #${compra.id_lote}'
                : 'Sin lote relacionado',
            color: tieneLote ? verde : Colors.grey,
          ),
          _crearDetalle(
            Icons.event_outlined,
            'Fecha de caducidad: ${fechaVisible(compra.fecha_caducidad)}',
          ),
          _crearDetalle(
            alarmaActiva
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            compra.alarma_habilitada == null
                ? 'Estado de alerta no disponible'
                : alarmaActiva
                    ? 'Alerta de caducidad activada'
                    : 'Alerta de caducidad desactivada',
            color: compra.alarma_habilitada == null
                ? Colors.grey
                : alarmaActiva
                    ? verde
                    : Colors.grey,
          ),
          if (compra.id != null)
            _crearDetalle(
              Icons.receipt_long_outlined,
              'Registro #${compra.id}',
              color: Colors.grey,
            ),
        ],
      ),
    );
  }


  Future<void> _cargarCantidadCarrito() async {
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
      // El contador no debe impedir abrir la pantalla.
    }
  }

  void _mostrarNotificaciones() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Consulta las alertas en el calendario.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirPantallaComun(Widget pantalla) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => pantalla),
    ).then((_) => _cargarCantidadCarrito());
  }

  void _irAInicio() {
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
      _irAInicio();
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
        _irAInicio();
      },
      onProductos: () {
        Navigator.pop(context);
        _abrirPantallaComun(const ProductosScreen());
      },
      onCategorias: () {
        Navigator.pop(context);
        _abrirPantallaComun(const CategoriaScreen());
      },
      onTiendas: () {
        Navigator.pop(context);
        _abrirPantallaComun(const TiendasScreen());
      },
      onLotes: () {
        Navigator.pop(context);
        _abrirPantallaComun(const LotesScreen());
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
        _abrirPantallaComun(const CarritoScreen());
      },
      onHistorial: () {
        Navigator.pop(context);
        _abrirPantallaComun(const HistorialCompraScreen());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBarComun(
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificaciones: () => _abrirPantallaComun(const NotificacionesScreen()),
        onCarrito: () => _abrirPantallaComun(const CarritoScreen()),
        cantidadCarrito: enCarrito,
      ),
      drawer: _construirMenuComun(),

      bottomNavigationBar: BarraNavegacion(
        indiceSeleccionado: 0,
        alSeleccionar: _seleccionarBarraInferior,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : compras.isEmpty
              ? RefreshIndicator(
                  onRefresh: cargarDatos,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 130),
                      Icon(
                        Icons.history,
                        size: 72,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Todavía no hay compras registradas.',
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Pulsa el botón para registrar tu primera compra.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: cargarDatos,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                    children: _agruparComprasPorFecha().entries.expand((grupo) {
                      return [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                color: verde,
                                size: 22,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  grupo.key == 'sin_fecha'
                                      ? 'Fecha no disponible'
                                      : fechaTituloGrupo(grupo.key),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: verde,
                                  ),
                                ),
                              ),
                              Text(
                                '${grupo.value.length} ${grupo.value.length == 1 ? 'compra' : 'compras'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...grupo.value.map(_crearTarjeta),
                      ];
                    }).toList(),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: cargando ? null : abrirFormularioCompra,
        backgroundColor: verdeClaro,
        foregroundColor: verde,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Registrar compra'),
      ),
    );
  }
}
