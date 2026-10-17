import '../database/alacena_db.dart';

class HistorialCompraDAO {
  int? id;
  int? producto_id;
  int? tienda_id;
  int? cantidad;
  String? fecha_compra;
  int? id_lote;

  // Datos complementarios obtenidos mediante SELECT con JOIN.
  String? nombre_producto;
  String? nombre_tienda;
  String? fecha_caducidad;
  int? alarma_habilitada;

  HistorialCompraDAO({
    this.id,
    this.producto_id,
    this.tienda_id,
    this.cantidad,
    this.fecha_compra,
    this.id_lote,
    this.nombre_producto,
    this.nombre_tienda,
    this.fecha_caducidad,
    this.alarma_habilitada,
  });

  factory HistorialCompraDAO.fromMap(Map<String, dynamic> compra) {
    return HistorialCompraDAO(
      id: compra['id'] as int?,
      producto_id: compra['producto_id'] as int?,
      tienda_id: compra['tienda_id'] as int?,
      cantidad: compra['cantidad'] as int?,
      fecha_compra: compra['fecha_compra'] as String?,
      id_lote: compra['id_lote'] as int?,
      nombre_producto: compra['nombre_producto'] as String?,
      nombre_tienda: compra['nombre_tienda'] as String?,
      fecha_caducidad: compra['fecha_caducidad'] as String?,
      alarma_habilitada: compra['alarma_habilitada'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': producto_id,
      'tienda_id': tienda_id,
      'cantidad': cantidad,
      'fecha_compra': fecha_compra,
      'id_lote': id_lote,
    };
  }
}

class HistorialCompraDB {
  /// Registra el lote y el historial dentro de una sola transacción.
  /// Si alguna operación falla, SQLite revierte ambas.
  Future<int> REGISTRAR_COMPRA({
    required int productoId,
    required int tiendaId,
    required int cantidad,
    required String fechaCompra,
    required String fechaCaducidad,
    int alarmaHabilitada = 1,
  }) async {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor que cero.');
    }

    if (fechaCaducidad.compareTo(fechaCompra) < 0) {
      throw ArgumentError(
        'La fecha de caducidad no puede ser anterior a la fecha de compra.',
      );
    }

    if (alarmaHabilitada != 0 && alarmaHabilitada != 1) {
      throw ArgumentError('El valor de la alarma debe ser 0 o 1.');
    }

    final conexion = await AlacenaDB().database;

    return conexion.transaction((txn) async {
      final idLote = await txn.insert('LOTES', {
        'producto_id': productoId,
        'cantidad': cantidad,
        'fecha_compra': fechaCompra,
        'fecha_caducidad': fechaCaducidad,
        'alarma_habilitada': alarmaHabilitada,
      });

      final idHistorial = await txn.insert('HISTORIAL_COMPRA', {
        'producto_id': productoId,
        'tienda_id': tiendaId,
        'cantidad': cantidad,
        'fecha_compra': fechaCompra,
        'id_lote': idLote,
      });

      // El trigger actualizar_ultima_tienda de tu base de datos
      // se encarga de actualizar PRODUCTOS.ultima_tienda_id.
      return idHistorial;
    });
  }

  /// Consulta el historial y muestra también los datos del lote.
  /// Los registros anteriores sin id_lote siguen apareciendo.
  Future<List<HistorialCompraDAO>> SELECT() async {
    final conexion = await AlacenaDB().database;

    final resultado = await conexion.rawQuery('''
      SELECT
        h.id,
        h.producto_id,
        h.tienda_id,
        h.cantidad,
        h.fecha_compra,
        h.id_lote,
        p.nombre AS nombre_producto,
        t.nombre AS nombre_tienda,
        l.fecha_caducidad AS fecha_caducidad,
        l.alarma_habilitada AS alarma_habilitada
      FROM HISTORIAL_COMPRA h
      INNER JOIN PRODUCTOS p
        ON p.id_producto = h.producto_id
      INNER JOIN TIENDA t
        ON t.id_tienda = h.tienda_id
      LEFT JOIN LOTES l
        ON l.id_lote = h.id_lote
      ORDER BY h.fecha_compra DESC, h.id DESC
    ''');

    return resultado
        .map((compra) => HistorialCompraDAO.fromMap(compra))
        .toList();
  }

