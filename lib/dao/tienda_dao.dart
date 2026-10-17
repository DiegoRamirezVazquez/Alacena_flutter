import '../database/alacena_db.dart';

class TiendaDAO {
  int? id_tienda;
  String? nombre;
  String? direccion;

  TiendaDAO({
    this.id_tienda,
    this.nombre,
    this.direccion,
  });

  factory TiendaDAO.fromMap(Map<String, dynamic> tienda) {
    return TiendaDAO(
      id_tienda: tienda['id_tienda'] as int?,
      nombre: tienda['nombre'] as String?,
      direccion: tienda['direccion'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_tienda': id_tienda,
      'nombre': nombre,
      'direccion': direccion,
    };
  }
}

class TiendaDB {
  Future<int> INSERT(Map<String, dynamic> tienda) async {
    final conexion = await AlacenaDB().database;

    return conexion.insert('TIENDA', tienda);
  }

  Future<int> UPDATE(Map<String, dynamic> tienda) async {
    final conexion = await AlacenaDB().database;

    return conexion.update(
      'TIENDA',
      tienda,
      where: 'id_tienda = ?',
      whereArgs: [tienda['id_tienda']],
    );
  }

  Future<int> DELETE(int idTienda) async {
    final conexion = await AlacenaDB().database;

    return conexion.delete(
      'TIENDA',
      where: 'id_tienda = ?',
      whereArgs: [idTienda],
    );
  }

  Future<List<TiendaDAO>> SELECT() async {
    final conexion = await AlacenaDB().database;

    final resultado = await conexion.query(
      'TIENDA',
      orderBy: 'nombre ASC',
    );

    return resultado
        .map((tienda) => TiendaDAO.fromMap(tienda))
        .toList();
  }
}
