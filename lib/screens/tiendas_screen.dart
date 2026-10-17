
import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';
import 'package:alacena_practica/dao/tienda_dao.dart';


import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';

class TiendasScreen extends StatefulWidget {
  const TiendasScreen({super.key});

  @override
  State<TiendasScreen> createState() => _TiendasScreenState();
}

class _TiendasScreenState extends State<TiendasScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int enCarrito = 0;

  final TiendaDB tiendaDB = TiendaDB();

  List<TiendaDAO> tiendas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCantidadCarrito();
    cargarTiendas();
  }

  Future<void> cargarTiendas() async {
    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    try {
      final resultado = await tiendaDB.SELECT();

      if (!mounted) return;

      setState(() {
        tiendas = resultado;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar tiendas: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      backgroundColor: const Color(0xFFF7F9F5),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tus lugares de compra',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF234B35),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Administra las tiendas donde compras tus productos.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(child: construirContenido()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormularioTienda(),
        backgroundColor: const Color(0xFF397653),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  // FORMULARIO PARA INSERTAR Y ACTUALIZAR
  Future<void> mostrarFormularioTienda({
    TiendaDAO? tienda,
  }) async {
    final formKey = GlobalKey<FormState>();

    final nombreController = TextEditingController(
      text: tienda?.nombre ?? '',
    );

    final direccionController = TextEditingController(
      text: tienda?.direccion ?? '',
    );

    final esEdicion = tienda != null;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          bool guardando = false;

          return StatefulBuilder(
            builder: (contextoDialogo, actualizarDialogo) {
              return AlertDialog(
                backgroundColor: const Color(0xFFF7F9F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Text(
                  esEdicion ? 'Editar tienda' : 'Nueva tienda',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF234B35),
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nombreController,
                            autofocus: true,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Nombre de la tienda',
                              hintText: 'Ej. Supermercado',
                              prefixIcon: const Icon(
                                Icons.store_outlined,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (valor) {
                              if (valor == null ||
                                  valor.trim().isEmpty) {
                                return 'Escribe el nombre de la tienda';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: direccionController,
                            textCapitalization:
                                TextCapitalization.sentences,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Dirección (opcional)',
                              hintText: 'Calle, colonia o ubicación',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: guardando
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF397653),
                            side: const BorderSide(
                              color: Color(0xFF397653),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF397653),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: guardando
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  actualizarDialogo(() {
                                    guardando = true;
                                  });

                                  try {
                                    final nombre =
                                        nombreController.text.trim();
                                    final direccion =
                                        direccionController.text.trim();

                                    final datos = TiendaDAO(
                                      id_tienda: tienda?.id_tienda,
                                      nombre: nombre,
                                      direccion: direccion.isEmpty
                                          ? null
                                          : direccion,
                                    );

                                    if (esEdicion) {
                                      await tiendaDB.UPDATE(datos.toMap());
                                    } else {
                                      await tiendaDB.INSERT({
                                        'nombre': nombre,
                                        'direccion': datos.direccion,
                                      });
                                    }

                                    if (!dialogContext.mounted) return;

                                    Navigator.of(dialogContext).pop();

                                    await cargarTiendas();

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          esEdicion
                                              ? 'Tienda actualizada correctamente.'
                                              : 'Tienda registrada correctamente.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!dialogContext.mounted) return;

                                    actualizarDialogo(() {
                                      guardando = false;
                                    });

                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo guardar la tienda: $e',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          icon: guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            guardando ? 'Guardando...' : 'Guardar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Evita liberar los controladores durante la animación de cierre.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nombreController.dispose();
        direccionController.dispose();
      });
    }
  }

  // CONFIRMAR Y ELIMINAR UNA TIENDA
  Future<void> eliminarTienda(TiendaDAO tienda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF7F9F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Eliminar tienda',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF234B35),
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminar "${tienda.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final id = tienda.id_tienda;

      if (id == null) {
        throw Exception('Identificador de tienda inválido.');
      }

      final eliminadas = await tiendaDB.DELETE(id);

      if (!mounted) return;

      if (eliminadas > 0) {
        await cargarTiendas();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tienda eliminada correctamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la tienda para eliminar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar la tienda. '
            'Puede tener productos o compras asociados. Detalle: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  
  // LISTA DE TIENDAS UTILIZANDO SLIVERS
  Widget construirContenido() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF397653),
        ),
      );
    }

    if (tiendas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes tiendas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega una tienda para comenzar a organizar tus compras.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cargarTiendas,
      color: const Color(0xFF397653),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tienda = tiendas[index];

                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                        color: Color(0xFFE2E8DD),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),

                      // ICONO DE LA TIENDA
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1EFDF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.store_outlined,
                          color: Color(0xFF397653),
                        ),
                      ),

                      // NOMBRE
                      title: Text(
                        tienda.nombre ?? 'Sin nombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF234B35),
                        ),
                      ),

                      // DIRECCIÓN
                      subtitle: Text(
                        tienda.direccion?.trim().isNotEmpty == true
                            ? tienda.direccion!
                            : 'Sin dirección registrada',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),

                      // BOTONES DE EDICIÓN Y ELIMINACIÓN
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar tienda',
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF397653),
                            ),
                            onPressed: () {
                              mostrarFormularioTienda(
                                tienda: tienda,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Eliminar tienda',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              eliminarTienda(tienda);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: tiendas.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
