
import '../database/alacena_db.dart';

// =====================================================
// MODELO: LOTESDAO
// =====================================================

class LotesDAO {
  int? id_lote;
  int? producto_id;
  int? cantidad;
  String? fecha_compra;
  String? fecha_caducidad;
  int? alarma_habilitada;

  // Datos del producto para mostrarlo en la pantalla.
  // No son columnas de LOTES; se obtienen mediante JOIN.
  String? nombre_producto;

  LotesDAO({
    this.id_lote,
    this.producto_id,
    this.cantidad,
    this.fecha_compra,
    this.fecha_caducidad,
    this.alarma_habilitada = 1,
    this.nombre_producto,
  });

  factory LotesDAO.fromMap(Map<String, dynamic> map) {
    return LotesDAO(
      id_lote: map['id_lote'] as int?,
      producto_id: map['producto_id'] as int?,
      cantidad: map['cantidad'] as int?,
      fecha_compra: map['fecha_compra'] as String?,
      fecha_caducidad: map['fecha_caducidad'] as String?,
      alarma_habilitada: map['alarma_habilitada'] as int?,
      nombre_producto: map['nombre_producto'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_lote': id_lote,
      'producto_id': producto_id,
      'cantidad': cantidad,
      'fecha_compra': fecha_compra,
      'fecha_caducidad': fecha_caducidad,
      'alarma_habilitada': alarma_habilitada,
    };
  }
}

// =====================================================
// ACCESO A LA BASE DE DATOS: LOTESDB
// =====================================================

class LotesDB {
  // Registrar un lote nuevo.
  Future<int> INSERT(Map<String, dynamic> lote) async {
    final db = await AlacenaDB().database;

    return await db.insert('LOTES', lote);
  }

  // Consultar todos los lotes con el nombre de su producto.
  Future<List<LotesDAO>> SELECT() async {
    final db = await AlacenaDB().database;

    final resultado = await db.rawQuery('''
      SELECT
        l.id_lote,
        l.producto_id,
        l.cantidad,
        l.fecha_compra,
        l.fecha_caducidad,
        l.alarma_habilitada,
        p.nombre AS nombre_producto
      FROM LOTES l
      INNER JOIN PRODUCTOS p
        ON l.producto_id = p.id_producto
      ORDER BY l.fecha_caducidad ASC
    ''');

    return resultado.map((fila) => LotesDAO.fromMap(fila)).toList();
  }

  // Consultar un lote por su ID.
  Future<LotesDAO?> SELECT_BY_ID(int idLote) async {
    final db = await AlacenaDB().database;

    final resultado = await db.rawQuery('''
      SELECT
        l.id_lote,
        l.producto_id,
        l.cantidad,
        l.fecha_compra,
        l.fecha_caducidad,
        l.alarma_habilitada,
        p.nombre AS nombre_producto
      FROM LOTES l
      INNER JOIN PRODUCTOS p
        ON l.producto_id = p.id_producto
      WHERE l.id_lote = ?
      LIMIT 1
    ''', [idLote]);

    if (resultado.isEmpty) return null;

    return LotesDAO.fromMap(resultado.first);
  }

  // Actualizar un lote existente.
 
  Future<int> UPDATE(Map<String, dynamic> lote) async {
    final db = await AlacenaDB().database;

    final datosActualizar = Map<String, dynamic>.from(lote);
    final idLote = datosActualizar.remove('id_lote');

    if (idLote == null) {
      throw Exception('No se recibió el identificador del lote.');
    }

    return await db.update(
      'LOTES',
      datosActualizar,
      where: 'id_lote = ?',
      whereArgs: [idLote],
    );
  }


  // Eliminar un lote.
  Future<int> DELETE(int idLote) async {
    final db = await AlacenaDB().database;

    return await db.delete(
      'LOTES',
      where: 'id_lote = ?',
      whereArgs: [idLote],
    );
  }

  // Consultar los productos disponibles para asociar un lote.
  Future<List<Map<String, dynamic>>> SELECT_PRODUCTOS() async {
    final db = await AlacenaDB().database;

    return await db.query(
      'PRODUCTOS',
      columns: ['id_producto', 'nombre'],
      orderBy: 'nombre ASC',
    );
  }

  Future<List<Map<String, dynamic>>> SELECT_INVENTARIO() async {
    final db = await AlacenaDB().database;

    return await db.rawQuery('''
      SELECT
        p.id_producto,
        p.nombre AS nombre_producto,
        p.imagen,
        p.categoria_id,
        c.nombre AS nombre_categoria,
        p.stock_minimo,
        COALESCE(SUM(l.cantidad), 0) AS cantidad_total,
        COUNT(l.id_lote) AS total_lotes
      FROM PRODUCTOS p
      INNER JOIN CATEGORIA c
        ON p.categoria_id = c.id_categoria
      LEFT JOIN LOTES l
        ON p.id_producto = l.producto_id
      GROUP BY
        p.id_producto,
        p.nombre,
        p.imagen,
        p.categoria_id,
        c.nombre,
        p.stock_minimo
      ORDER BY p.nombre COLLATE NOCASE ASC
    ''');
  }
}
