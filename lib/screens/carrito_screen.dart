import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';
import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  // =========================================================
  // 1. VARIABLES
  // =========================================================

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> productosCarrito = [];
  bool cargando = true;
  int enCarrito = 0;

  // =========================================================
  // 2. INICIALIZACIÓN
  // =========================================================

  @override
  void initState() {
    super.initState();
    cargarCarrito();
  }

  // =========================================================
  // 3. CONSULTAR PRODUCTOS DEL CARRITO
  // =========================================================

  Future<void> cargarCarrito() async {
    try {
      final db = await AlacenaDB().database;

      final resultado = await db.rawQuery('''
        SELECT
          c.id,
          c.producto_id,
          c.cantidad,
          c.fecha_agregado,
          p.nombre,
          p.imagen,
          p.categoria_id,
          cat.nombre AS categoria
        FROM CARRITO c
        INNER JOIN PRODUCTOS p
          ON p.id_producto = c.producto_id
        LEFT JOIN CATEGORIA cat
          ON cat.id_categoria = p.categoria_id
        ORDER BY c.fecha_agregado DESC
      ''');

      if (!mounted) return;

      setState(() {
        productosCarrito = resultado;
        enCarrito = resultado.fold<int>(
          0,
          (total, producto) =>
              total + ((producto['cantidad'] as num?)?.toInt() ?? 0),
        );
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar el carrito: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el carrito.'),
        ),
      );
    }
  }

  // =========================================================
  // 4. MODIFICAR CANTIDAD
  // =========================================================

  Future<void> cambiarCantidad(
    int idCarrito,
    int cantidadActual,
    int cambio,
  ) async {
    final nuevaCantidad = cantidadActual + cambio;

    try {
      final db = await AlacenaDB().database;

      if (nuevaCantidad <= 0) {
        await db.delete(
          'CARRITO',
          where: 'id = ?',
          whereArgs: [idCarrito],
        );
      } else {
        await db.update(
          'CARRITO',
          {'cantidad': nuevaCantidad},
          where: 'id = ?',
          whereArgs: [idCarrito],
        );
      }

      await cargarCarrito();
    } catch (e) {
      debugPrint('Error al modificar cantidad: $e');
    }
  }

  // =========================================================
  // 5. ELIMINAR PRODUCTO DEL CARRITO
  // =========================================================

  Future<void> eliminarProducto(int idCarrito) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text(
          '¿Quieres quitar este producto de tu carrito?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final db = await AlacenaDB().database;

      await db.delete(
        'CARRITO',
        where: 'id = ?',
        whereArgs: [idCarrito],
      );

      await cargarCarrito();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto eliminado del carrito.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error al eliminar producto: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar el producto.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  // =========================================================
  // 6. REGISTRAR LA COMPRA DE UN PRODUCTO DEL CARRITO
  // =========================================================

  String _fechaBD(DateTime fecha) {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fechaVisible(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  Future<void> registrarCompra(Map<String, dynamic> producto) async {
    final db = await AlacenaDB().database;
    // Convertimos el resultado a una lista mutable para poder reemplazarla
    // cuando se agregue una tienda nueva.
    var tiendas = List<Map<String, dynamic>>.from(
      await db.query('TIENDA', orderBy: 'nombre COLLATE NOCASE'),
    );

    if (!mounted) return;

    final int idCarrito = (producto['id'] as num).toInt();
    final int idProducto = (producto['producto_id'] as num).toInt();
    final String nombre = producto['nombre']?.toString() ?? 'Producto';
    final int cantidadCarrito = (producto['cantidad'] as num?)?.toInt() ?? 1;
    int cantidad = cantidadCarrito > 0 ? cantidadCarrito : 1;
    int? tiendaId = tiendas.isNotEmpty
        ? (tiendas.first['id_tienda'] as num).toInt()
        : null;
    DateTime fechaCompra = DateTime.now();
    DateTime fechaCaducidad = DateTime.now().add(const Duration(days: 30));
    bool alarmaHabilitada = true;
    bool guardando = false;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (contextDialog, actualizarDialogo) {
          Future<void> agregarOtraTienda() async {
            final formTiendaKey = GlobalKey<FormState>();
            String nombreTienda = '';
            String direccionTienda = '';

            // No usamos TextEditingController: así evitamos que el campo
            // de texto intente notificar después de ser liberado.
            final datosTienda = await showDialog<Map<String, String>?>(
              context: contextDialog,
              builder: (contextTienda) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Agregar otra tienda'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formTiendaKey,
                    child: SizedBox(
                      width: 360,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la tienda',
                              prefixIcon: Icon(Icons.store_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (valor) => nombreTienda = valor,
                            validator: (valor) => valor == null || valor.trim().isEmpty
                                ? 'Escribe el nombre de la tienda'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Dirección (opcional)',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (valor) => direccionTienda = valor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(contextTienda),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      if (!(formTiendaKey.currentState?.validate() ?? false)) return;
                      Navigator.pop(contextTienda, {
                        'nombre': nombreTienda.trim(),
                        'direccion': direccionTienda.trim(),
                      });
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar tienda'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF397653),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );

            if (datosTienda == null || !contextDialog.mounted) return;

            try {
              final nuevoId = await db.insert('TIENDA', {
                'nombre': datosTienda['nombre'],
                'direccion': (datosTienda['direccion'] ?? '').trim().isEmpty
                    ? null
                    : datosTienda['direccion']!.trim(),
              });

              final consultaTiendas = await db.query(
                'TIENDA',
                orderBy: 'nombre COLLATE NOCASE',
              );
              if (!contextDialog.mounted) return;

              actualizarDialogo(() {
                // Reemplazar la referencia; no modificar con clear/addAll
                // una lista que podría ser de solo lectura.
                tiendas = List<Map<String, dynamic>>.from(consultaTiendas);
                tiendaId = nuevoId;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tienda "${datosTienda['nombre']}" agregada.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e, stackTrace) {
              debugPrint('Error al agregar tienda: $e');
              debugPrint('$stackTrace');
              if (!contextDialog.mounted || !mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No se pudo guardar la tienda: $e')),
              );
            }
          }

          Future<void> elegirFecha({required bool esCompra}) async {
            final inicial = esCompra ? fechaCompra : fechaCaducidad;
            final seleccionada = await showDatePicker(
              context: contextDialog,
              initialDate: inicial,
              firstDate: esCompra ? DateTime(2000) : fechaCompra,
              lastDate: DateTime(2100),
              helpText: esCompra ? 'Fecha de compra' : 'Fecha de caducidad',
              cancelText: 'Cancelar',
              confirmText: 'Aceptar',
            );
            if (seleccionada == null || !contextDialog.mounted) return;
            actualizarDialogo(() {
              if (esCompra) {
                fechaCompra = seleccionada;
                if (fechaCaducidad.isBefore(fechaCompra)) {
                  fechaCaducidad = fechaCompra;
                }
              } else {
                fechaCaducidad = seleccionada;
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Registrar compra',
              style: TextStyle(
                color: Color(0xFF234B35),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1EFDF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: _construirImagenProducto(producto['imagen']?.toString()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF234B35),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  producto['categoria']?.toString() ?? 'Sin categoría',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Cantidad del carrito: $cantidadCarrito',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tienda donde lo compraste'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: tiendas.any((t) => (t['id_tienda'] as num?)?.toInt() == tiendaId)
                          ? tiendaId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      items: tiendas.map((tienda) {
                        final id = (tienda['id_tienda'] as num).toInt();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            tienda['nombre']?.toString() ?? 'Tienda sin nombre',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (valor) => actualizarDialogo(() => tiendaId = valor),
                      validator: (_) => tiendaId == null ? 'Agrega o selecciona una tienda' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: guardando ? null : agregarOtraTienda,
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('+ Agregar otra tienda'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF397653),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Cantidad comprada'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          onPressed: cantidad > 1
                              ? () => actualizarDialogo(() => cantidad--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$cantidad',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => actualizarDialogo(() => cantidad++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => elegirFecha(esCompra: true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Compra: ${_fechaVisible(fechaCompra)}'),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => elegirFecha(esCompra: false),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text('Caducidad: ${_fechaVisible(fechaCaducidad)}'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activar alerta de caducidad'),
                      value: alarmaHabilitada,
                      activeColor: const Color(0xFF397653),
                      onChanged: (valor) => actualizarDialogo(() => alarmaHabilitada = valor),
                    ),
                    const Text(
                      'Al confirmar, se registrará la compra, se creará un lote y se quitará este producto del carrito.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: guardando || tiendaId == null || cantidad < 1 || fechaCaducidad.isBefore(fechaCompra)
                    ? null
                    : () async {
                        actualizarDialogo(() => guardando = true);
                        try {
                          // Crea la tabla únicamente si no existe; no elimina datos.
                          await db.execute('''
                            CREATE TABLE IF NOT EXISTS COMPRAS (
                              id_compra INTEGER PRIMARY KEY AUTOINCREMENT,
                              tienda_id INTEGER NOT NULL,
                              fecha_compra TEXT NOT NULL,
                              FOREIGN KEY (tienda_id) REFERENCES TIENDA(id_tienda)
                            )
                          ''');

                          // Compatibilidad con bases antiguas: agrega id_compra
                          // solo si la tabla existente todavía no tiene esa columna.
                          // ALTER TABLE conserva los registros que ya existen.
                          final columnasHistorial = await db.rawQuery(
                            "PRAGMA table_info('HISTORIAL_COMPRA')",
                          );
                          final tieneIdCompra = columnasHistorial.any(
                            (columna) => columna['name'] == 'id_compra',
                          );
                          if (!tieneIdCompra) {
                            await db.execute(
                              'ALTER TABLE HISTORIAL_COMPRA ADD COLUMN id_compra INTEGER',
                            );
                          }

                          await db.transaction((txn) async {
                            final idCompra = await txn.insert('COMPRAS', {
                              'tienda_id': tiendaId,
                              'fecha_compra': _fechaBD(fechaCompra),
                            });
                            final idLote = await txn.insert('LOTES', {
                              'producto_id': idProducto,
                              'cantidad': cantidad,
                              'fecha_compra': _fechaBD(fechaCompra),
                              'fecha_caducidad': _fechaBD(fechaCaducidad),
                              'alarma_habilitada': alarmaHabilitada ? 1 : 0,
                            });
                            final columnas = await txn.rawQuery(
                              "PRAGMA table_info('HISTORIAL_COMPRA')",
                            );

                            debugPrint('ESTRUCTURA HISTORIAL_COMPRA: $columnas');
                            await txn.insert('HISTORIAL_COMPRA', {
                              'id_compra': idCompra,
                              'tienda_id': tiendaId,
                              'producto_id': idProducto,
                              'id_lote': idLote,
                              'cantidad': cantidad,
                              'fecha_compra': _fechaBD(fechaCompra),
                            });
                            await txn.update(
                              'PRODUCTOS',
                              {'ultima_tienda_id': tiendaId},
                              where: 'id_producto = ?',
                              whereArgs: [idProducto],
                            );
                            await txn.delete(
                              'CARRITO',
                              where: 'id = ?',
                              whereArgs: [idCarrito],
                            );
                          });

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e, stackTrace) {
                          debugPrint('Error al registrar compra desde carrito: $e');
                          debugPrint('$stackTrace');
                          if (contextDialog.mounted) {
                            actualizarDialogo(() => guardando = false);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No se pudo registrar la compra: $e')),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF397653),
                  foregroundColor: Colors.white,
                ),
                icon: guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(guardando ? 'Guardando...' : 'Confirmar compra'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == true && mounted) {
      await cargarCarrito();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nombre: compra registrada y lote creado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _construirImagenProducto(String? ruta) {
    if (ruta == null || ruta.trim().isEmpty) return _iconoProducto();
    final archivo = File(ruta);
    if (archivo.existsSync()) {
      return Image.file(
        archivo,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconoProducto(),
      );
    }
    return Image.asset(
      ruta,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _iconoProducto(),
    );
  }

  // =========================================================
  // 6. COMPARTIR LISTA DE COMPRAS COMO IMAGEN
  // =========================================================

  String _fechaListaCompras() {
    final ahora = DateTime.now();
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}';
  }

  Widget _construirReporteCompras() {
    final totalUnidades = productosCarrito.fold<int>(
      0,
      (total, producto) =>
          total + ((producto['cantidad'] as num?)?.toInt() ?? 0),
    );

    return Container(
      width: 340,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E6D5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1EFDF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_basket_outlined,
                  color: Color(0xFF397653),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'MI LISTA DE COMPRAS',
                  style: TextStyle(
                    color: Color(0xFF234B35),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _fechaListaCompras(),
            style: const TextStyle(color: Color(0xFF657568), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Container(height: 2, color: const Color(0xFF397653)),
          const SizedBox(height: 10),
          ...productosCarrito.map((producto) {
            final nombre = producto['nombre']?.toString() ?? 'Producto';
            final categoria = producto['categoria']?.toString() ?? '';
            final cantidad = (producto['cantidad'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_box_outline_blank,
                      color: Color(0xFF397653),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Color(0xFF243328),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (categoria.isNotEmpty)
                          Text(
                            categoria,
                            style: const TextStyle(
                              color: Color(0xFF788579),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'x$cantidad',
                    style: const TextStyle(
                      color: Color(0xFF234B35),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFFD9E6D5)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total de unidades',
                  style: TextStyle(
                    color: Color(0xFF234B35),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$totalUnidades',
                style: const TextStyle(
                  color: Color(0xFF234B35),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Generado con Alacena Smart',
              style: TextStyle(color: Color(0xFF788579), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> compartirListaCompras() async {
    if (productosCarrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega productos al carrito antes de compartir la lista.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controladorCaptura = ScreenshotController();
    bool compartiendo = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (contextDialog, actualizarDialogo) => AlertDialog(
          backgroundColor: const Color(0xFFF7F9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Vista previa de tu lista',
            style: TextStyle(
              color: Color(0xFF234B35),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Screenshot(
                controller: controladorCaptura,
                child: _construirReporteCompras(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: compartiendo
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: compartiendo
                  ? null
                  : () async {
                      actualizarDialogo(() => compartiendo = true);
                      try {
                        final Uint8List? imagen =
                            await controladorCaptura.capture(pixelRatio: 3.0);

                        if (imagen == null) {
                          throw Exception('No se pudo generar la imagen.');
                        }

                        final directorio = await getTemporaryDirectory();
                        final archivo = File(
                          '${directorio.path}/lista_compras_${DateTime.now().millisecondsSinceEpoch}.png',
                        );
                        await archivo.writeAsBytes(imagen, flush: true);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        await Share.shareXFiles(
                          [XFile(archivo.path, mimeType: 'image/png')],
                          text: '¡Hola! Te comparto mi lista de compras de Alacena Smart 🛒',
                          subject: 'Lista de compras',
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          actualizarDialogo(() => compartiendo = false);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No se pudo compartir la lista: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF397653),
                foregroundColor: Colors.white,
              ),
              icon: compartiendo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.share_outlined),
              label: Text(compartiendo ? 'Preparando...' : 'Compartir imagen'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 6. NAVEGACIÓN Y WIDGETS COMPARTIDOS
  // =========================================================

  void _mostrarNotificaciones() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Consulta las alertas en el calendario.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirPantallaComun(Widget pantalla) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  void _irAInicio() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _irASeccionPrincipal(Widget pantalla) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
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
        cargarCarrito();
      },
      onHistorial: () {
        Navigator.pop(context);
        _abrirPantallaComun(const HistorialCompraScreen());
      },
    );
  }

  // =========================================================
  // 7. CONSTRUIR PANTALLA
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final totalUnidades = productosCarrito.fold<int>(
      0,
      (total, producto) =>
          total + (producto['cantidad'] as int),
    );

    return Scaffold(
      // -------------------------------------------------------
      // 6.1. BARRA SUPERIOR
      // -------------------------------------------------------

      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBarComun(
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificaciones: () => _abrirPantallaComun(const NotificacionesScreen()),
        onCarrito: cargarCarrito,
        cantidadCarrito: enCarrito,
      ),
      drawer: _construirMenuComun(),
      bottomNavigationBar: BarraNavegacion(
        indiceSeleccionado: 0,
        alSeleccionar: _seleccionarBarraInferior,
      ),

      // -------------------------------------------------------
      // 6.2. CONTENIDO
      // -------------------------------------------------------

      body: cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : productosCarrito.isEmpty
              ? _construirCarritoVacio()
              : Column(
                  children: [
                    // Resumen de unidades.
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(
                        16, 16, 16, 8,
                      ),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1EFDF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 32,
                            color: Color(0xFF397653),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Productos para comprar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF234B35),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$totalUnidades unidades por comprar '
                                  'en ${productosCarrito.length} '
                                  '${productosCarrito.length == 1
                                      ? 'producto'
                                      : 'productos'}',
                                  style: const TextStyle(
                                    color: Color(0xFF315B40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Acciones para compartir o exportar la lista.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: compartirListaCompras,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartir lista como imagen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF397653),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Lista de productos.
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: productosCarrito.length,
                        itemBuilder: (context, index) {
                          final producto =
                              productosCarrito[index];

                          final idCarrito =
                              producto['id'] as int;
                          final cantidad =
                              producto['cantidad'] as int;

                          final nombre =
                              producto['nombre']?.toString()
                                  ?? 'Producto';

                          final imagen =
                              producto['imagen']?.toString();

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                              side: const BorderSide(
                                color: Color(0xFFE2E8DD),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Imagen del producto.
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 68,
                                      height: 68,
                                      child: _construirImagenProducto(imagen),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Nombre y cantidad.
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 15,
                                            color:
                                                Color(0xFF234B35),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          producto['categoria']?.toString() ?? 'Sin categoría',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Controles de cantidad.
                                        Row(
                                          children: [
                                            _botonCantidad(
                                              icono: Icons.remove,
                                              accion: () =>
                                                  cambiarCantidad(
                                                idCarrito,
                                                cantidad,
                                                -1,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                '$cantidad',
                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            _botonCantidad(
                                              icono: Icons.add,
                                              accion: () =>
                                                  cambiarCantidad(
                                                idCarrito,
                                                cantidad,
                                                1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () => registrarCompra(producto),
                                            icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                            label: const Text('Producto comprado'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF397653),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Eliminar producto.
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () =>
                                        eliminarProducto(
                                      idCarrito,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  // =========================================================
  // 7. WIDGETS AUXILIARES
  // =========================================================

  Widget _construirCarritoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 85,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 18),
            const Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega productos desde tu alacena para '
              'registrar tus próximas compras.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Regresar'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF397653),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconoProducto() {
    return Container(
      color: const Color(0xFFE1EFDF),
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 34,
        color: Color(0xFF397653),
      ),
    );
  }

  Widget _botonCantidad({
    required IconData icono,
    required VoidCallback accion,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: accion,
        padding: EdgeInsets.zero,
        iconSize: 18,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE1EFDF),
          foregroundColor: const Color(0xFF234B35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: Icon(icono),
      ),
    );
  }
}