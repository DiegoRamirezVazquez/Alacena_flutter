
import 'package:alacena_practica/database/alacena_db.dart';


class CategoriaDAO {
  int? id_categoria;
  String? nombre;
  String? descripcion;

  CategoriaDAO({
    this.id_categoria,
    this.nombre,
    this.descripcion,
  });

  factory CategoriaDAO.fromMap(Map<String, dynamic> categoria) {
    return CategoriaDAO(
      id_categoria: categoria['id_categoria'] as int?,
      nombre: categoria['nombre'] as String?,
      descripcion: categoria['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_categoria': id_categoria,
      'nombre': nombre,
      'descripcion': descripcion,
    };
  }
}

class CategoriaDB {
  Future<int> INSERT(Map<String, dynamic> categoria) async {
    final conexion = await AlacenaDB().database;
    return conexion.insert('CATEGORIA', categoria);
  }

  Future<int> UPDATE(Map<String, dynamic> categoria) async {
    final conexion = await AlacenaDB().database;

    return conexion.update(
      'CATEGORIA',
      categoria,
      where: 'id_categoria = ?',
      whereArgs: [categoria['id_categoria']],
    );
  }

  Future<int> DELETE(int idCategoria) async {
    final conexion = await AlacenaDB().database;

    return conexion.delete(
      'CATEGORIA',
      where: 'id_categoria = ?',
      whereArgs: [idCategoria],
    );
  }

  Future<List<CategoriaDAO>> SELECT() async {
    final conexion = await AlacenaDB().database;
    final res = await conexion.query(
      'CATEGORIA',
      orderBy: 'nombre ASC',
    );

    return res.map((categoria) =>
        CategoriaDAO.fromMap(categoria)).toList();
  }
}
