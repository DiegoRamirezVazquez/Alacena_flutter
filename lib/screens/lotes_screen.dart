
import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';

import '../dao/lotes_dao.dart';


import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';

class LotesScreen extends StatefulWidget {
  const LotesScreen({super.key});

  @override
  State<LotesScreen> createState() => _LotesScreenState();
}

class _LotesScreenState extends State<LotesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int enCarrito = 0;

  final LotesDB lotesDB = LotesDB();

  List<LotesDAO> lotes = [];
  List<Map<String, dynamic>> productos = [];

  bool cargando = true;
  bool guardando = false;
  bool mostrarAgotados = false;

  int? productoSeleccionado;
  int cantidad = 1;
  int alarmaHabilitada = 1;

  DateTime? fechaCompra;
  DateTime? fechaCaducidad;

  static const Color verde = Color(0xFF176B45);
  static const Color verdeClaro = Color(0xFFD8F5E3);

  @override
  void initState() {
    super.initState();
    _cargarCantidadCarrito();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final resultados = await Future.wait([
        lotesDB.SELECT(),
        lotesDB.SELECT_PRODUCTOS(),
      ]);

      if (!mounted) return;

      setState(() {
        lotes = resultados[0] as List<LotesDAO>;
        productos = resultados[1] as List<Map<String, dynamic>>;
        cargando = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR AL CARGAR DATOS: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      mostrarMensaje('No se pudieron cargar los datos: $e');
    }
  }

  Future<void> recargarSoloLotes() async {
    try {
      final resultado = await lotesDB
          .SELECT()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        lotes = resultado;
      });

      debugPrint('Lotes recargados: ${resultado.length}');
    } catch (e, stackTrace) {
      debugPrint('ERROR AL RECARGAR LOTES: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      mostrarMensaje(
        'El lote se guardó, pero no se pudo actualizar la lista.',
      );
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

  String fechaTexto(String? fecha) {
    if (fecha == null || fecha.isEmpty) {
      return 'Sin fecha';
    }

    final partes = fecha.split('-');

    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }

    return fecha;
  }

  Future<DateTime?> seleccionarFecha(
    BuildContext contexto,
    DateTime? inicial,
  ) {
    final hoy = DateTime.now();
    final fechaInicial = inicial ?? hoy;

    return showDatePicker(
      context: contexto,
      initialDate: fechaInicial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
  }

  Color colorCaducidad(String? fecha) {
    if (fecha == null || fecha.isEmpty) {
      return Colors.grey;
    }

    final caducidad = DateTime.tryParse(fecha);
    if (caducidad == null) return Colors.grey;

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final dias = caducidad.difference(hoySinHora).inDays;

    if (dias < 0) return Colors.red;
    if (dias <= 5) return Colors.orange;

    return Colors.green;
  }

  String estadoCaducidad(String? fecha) {
    if (fecha == null || fecha.isEmpty) {
      return 'Sin fecha';
    }

    final caducidad = DateTime.tryParse(fecha);
    if (caducidad == null) return 'Fecha no válida';

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final dias = caducidad.difference(hoySinHora).inDays;

    if (dias < 0) return 'Producto caducado';
    if (dias == 0) return 'Caduca hoy';
    if (dias <= 5) return 'Caduca pronto';

    return 'Vigente';
  }

  Future<void> abrirFormulario({LotesDAO? lote}) async {
    if (guardando) return;

    if (productos.isEmpty) {
      mostrarMensaje(
        'Primero registra al menos un producto en el módulo Productos.',
      );
      return;
    }

    productoSeleccionado =
        lote?.producto_id ?? productos.first['id_producto'] as int;

    cantidad = lote?.cantidad ?? 1;
    alarmaHabilitada = lote?.alarma_habilitada ?? 1;

    fechaCompra = lote?.fecha_compra != null
        ? DateTime.tryParse(lote!.fecha_compra!)
        : DateTime.now();

    fechaCaducidad = lote?.fecha_caducidad != null
        ? DateTime.tryParse(lote!.fecha_caducidad!)
        : DateTime.now().add(const Duration(days: 30));

    final formKey = GlobalKey<FormState>();
    bool guardadoCorrectamente = false;
    bool guardandoDialogo = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (contexto, actualizarDialogo) {
              return AlertDialog(
                title: Text(
                  lote == null ? 'Registrar lote' : 'Editar lote',
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            value: productoSeleccionado,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Producto',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.inventory_2_outlined,
                              ),
                            ),
                            items: productos.map((producto) {
                              return DropdownMenuItem<int>(
                                value: producto['id_producto'] as int,
                                child: Text(
                                  producto['nombre'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: guardandoDialogo
                                ? null
                                : (valor) {
                                    actualizarDialogo(() {
                                      productoSeleccionado = valor;
                                    });
                                  },
                            validator: (valor) {
                              if (valor == null) {
                                return 'Selecciona un producto';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: cantidad.toString(),
                            enabled: !guardandoDialogo,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad disponible',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (valor) {
                              final numero = int.tryParse(valor ?? '');

                              if (numero == null) {
                                return 'Ingresa una cantidad válida';
                              }

                              if (numero < 0) {
                                return 'La cantidad no puede ser negativa';
                              }

                              return null;
                            },
                            onSaved: (valor) {
                              cantidad = int.parse(valor!);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Fecha de compra',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: guardandoDialogo
                                ? null
                                : () async {
                                    final fecha = await seleccionarFecha(
                                      contexto,
                                      fechaCompra,
                                    );

                                    if (fecha != null &&
                                        contexto.mounted) {
                                      actualizarDialogo(() {
                                        fechaCompra = fecha;
                                      });
                                    }
                                  },
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                            ),
                            label: Text(
                              fechaCompra == null
                                  ? 'Seleccionar fecha'
                                  : fechaTexto(
                                      fechaParaBD(fechaCompra!),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Fecha de caducidad',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: guardandoDialogo
                                ? null
                                : () async {
                                    final fecha = await seleccionarFecha(
                                      contexto,
                                      fechaCaducidad,
                                    );

                                    if (fecha != null &&
                                        contexto.mounted) {
                                      actualizarDialogo(() {
                                        fechaCaducidad = fecha;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              fechaCaducidad == null
                                  ? 'Seleccionar fecha'
                                  : fechaTexto(
                                      fechaParaBD(fechaCaducidad!),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Alerta de caducidad'),
                            subtitle: const Text(
                              'Habilitar el seguimiento de este lote',
                            ),
                            value: alarmaHabilitada == 1,
                            onChanged: guardandoDialogo
                                ? null
                                : (valor) {
                                    actualizarDialogo(() {
                                      alarmaHabilitada = valor ? 1 : 0;
                                    });
                                  },
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

                            if (fechaCompra == null ||
                                fechaCaducidad == null) {
                              mostrarMensaje('Selecciona las dos fechas.');
                              return;
                            }

                            if (fechaCaducidad!.isBefore(fechaCompra!)) {
                              mostrarMensaje(
                                'La caducidad no puede ser anterior a la compra.',
                              );
                              return;
                            }

                            formulario.save();

                            final datos = <String, dynamic>{
                              'producto_id': productoSeleccionado,
                              'cantidad': cantidad,
                              'fecha_compra': fechaParaBD(fechaCompra!),
                              'fecha_caducidad':
                                  fechaParaBD(fechaCaducidad!),
                              'alarma_habilitada': alarmaHabilitada,
                            };

                            actualizarDialogo(() {
                              guardandoDialogo = true;
                            });

                            try {
                              debugPrint(
                                lote == null
                                    ? 'Registrando lote...'
                                    : 'Actualizando lote...',
                              );

                              if (lote == null) {
                                await lotesDB
                                    .INSERT(datos)
                                    .timeout(const Duration(seconds: 10));
                              } else {
                                datos['id_lote'] = lote.id_lote;

                                final resultado = await lotesDB
                                    .UPDATE(datos)
                                    .timeout(const Duration(seconds: 10));

                                if (resultado == 0) {
                                  throw Exception(
                                    'No se encontró el lote para actualizar.',
                                  );
                                }
                              }

                              debugPrint('Lote guardado correctamente');
                              guardadoCorrectamente = true;

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            } catch (e, stackTrace) {
                              debugPrint('ERROR AL GUARDAR LOTE: $e');
                              debugPrint('$stackTrace');

                              if (contexto.mounted) {
                                actualizarDialogo(() {
                                  guardandoDialogo = false;
                                });
                              }

                              if (mounted) {
                                mostrarMensaje(
                                  'No se pudo guardar el lote: $e',
                                );
                              }
                            }
                          },
                    icon: guardandoDialogo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      guardandoDialogo ? 'Guardando...' : 'Guardar',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (guardadoCorrectamente && mounted) {
        await recargarSoloLotes();

        if (!mounted) return;

        mostrarMensaje(
          lote == null
              ? 'Lote registrado correctamente.'
              : 'Lote actualizado correctamente.',
        );
      }
    } finally {
      guardando = false;
    }
  }

  Future<void> eliminarLote(LotesDAO lote) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar lote'),
          content: Text(
            '¿Deseas eliminar el lote de '
            '"${lote.nombre_producto ?? 'este producto'}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await lotesDB.DELETE(lote.id_lote!);
      await recargarSoloLotes();

      if (!mounted) return;

      mostrarMensaje('Lote eliminado correctamente.');
    } catch (e, stackTrace) {
      debugPrint('ERROR AL ELIMINAR LOTE: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      mostrarMensaje('No se pudo eliminar el lote: $e');
    }
  }

  Widget _detalleLote(
    IconData icono,
    String texto, {
    Color color = Colors.black54,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumenLotes({
    required String titulo,
    required int cantidad,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback alTocar,
  }) {
    return Material(
      color: seleccionado ? verdeClaro : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: seleccionado ? verde : Colors.grey.withValues(alpha: 0.25),
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: seleccionado ? verde : Colors.grey, size: 22),
              const SizedBox(height: 8),
              Text(
                '$cantidad',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: seleccionado ? verde : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(titulo, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crearTarjetaLote(LotesDAO lote) {
    final color = colorCaducidad(lote.fecha_caducidad);
    final alarmaActiva = lote.alarma_habilitada == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey('lote_${lote.id_lote}'),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            Icons.inventory_2_outlined,
            color: color,
          ),
        ),
        title: Text(
          lote.nombre_producto ?? 'Producto sin nombre',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Lote #${lote.id_lote} · ${lote.cantidad ?? 0} unidades',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones del lote',
          onSelected: (opcion) {
            if (opcion == 'editar') {
              abrirFormulario(lote: lote);
            } else if (opcion == 'eliminar') {
              eliminarLote(lote);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 10),
                  Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'eliminar',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Eliminar'),
                ],
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_vert),
          ),
        ),
        children: [
          const Divider(height: 12),
          _detalleLote(
            Icons.numbers,
            'Cantidad disponible: ${lote.cantidad ?? 0}',
          ),
          _detalleLote(
            Icons.shopping_cart_outlined,
            'Fecha de compra: ${fechaTexto(lote.fecha_compra)}',
          ),
          _detalleLote(
            Icons.event_outlined,
            'Fecha de caducidad: ${fechaTexto(lote.fecha_caducidad)}',
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: color),
                    const SizedBox(width: 7),
                    Text(
                      estadoCaducidad(lote.fecha_caducidad),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _detalleLote(
            alarmaActiva
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            alarmaActiva
                ? 'Alerta de caducidad activada'
                : 'Alerta de caducidad desactivada',
            color: alarmaActiva ? Colors.green : Colors.grey,
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
      onNotificaciones: () =>
          _abrirPantallaComun(const NotificacionesScreen()),
      onCarrito: () =>
          _abrirPantallaComun(const CarritoScreen()),
      cantidadCarrito: enCarrito,
    ),

    drawer: _construirMenuComun(),

    bottomNavigationBar: BarraNavegacion(
      indiceSeleccionado: 0,
      alSeleccionar: _seleccionarBarraInferior,
    ),

    body: cargando
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Builder(
            builder: (context) {
              final lotesActivos = lotes
                  .where((lote) => (lote.cantidad ?? 0) > 0)
                  .toList();

              final lotesAgotados = lotes
                  .where((lote) => (lote.cantidad ?? 0) <= 0)
                  .toList();

              final lotesVisibles =
                  mostrarAgotados ? lotesAgotados : lotesActivos;

              return RefreshIndicator(
                onRefresh: cargarDatos,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),

                  slivers: [
                    // ENCABEZADO
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mis lotes',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: verde,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Controla las existencias de tus alimentos',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // TARJETAS DE RESUMEN
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        20,
                        16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: _tarjetaResumenLotes(
                                titulo: 'Lotes activos',
                                cantidad: lotesActivos.length,
                                icono: Icons.inventory_2_outlined,
                                seleccionado: !mostrarAgotados,
                                alTocar: () {
                                  setState(() {
                                    mostrarAgotados = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _tarjetaResumenLotes(
                                titulo: 'Agotados',
                                cantidad: lotesAgotados.length,
                                icono: Icons.archive_outlined,
                                seleccionado: mostrarAgotados,
                                alTocar: () {
                                  setState(() {
                                    mostrarAgotados = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // TÍTULO DE LA LISTA
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        10,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          mostrarAgotados
                              ? 'Lotes agotados'
                              : 'Existencias actuales',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // MENSAJE CUANDO NO HAY LOTES
                    if (lotesVisibles.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          100,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Icon(
                                mostrarAgotados
                                    ? Icons.inventory_outlined
                                    : Icons.kitchen_outlined,
                                size: 58,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                mostrarAgotados
                                    ? 'No tienes lotes agotados.'
                                    : 'No tienes lotes con existencias.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                mostrarAgotados
                                    ? 'Los lotes que lleguen a cero aparecerán aquí.'
                                    : 'Los lotes nuevos se crearán automáticamente al registrar una compra.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )

                    // LISTA DE LOTES CON SLIVERLIST
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          100,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final lote = lotesVisibles[index];

                              return _crearTarjetaLote(lote);
                            },
                            childCount: lotesVisibles.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
     );
  }

}