  /// Actualiza una compra y su lote relacionado.
  /// No permite modificar automáticamente registros antiguos sin lote.
  Future<int> ACTUALIZAR_COMPRA({
    required int id,
    required int idLote,
    required int productoId,
    required int tiendaId,
    required int cantidad,
    required String fechaCompra,
    required String fechaCaducidad,
    required int alarmaHabilitada,
  }) async {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor que cero.');
    }

    if (fechaCaducidad.compareTo(fechaCompra) < 0) {
      throw ArgumentError(
        'La fecha de caducidad no puede ser anterior a la fecha de compra.',
      );
    }

    if (alarmaHabilitada != 0 && alarmaHabilitada != 1) {
      throw ArgumentError('El valor de la alarma debe ser 0 o 1.');
    }

    final conexion = await AlacenaDB().database;

    return conexion.transaction((txn) async {
      final registros = await txn.query(
        'HISTORIAL_COMPRA',
        columns: ['producto_id', 'id_lote'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (registros.isEmpty) {
        throw StateError('La compra que intentas editar no existe.');
      }

      final registroAnterior = registros.first;
      final loteRelacionado = registroAnterior['id_lote'];

      if (loteRelacionado == null || loteRelacionado != idLote) {
        throw StateError(
          'Esta compra no tiene un lote relacionado válido. '
          'No se modificó ningún registro.',
        );
      }

      final productoAnterior = registroAnterior['producto_id'] as int;

      final filasLote = await txn.update(
        'LOTES',
        {
          'producto_id': productoId,
          'cantidad': cantidad,
          'fecha_compra': fechaCompra,
          'fecha_caducidad': fechaCaducidad,
          'alarma_habilitada': alarmaHabilitada,
        },
        where: 'id_lote = ?',
        whereArgs: [idLote],
      );

      if (filasLote == 0) {
        throw StateError('No se encontró el lote relacionado.');
      }

      final filasHistorial = await txn.update(
        'HISTORIAL_COMPRA',
        {
          'producto_id': productoId,
          'tienda_id': tiendaId,
          'cantidad': cantidad,
          'fecha_compra': fechaCompra,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Recalcula la última tienda de los productos afectados.
      await _actualizarUltimaTienda(txn, productoAnterior);
      if (productoId != productoAnterior) {
        await _actualizarUltimaTienda(txn, productoId);
      }

      return filasHistorial;
    });
  }

  Future<void> _actualizarUltimaTienda(
    dynamic txn,
    int productoId,
  ) async {
    final ultimaCompra = await txn.query(
      'HISTORIAL_COMPRA',
      columns: ['tienda_id'],
      where: 'producto_id = ?',
      whereArgs: [productoId],
      orderBy: 'fecha_compra DESC, id DESC',
      limit: 1,
    );

    final int? ultimaTienda = ultimaCompra.isEmpty
        ? null
        : ultimaCompra.first['tienda_id'] as int?;

    await txn.update(
      'PRODUCTOS',
      {'ultima_tienda_id': ultimaTienda},
      where: 'id_producto = ?',
      whereArgs: [productoId],
    );
  }

  /// Se conservan estos métodos para no quitar operaciones existentes.
  /// La pantalla de historial no debe ofrecer una opción para eliminar.
  Future<int> INSERT(Map<String, dynamic> compra) async {
    final conexion = await AlacenaDB().database;
    return conexion.insert('HISTORIAL_COMPRA', compra);
  }

  Future<int> UPDATE(Map<String, dynamic> compra) async {
    final conexion = await AlacenaDB().database;
    return conexion.update(
      'HISTORIAL_COMPRA',
      compra,
      where: 'id = ?',
      whereArgs: [compra['id']],
    );
  }

  Future<int> DELETE(int idCompra) async {
    final conexion = await AlacenaDB().database;
    return conexion.delete(
      'HISTORIAL_COMPRA',
      where: 'id = ?',
      whereArgs: [idCompra],
    );
  }
}
