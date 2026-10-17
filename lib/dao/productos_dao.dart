import '../database/alacena_db.dart';

class ProductosDAO {
  int? id_producto;
  String? nombre;
  String? imagen;
  int? categoria_id;
  int? stock_minimo;
  int? dias_alerta_caducidad;
  int? ultima_tienda_id;

  ProductosDAO({
    this.id_producto,
    this.nombre,
    this.imagen,
    this.categoria_id,
    this.stock_minimo,
    this.dias_alerta_caducidad,
    this.ultima_tienda_id,
  });

  factory ProductosDAO.fromMap(Map<String, dynamic> producto) {
    return ProductosDAO(
      id_producto: producto['id_producto'] as int?,
      nombre: producto['nombre'] as String?,
      imagen: producto['imagen'] as String?,
      categoria_id: producto['categoria_id'] as int?,
      stock_minimo: producto['stock_minimo'] as int?,
      dias_alerta_caducidad:
          producto['dias_alerta_caducidad'] as int?,
      ultima_tienda_id: producto['ultima_tienda_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_producto': id_producto,
      'nombre': nombre,
      'imagen': imagen,
      'categoria_id': categoria_id,
      'stock_minimo': stock_minimo,
      'dias_alerta_caducidad': dias_alerta_caducidad,
      'ultima_tienda_id': ultima_tienda_id,
    };
  }
}

class ProductosDB {
  Future<int> INSERT(Map<String, dynamic> producto) async {
    final conexion = await AlacenaDB().database;

    return conexion.insert('PRODUCTOS', producto);
  }

  Future<int> UPDATE(Map<String, dynamic> producto) async {
    final conexion = await AlacenaDB().database;

    return conexion.update(
      'PRODUCTOS',
      producto,
      where: 'id_producto = ?',
      whereArgs: [producto['id_producto']],
    );
  }

  Future<int> DELETE(int idProducto) async {
    final conexion = await AlacenaDB().database;



  final lotes = await conexion.query(
  'LOTES',
  where: 'producto_id = ?',
  whereArgs: [idProducto],
);

final historial = await conexion.query(
  'HISTORIAL_COMPRA',
  where: 'producto_id = ?',
  whereArgs: [idProducto],
);

final carrito = await conexion.query(
  'CARRITO',
  where: 'producto_id = ?',
  whereArgs: [idProducto],
);

print('Lotes relacionados: ${lotes.length}');
print('Compras relacionadas: ${historial.length}');
print('Registros en carrito: ${carrito.length}');
    return conexion.delete(
      'PRODUCTOS',
      where: 'id_producto = ?',
      whereArgs: [idProducto],
    );
  }

  Future<List<ProductosDAO>> SELECT() async {
    final conexion = await AlacenaDB().database;

    final resultado = await conexion.query(
      'PRODUCTOS',
      orderBy: 'nombre ASC',
    );
    
    return resultado
        .map((producto) => ProductosDAO.fromMap(producto))
        .toList();
  }
}