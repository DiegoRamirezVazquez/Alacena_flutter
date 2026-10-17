
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AlacenaDB {
  static final nameDB = "ALACENADB.db";
  static final versionDB = 2;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDataBase();
    return _database!;
  }

  Future<Database> _initDataBase() async {
    Directory folder = await getApplicationDocumentsDirectory();
    String pathDB = join(folder.path, nameDB);

    return openDatabase(
      pathDB,
      version: versionDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE HISTORIAL_COMPRA '
            'ADD COLUMN id_lote INTEGER REFERENCES LOTES(id_lote)',
          );
        }
      },
    );
  }

  Future<void> createTables(Database db, int version) async {

    // TABLA CATEGORIA
    await db.execute('''
      CREATE TABLE CATEGORIA (
        id_categoria INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
          CHECK(length(trim(nombre)) > 0),
        descripcion TEXT
      )
    ''');

    // TABLA TIENDA
    await db.execute('''
      CREATE TABLE TIENDA (
        id_tienda INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
          CHECK(length(trim(nombre)) > 0),
        direccion TEXT
      )
    ''');

    // TABLA PRODUCTOS
    await db.execute('''
      CREATE TABLE PRODUCTOS (
        id_producto INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
          CHECK(length(trim(nombre)) > 0),
        imagen TEXT,
        categoria_id INTEGER NOT NULL,
        stock_minimo INTEGER NOT NULL DEFAULT 1
          CHECK(stock_minimo >= 0),
        dias_alerta_caducidad INTEGER NOT NULL DEFAULT 5
          CHECK(dias_alerta_caducidad >= 0),
        ultima_tienda_id INTEGER,

        FOREIGN KEY (categoria_id)
          REFERENCES CATEGORIA(id_categoria),

        FOREIGN KEY (ultima_tienda_id)
          REFERENCES TIENDA(id_tienda)
      )
    ''');

    // TABLA LOTES
    await db.execute('''
      CREATE TABLE LOTES (
        id_lote INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL DEFAULT 0
          CHECK(cantidad >= 0),
        fecha_compra TEXT NOT NULL,
        fecha_caducidad TEXT NOT NULL,
        alarma_habilitada INTEGER NOT NULL DEFAULT 1
          CHECK(alarma_habilitada IN (0, 1)),

        FOREIGN KEY (producto_id)
          REFERENCES PRODUCTOS(id_producto),

        CHECK(fecha_caducidad >= fecha_compra)
      )
    ''');

    // TABLA HISTORIAL_COMPRA
    await db.execute('''
      CREATE TABLE HISTORIAL_COMPRA (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        tienda_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL
          CHECK(cantidad > 0),
        fecha_compra TEXT NOT NULL,
        id_lote INTEGER REFERENCES LOTES(id_lote),

        FOREIGN KEY (producto_id)
          REFERENCES PRODUCTOS(id_producto),

        FOREIGN KEY (tienda_id)
          REFERENCES TIENDA(id_tienda)
      )
    ''');

    // TABLA CARRITO
    await db.execute('''
      CREATE TABLE CARRITO (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL UNIQUE,
        cantidad INTEGER NOT NULL DEFAULT 1
          CHECK(cantidad > 0),
        fecha_agregado TEXT NOT NULL,

        FOREIGN KEY (producto_id)
          REFERENCES PRODUCTOS(id_producto)
      )
    ''');

    // ÍNDICES PARA AGILIZAR CONSULTAS
    await db.execute('''
      CREATE INDEX idx_lotes_producto_caducidad
      ON LOTES(producto_id, fecha_caducidad)
    ''');

    await db.execute('''
      CREATE INDEX idx_historial_producto
      ON HISTORIAL_COMPRA(producto_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_historial_tienda
      ON HISTORIAL_COMPRA(tienda_id)
    ''');

    // ACTUALIZAR LA ÚLTIMA TIENDA AL REGISTRAR UNA COMPRA
    await db.execute('''
      CREATE TRIGGER actualizar_ultima_tienda
      AFTER INSERT ON HISTORIAL_COMPRA
      BEGIN
        UPDATE PRODUCTOS
        SET ultima_tienda_id = NEW.tienda_id
        WHERE id_producto = NEW.producto_id;
      END
    ''');

    print("Base de datos ALACENADB creada correctamente");
  }
}
