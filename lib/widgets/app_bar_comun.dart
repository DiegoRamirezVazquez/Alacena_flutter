import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

/// Barra superior compartida de Alacena Smart.
/// El contador y las acciones se reciben desde cada pantalla.
class AppBarComun extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenu;
  final VoidCallback onNotificaciones;
  final VoidCallback onCarrito;
  final int cantidadCarrito;

  const AppBarComun({
    super.key,
    required this.onMenu,
    required this.onNotificaciones,
    required this.onCarrito,
    required this.cantidadCarrito,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Abrir menú',
        onPressed: onMenu,
        icon: const Icon(Icons.menu, color: Color(0xFF234B35)),
      ),
      title: const Row(
        children: [
          Icon(Icons.eco, color: Color(0xFF397653), size: 28),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Alacena Smart',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: onNotificaciones,
          icon: const Icon(Icons.notifications_none),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: badges.Badge(
            position: badges.BadgePosition.topEnd(top: 2, end: 2),
            showBadge: cantidadCarrito > 0,
            badgeStyle: const badges.BadgeStyle(
              badgeColor: Color(0xFFB42318),
              padding: EdgeInsets.all(5),
            ),
            badgeContent: Text(
              cantidadCarrito > 99 ? '99+' : '$cantidadCarrito',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: IconButton(
              tooltip: 'Carrito de compras',
              onPressed: onCarrito,
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ),
      ],
    );
  }
}
