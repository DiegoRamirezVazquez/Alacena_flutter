
import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';
import 'package:alacena_practica/dao/categoria_dao.dart';


import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/productos_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';

class CategoriaScreen extends StatefulWidget {
  const CategoriaScreen({super.key});

  @override
  State<CategoriaScreen> createState() => _CategoriaScreenState();
}

class _CategoriaScreenState extends State<CategoriaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int enCarrito = 0;

  final CategoriaDB categoriaDB = CategoriaDB();

  List<CategoriaDAO> categorias = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCantidadCarrito();
    cargarCategorias();
  }

  Future<void> cargarCategorias() async {
    setState(() {
      cargando = true;
    });

    try {
      final resultado = await categoriaDB.SELECT();

      if (!mounted) return;

      setState(() {
        categorias = resultado;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar categorías: $e'),
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
                'Categorias de tus productos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF234B35),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Agrega las categorias que tienen tus productos.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: _construirContenido(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          mostrarFormularioCategoria();
        },
        backgroundColor: const Color(0xFF397653),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }



  
  Future<void> mostrarFormularioCategoria({
    CategoriaDAO? categoria,
  }) async {
    final formKey = GlobalKey<FormState>();

    final nombreController = TextEditingController(
      text: categoria?.nombre ?? '',
    );

    final descripcionController = TextEditingController(
      text: categoria?.descripcion ?? '',
    );

    final esEdicion = categoria != null;

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
                esEdicion ? 'Editar categoría' : 'Nueva categoría',
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
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Nombre de la categoría',
                            hintText: 'Ej. Frutas',
                            prefixIcon: const Icon(
                              Icons.category_outlined,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (valor) {
                            if (valor == null || valor.trim().isEmpty) {
                              return 'Escribe el nombre de la categoría';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descripcionController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Descripción (opcional)',
                            hintText: '¿Qué productos incluye?',
                            prefixIcon: const Icon(
                              Icons.notes_outlined,
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
                          : () {
                              Navigator.of(dialogContext).pop();
                            },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF397653),
                          side: const BorderSide(
                            color: Color(0xFF397653),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  final nombre = nombreController.text.trim();
                                  final descripcion =
                                      descripcionController.text.trim();

                                  // Comprobar si el nombre ya existe.
                                  final existentes = await categoriaDB.SELECT();

                                  final nombreDuplicado = existentes.any((elemento) {
                                    final mismoNombre = elemento.nombre
                                            ?.trim()
                                            .toLowerCase() ==
                                        nombre.toLowerCase();

                                    final mismaCategoria =
                                        elemento.id_categoria ==
                                            categoria?.id_categoria;

                                    return mismoNombre && !mismaCategoria;
                                  });

                                  if (nombreDuplicado) {
                                    if (!dialogContext.mounted) return;

                                    actualizarDialogo(() {
                                      guardando = false;
                                    });

                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ya existe una categoría con ese nombre.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );

                                    return;
                                  }

                                  final datos = CategoriaDAO(
                                    id_categoria: categoria?.id_categoria,
                                    nombre: nombre,
                                    descripcion: descripcion.isEmpty
                                        ? null
                                        : descripcion,
                                  );

                                  if (esEdicion) {
                                    await categoriaDB.UPDATE(datos.toMap());
                                  } else {
                                    await categoriaDB.INSERT({
                                      'nombre': nombre,
                                      'descripcion': datos.descripcion,
                                    });
                                  }

                                  if (!dialogContext.mounted) return;

                                  Navigator.pop(dialogContext);

                                  await cargarCategorias();

                                  if (!mounted) return;

                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        esEdicion
                                            ? 'Categoría actualizada correctamente.'
                                            : 'Categoría registrada correctamente.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  if (!dialogContext.mounted) return;

                                  actualizarDialogo(() {
                                    guardando = false;
                                  });

                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'No se pudo guardar la categoría: $e',
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

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombreController.dispose();
      descripcionController.dispose();
    });
  }

  
Future<void> eliminarCategoria(CategoriaDAO categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF7F9F5),
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Seguro que deseas eliminar "${categoria.nombre}"?',
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
      final id = categoria.id_categoria;

      if (id == null) {
        throw Exception('La categoría no tiene un identificador válido.');
      }

      final eliminadas = await categoriaDB.DELETE(id);

      if (!mounted) return;

      if (eliminadas > 0) {
        await cargarCategorias();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categoría eliminada correctamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la categoría para eliminar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar la categoría. '
            'Puede tener productos asociados. Detalle: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  
  Widget _construirContenido() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF397653),
        ),
      );
    }

    if (categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes categorías',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega una para comenzar a organizar tus productos.',
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
      onRefresh: cargarCategorias,
      color: const Color(0xFF397653),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final categoria = categorias[index];

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
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1EFDF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.category_outlined,
                          color: Color(0xFF397653),
                        ),
                      ),

                      // NOMBRE
                      title: Text(
                        categoria.nombre ?? 'Sin nombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF234B35),
                        ),
                      ),

                      // DESCRIPCIÓN
                      subtitle: Text(
                        categoria.descripcion?.trim().isNotEmpty == true
                            ? categoria.descripcion!
                            : 'Sin descripción',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),

                      // ACCIONES
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar categoría',
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF397653),
                            ),
                            onPressed: () {
                              mostrarFormularioCategoria(
                                categoria: categoria,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Eliminar categoría',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              eliminarCategoria(categoria);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: categorias.length,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
