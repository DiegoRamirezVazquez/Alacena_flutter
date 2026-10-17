import 'package:flutter/material.dart';

/// Menú lateral compartido. Cada pantalla define qué ocurre al seleccionar
/// una opción, evitando importar pantallas aquí y crear dependencias circulares.
class MenuLateral extends StatelessWidget {
  final VoidCallback onInicio;
  final VoidCallback onProductos;
  final VoidCallback onCategorias;
  final VoidCallback onTiendas;
  final VoidCallback onLotes;
  final VoidCallback onAlacena;
  final VoidCallback onCalendario;
  final VoidCallback onCarrito;
  final VoidCallback onHistorial;

  const MenuLateral({
    super.key,
    required this.onInicio,
    required this.onProductos,
    required this.onCategorias,
    required this.onTiendas,
    required this.onLotes,
    required this.onAlacena,
    required this.onCalendario,
    required this.onCarrito,
    required this.onHistorial,
  });

  Widget _opcion({
    required IconData icono,
    required String texto,
    required VoidCallback accion,
  }) {
    return ListTile(
      leading: Icon(icono),
      title: Text(texto),
      onTap: accion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              color: const Color(0xFF397653),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.eco, size: 42, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Alacena Smart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Menú principal', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _opcion(icono: Icons.home_outlined, texto: 'Inicio', accion: onInicio),
                  const Divider(height: 1),
                  _opcion(icono: Icons.inventory_2_outlined, texto: 'Productos', accion: onProductos),
                  _opcion(icono: Icons.category_outlined, texto: 'Categorías', accion: onCategorias),
                  _opcion(icono: Icons.store_outlined, texto: 'Tiendas', accion: onTiendas),
                  _opcion(icono: Icons.inventory_outlined, texto: 'Lotes', accion: onLotes),
                  const Divider(height: 1),
                  _opcion(icono: Icons.kitchen_outlined, texto: 'Alacena', accion: onAlacena),
                  _opcion(icono: Icons.calendar_month_outlined, texto: 'Calendario', accion: onCalendario),
                  const Divider(height: 1),
                  _opcion(icono: Icons.shopping_cart_outlined, texto: 'Carrito de compras', accion: onCarrito),
                  _opcion(icono: Icons.receipt_long_outlined, texto: 'Historial de compras', accion: onHistorial),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
