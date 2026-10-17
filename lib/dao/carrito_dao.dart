import '../database/alacena_db.dart';

class CarritoDAO {
  int? id;
  int? producto_id;
  int? cantidad;
  String? fecha_agregado;

  CarritoDAO({
    this.id,
    this.producto_id,
    this.cantidad,
    this.fecha_agregado,
  });

  factory CarritoDAO.fromMap(Map<String, dynamic> carrito) {
    return CarritoDAO(
      id: carrito['id'] as int?,
      producto_id: carrito['producto_id'] as int?,
      cantidad: carrito['cantidad'] as int?,
      fecha_agregado: carrito['fecha_agregado'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': producto_id,
      'cantidad': cantidad,
      'fecha_agregado': fecha_agregado,
    };
  }
}

class CarritoDB {
  Future<int> INSERT(Map<String, dynamic> carrito) async {
    final conexion = await AlacenaDB().database;

    return conexion.insert('CARRITO', carrito);
  }

  Future<int> UPDATE(Map<String, dynamic> carrito) async {
    final conexion = await AlacenaDB().database;

    return conexion.update(
      'CARRITO',
      carrito,
      where: 'id = ?',
      whereArgs: [carrito['id']],
    );
  }

  Future<int> DELETE(int idCarrito) async {
    final conexion = await AlacenaDB().database;

    return conexion.delete(
      'CARRITO',
      where: 'id = ?',
      whereArgs: [idCarrito],
    );
  }

  Future<List<CarritoDAO>> SELECT() async {
    final conexion = await AlacenaDB().database;

    final resultado = await conexion.query(
      'CARRITO',
      orderBy: 'fecha_agregado DESC',
    );

    return resultado
        .map((producto) => CarritoDAO.fromMap(producto))
        .toList();
  }
}