import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/notificaciones_screen.dart';
import 'package:flutter/material.dart';
import '../dao/productos_dao.dart';
import '../dao/categoria_dao.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';




import 'package:alacena_practica/database/alacena_db.dart';
import 'package:alacena_practica/screens/alacena_screen.dart';
import 'package:alacena_practica/screens/calendario_screen.dart';
import 'package:alacena_practica/screens/categorias_screen.dart';
import 'package:alacena_practica/screens/tiendas_screen.dart';
import 'package:alacena_practica/screens/lotes_screen.dart';
import 'package:alacena_practica/screens/carrito_screen.dart';
import 'package:alacena_practica/screens/historial_compra_screen.dart';
import 'package:alacena_practica/widgets/app_bar_comun.dart';
import 'package:alacena_practica/widgets/menu_lateral.dart';
import 'package:alacena_practica/widgets/barra_navegacion.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int enCarrito = 0;

  final ProductosDB productosDB = ProductosDB();
  final CategoriaDB categoriaDB = CategoriaDB();
  final ImagePicker selectorImagen = ImagePicker();

  String? rutaImagenSeleccionada;

  List<ProductosDAO> productos = [];
  bool cargando = true;
  List<CategoriaDAO> categorias = [];
  int? categoriaSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarCantidadCarrito();
    cargarProductos();
  }

    Future<String?> guardarImagenPermanente(String? rutaOriginal) async {
    if (rutaOriginal == null || rutaOriginal.isEmpty) {
      return null;
    }

    final archivoOriginal = File(rutaOriginal);

    if (!await archivoOriginal.exists()) {
      throw Exception('La imagen seleccionada ya no está disponible.');
    }

    final directorio = await getApplicationDocumentsDirectory();

    final carpetaImagenes = Directory(
      '${directorio.path}/imagenes_productos',
    );

    if (!await carpetaImagenes.exists()) {
      await carpetaImagenes.create(recursive: true);
    }

    final extension = rutaOriginal.contains('.')
        ? rutaOriginal.substring(rutaOriginal.lastIndexOf('.'))
        : '.jpg';

    final nombreArchivo =
        'producto_${DateTime.now().microsecondsSinceEpoch}$extension';

    final nuevaRuta =
        '${carpetaImagenes.path}/$nombreArchivo';

    await archivoOriginal.copy(nuevaRuta);

    return nuevaRuta;
  }

  Future<void> cargarProductos() async {
    try {
      final resultado = await productosDB.SELECT();
      final resultadoCategorias = await categoriaDB.SELECT();

      if (!mounted) return;

      setState(() {
        productos = resultado;
        categorias = resultadoCategorias;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  
Future<void> _crearCategoriaDesdeProducto(
  StateSetter actualizarFormularioProducto,
) async {
  final formKey = GlobalKey<FormState>();

  String nombreCategoria = '';
  String descripcionCategoria = '';
  bool guardando = false;

  final nombreCreado = await showDialog<String>(
    context: context,
    builder: (contextoCategoria) {
      return StatefulBuilder(
        builder: (contextoInterno, actualizarDialogo) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: const Color(0xFFF7F9F5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Crear categoría',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF234B35),
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      autofocus: true,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la categoría',
                        hintText: 'Ej. Frutas',
                        prefixIcon:
                            Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (valor) {
                        nombreCategoria = valor;
                      },
                      validator: (valor) {
                        if (valor == null ||
                            valor.trim().isEmpty) {
                          return 'Escribe el nombre de la categoría';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      textCapitalization:
                          TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: '¿Qué productos incluye?',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (valor) {
                        descripcionCategoria = valor;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando
                    ? null
                    : () {
                        Navigator.pop(contextoCategoria);
                      },
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: guardando
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ??
                            false)) {
                          return;
                        }

                        final nombre = nombreCategoria.trim();
                        actualizarDialogo(() {
                          guardando = true;
                        });

                        try {
                          final existentes =
                              await categoriaDB.SELECT();

                          final duplicada = existentes.any(
                            (item) =>
                                item.nombre?.trim().toLowerCase() ==
                                nombre.toLowerCase(),
                          );

                          if (duplicada) {
                            if (!contextoCategoria.mounted) {
                              return;
                            }

                            actualizarDialogo(() {
                              guardando = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ya existe una categoría con ese nombre.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          await categoriaDB.INSERT({
                            'nombre': nombre,
                            'descripcion':
                                descripcionCategoria.trim().isEmpty
                                    ? null
                                    : descripcionCategoria.trim(),
                          });

                          if (!contextoCategoria.mounted) return;

                          Navigator.pop(contextoCategoria, nombre);
                        } catch (e) {
                          if (!contextoCategoria.mounted) return;

                          actualizarDialogo(() {
                            guardando = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No se pudo crear la categoría: $e',
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
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  guardando
                      ? 'Guardando...'
                      : 'Guardar categoría',
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (nombreCreado == null || !mounted) return;

  try {
    final actualizadas = await categoriaDB.SELECT();

    if (!mounted) return;

    CategoriaDAO? categoriaNueva;

    for (final item in actualizadas) {
      if (item.nombre?.trim().toLowerCase() ==
          nombreCreado.trim().toLowerCase()) {
        categoriaNueva = item;
        break;
      }
    }

    actualizarFormularioProducto(() {
      categorias = actualizadas;
      categoriaSeleccionada = categoriaNueva?.id_categoria;
    });

    if (categoriaNueva?.id_categoria == null) {
      mostrarMensajeCategoria(
        'Categoría creada. Selecciónala en la lista.',
      );
    }
  } catch (e) {
    mostrarMensajeCategoria(
      'La categoría se creó, pero no se pudo actualizar la lista: $e',
    );
  }
}

  void mostrarMensajeCategoria(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  
  Future<void> mostrarFormulario({ProductosDAO? producto}) async {
    final nombreController = TextEditingController(
      text: producto?.nombre ?? '',
    );

    final stockController = TextEditingController(
      text: '${producto?.stock_minimo ?? 1}',
    );

    final alertaController = TextEditingController(
      text: '${producto?.dias_alerta_caducidad ?? 5}',
    );

    final formKey = GlobalKey<FormState>();

    rutaImagenSeleccionada = producto?.imagen;
    categoriaSeleccionada = producto?.categoria_id;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (contextDialogo, actualizarDialogo) {
            return AlertDialog(
              title: Text(
                producto == null ? 'Nuevo producto' : 'Editar producto',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nombre del producto.
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del alimento',
                          hintText: 'Ej. Leche',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Escribe el nombre del alimento';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Selección de categoría.
                      DropdownButtonFormField<int>(
                        value: categoriaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: categorias.map((categoria) {
                          return DropdownMenuItem<int>(
                            value: categoria.id_categoria,
                            child: Text(
                              categoria.nombre ?? 'Sin nombre',
                            ),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          actualizarDialogo(() {
                            categoriaSeleccionada = valor;
                          });
                        },
                        validator: (valor) {
                          if (valor == null) {
                            return 'Selecciona una categoría';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _crearCategoriaDesdeProducto(actualizarDialogo);
                          },
                          icon: const Icon(
                            Icons.add_circle_outline,
                            size: 19,
                          ),
                          label: const Text('Crear categoría'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF397653),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Stock mínimo.
                      TextFormField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock mínimo',
                        ),
                        validator: (value) {
                          final numero = int.tryParse(value ?? '');

                          if (numero == null || numero < 0) {
                            return 'Escribe un número válido';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Días de anticipación para caducidad.
                      TextFormField(
                        controller: alertaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Avisar días antes de caducar',
                        ),
                        validator: (value) {
                          final numero = int.tryParse(value ?? '');

                          if (numero == null || numero < 0) {
                            return 'Escribe un número válido';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Título de la sección de fotografía.
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Fotografía del alimento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Vista previa de la fotografía.
                      if (rutaImagenSeleccionada != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(rutaImagenSeleccionada!),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1EFDF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Color(0xFF397653),
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Abrir la galería.
                      OutlinedButton.icon(
                        onPressed: () async {
                          await seleccionarImagen();

                          if (!contextDialogo.mounted) return;

                          actualizarDialogo(() {});
                        },
                        icon: const Icon(
                          Icons.photo_library_outlined,
                        ),
                        label: const Text('Seleccionar fotografía'),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: Text(
                    producto == null ? 'Guardar' : 'Guardar cambios',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (guardado == true) {
      try {
        final imagenPermanente = rutaImagenSeleccionada != null
          ? await guardarImagenPermanente(rutaImagenSeleccionada)
          : producto?.imagen;
        final productoActualizado = ProductosDAO(
          id_producto: producto?.id_producto,
          nombre: nombreController.text.trim(),
          imagen: imagenPermanente,
          categoria_id: categoriaSeleccionada,
          stock_minimo: int.parse(stockController.text),
          dias_alerta_caducidad: int.parse(alertaController.text),
          ultima_tienda_id: producto?.ultima_tienda_id,
        );

        if (producto == null) {
          await productosDB.INSERT(productoActualizado.toMap());
        } else {
          await productosDB.UPDATE(productoActualizado.toMap());
        }

        await cargarProductos();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              producto == null
                  ? 'Producto guardado correctamente'
                  : 'Producto actualizado correctamente',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el producto: $e'),
          ),
        );
      }
    }

    nombreController.dispose();
    stockController.dispose();
    alertaController.dispose();
  }

Future<void> editarProducto(ProductosDAO producto) async {
  await mostrarFormulario(producto: producto);
}

  
Future<void> eliminarProducto(ProductosDAO producto) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Eliminar producto'),
      content: Text(
        '¿Quieres eliminar "${producto.nombre ?? 'este producto'}"?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirmar != true || producto.id_producto == null) return;

  try {
    await productosDB.DELETE(producto.id_producto!);
    await cargarProductos();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Producto eliminado correctamente'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    final conexion = await AlacenaDB().database;

    final lotes = await conexion.query(
      'LOTES',
      where: 'producto_id = ?',
      whereArgs: [producto.id_producto],
    );

    final historial = await conexion.query(
      'HISTORIAL_COMPRA',
      where: 'producto_id = ?',
      whereArgs: [producto.id_producto],
    );

    if (!mounted) return;

    String mensaje;

    if (lotes.isNotEmpty && historial.isNotEmpty) {
      mensaje =
          'No se puede eliminar: tiene lotes y compras registradas.';
    } else if (lotes.isNotEmpty) {
      mensaje = 'No se puede eliminar: tiene lotes asociados.';
    } else if (historial.isNotEmpty) {
      mensaje =
          'No se puede eliminar: tiene compras en el historial.';
    } else {
      mensaje = 'No se pudo eliminar el producto: $e';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }
}


    
  Future<void> seleccionarImagen() async {
    try {
      final XFile? imagen = await selectorImagen.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (imagen == null) return;

      if (!mounted) return;

      setState(() {
        rutaImagenSeleccionada = imagen.path;
      });
    } catch (e, stackTrace) {
      debugPrint('Error al seleccionar imagen: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar la imagen: $e'),
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

      body: Column(
        children: [
          // ENCABEZADO
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis productos',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF234B35),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Administra los alimentos de tu alacena',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO PRINCIPAL
          Expanded(
            child: cargando
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : productos.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Color(0xFF397653),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tu alacena está esperando alimentos',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Pulsa + para agregar tu primer producto',
                            ),
                          ],
                        ),
                      )

                    
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16),

                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final producto = productos[index];

                                  return Card(
                                    margin: const EdgeInsets.only(
                                      bottom: 10,
                                    ),

                                    child: ListTile(
                                      leading: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),

                                        child: producto.imagen != null &&
                                                producto.imagen!.isNotEmpty &&
                                                File(producto.imagen!)
                                                    .existsSync()
                                            ? Image.file(
                                                File(producto.imagen!),
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,

                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return const SizedBox(
                                                    width: 56,
                                                    height: 56,
                                                    child: ColoredBox(
                                                      color:
                                                          Color(0xFFE1EFDF),
                                                      child: Icon(
                                                        Icons.fastfood_outlined,
                                                        color:
                                                            Color(0xFF397653),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                width: 56,
                                                height: 56,
                                                color:
                                                    const Color(0xFFE1EFDF),
                                                child: const Icon(
                                                  Icons.fastfood_outlined,
                                                  color: Color(0xFF397653),
                                                ),
                                              ),
                                      ),

                                      // NOMBRE DEL PRODUCTO
                                      title: Text(
                                        producto.nombre ?? 'Sin nombre',
                                      ),

                                      // INFORMACIÓN DEL PRODUCTO
                                      subtitle: Text(
                                        'Stock mínimo: '
                                        '${producto.stock_minimo}'
                                        '\nAviso de caducidad: '
                                        '${producto.dias_alerta_caducidad} días',
                                      ),

                                      isThreeLine: true,

                                      // BOTONES DE EDICIÓN Y ELIMINACIÓN
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Editar producto',

                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: Color(0xFF397653),
                                            ),

                                            onPressed: () {
                                              editarProducto(producto);
                                            },
                                          ),

                                          IconButton(
                                            tooltip: 'Eliminar producto',

                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),

                                            onPressed: () {
                                              eliminarProducto(producto);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },

                                // CANTIDAD DE ELEMENTOS DE LA LISTA
                                childCount: productos.length,
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),

      // BOTÓN PARA AGREGAR PRODUCTOS
      floatingActionButton: FloatingActionButton.extended(
        onPressed: mostrarFormulario,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

}
