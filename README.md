# Alacena Smart

**Aplicación móvil para administrar productos, organizar la alacena y gestionar las compras del hogar.**

Alacena Smart es una aplicación desarrollada con **Flutter y Dart** que permite llevar un control organizado de los productos almacenados en casa. Su objetivo es facilitar la administración del inventario, supervisar las fechas de caducidad, controlar las existencias y organizar las compras mediante una interfaz intuitiva y fácil de utilizar.

La aplicación utiliza una base de datos local SQLite para almacenar la información y ofrece distintas herramientas para mejorar la organización de los productos y reducir el desperdicio de alimentos.

## Funcionalidades principales

### Gestión de inventario
- Registro, consulta, edición y eliminación de productos.
- Organización de productos por categorías.
- Administración de tiendas.
- Control de lotes, cantidades y fechas de caducidad.
- Almacenamiento de imágenes de productos mediante rutas locales.
- Consulta de las existencias disponibles en la alacena.

### Control de caducidad y existencias
- Identificación de productos próximos a caducar.
- Alertas para productos con existencias bajas.
- Organización de los lotes mediante el criterio **FEFO** (*First Expired, First Out*), que prioriza el uso de los productos que caducan primero.

### Calendario
- Visualización de fechas relevantes relacionadas con la administración de la alacena.
- Consulta de eventos y fechas para facilitar la organización.

### Carrito e historial de compras
- Administración de los productos agregados al carrito.
- Visualización de la cantidad de productos mediante un contador.
- Compartir la lista de compras como imagen.
- Registro y consulta del historial de compras.

### Notificaciones
- Notificaciones para recordar situaciones relevantes relacionadas con el inventario.
- Consulta del historial de notificaciones.

### Interfaz y navegación
- Barra superior reutilizable con accesos al menú, notificaciones y carrito.
- Barra de navegación inferior para acceder a Inicio, Alacena y Calendario.
- Menú lateral con accesos a los diferentes módulos.
- Diseño basado en una paleta de colores verdes.
- Componentes reutilizables para mantener una interfaz uniforme y facilitar el mantenimiento del código.

## Tecnologías y herramientas

| Tecnología o paquete | Uso |
|---|---|
| Flutter | Desarrollo de la interfaz y de la aplicación. |
| Dart | Lenguaje de programación. |
| SQLite | Almacenamiento local de la información. |
| `sqflite` | Operaciones con la base de datos SQLite. |
| `path` | Manejo de rutas de archivos. |
| `table_calendar` | Implementación del calendario. |
| `badges` | Contador visual del carrito de compras. |
| `flutter_local_notifications` | Gestión de notificaciones locales. |
| `timezone` | Manejo de zonas horarias para las notificaciones programadas. |
| `flutter_slidable` | Acciones deslizables en elementos de las listas, donde se utilizan. |
| `fl_chart` | Creación de gráficas. |
| `path_provider` | Acceso a directorios del dispositivo. |
| `screenshot` | Captura de widgets como imágenes. |
| `share_plus` | Compartir archivos e imágenes desde la aplicación. |

## Base de datos

La aplicación utiliza una base de datos local SQLite organizada en seis tablas principales:

- **CATEGORIA:** almacena las categorías de los productos.
- **PRODUCTOS:** contiene la información de los productos registrados.
- **LOTES:** administra las cantidades y fechas de caducidad de los lotes.
- **TIENDA:** almacena la información de las tiendas.
- **HISTORIAL_COMPRA:** registra las compras realizadas.
- **CARRITO:** administra los productos agregados a la lista de compras.

Esta estructura permite relacionar la información y realizar operaciones de consulta, inserción, actualización y eliminación desde los diferentes módulos de la aplicación.

## Instalación y ejecución

### Requisitos previos

Antes de ejecutar el proyecto, es necesario contar con:

- [Flutter SDK](https://docs.flutter.dev/get-started/install).
- [Dart](https://dart.dev/get-dart), incluido con Flutter.
- [Git](https://git-scm.com/downloads).
- Un editor de código, como [Visual Studio Code](https://code.visualstudio.com/).
- Un emulador o dispositivo compatible con la plataforma de ejecución.

### 1. Clonar el repositorio

Abre una terminal y ejecuta:

```bash
git clone https://github.com/DiegoRamirezVazquez/Alacena_flutter.git
```

### 2. Entrar en el proyecto

```bash
cd Alacena_flutter
```

### 3. Instalar las dependencias

```bash
flutter pub get
```

### 4. Verificar la configuración de Flutter

```bash
flutter doctor
```

### 5. Ejecutar la aplicación

Con un emulador o dispositivo conectado, ejecuta:

```bash
flutter run
```

## Estructura general del proyecto

La organización de los archivos puede consultarse directamente en el repositorio. Entre los componentes desarrollados se encuentran las pantallas de los diferentes módulos, las clases de acceso a datos y los widgets compartidos para la navegación.

Los widgets reutilizables principales son:

- `AppBarComun`: barra superior con notificaciones y contador del carrito.
- `BarraNavegacion`: navegación inferior entre las secciones principales.
- `MenuLateral`: menú desplegable para acceder a los módulos de la aplicación.

## Objetivo del proyecto

Desarrollar una aplicación móvil que facilite el control del inventario doméstico mediante el registro de productos, el seguimiento de fechas de caducidad, la consulta de existencias y la organización de las compras. Asimismo, el proyecto permite aplicar conocimientos de desarrollo móvil con Flutter, persistencia de datos con SQLite, diseño de interfaces y programación de componentes reutilizables.

## Créditos

**Proyecto:** Alacena Smart  
**Repositorio:** [Alacena_flutter en GitHub](https://github.com/DiegoRamirezVazquez/Alacena_flutter)  
**Tecnologías principales:** Flutter, Dart y SQLite.

---

Desarrollado como proyecto académico de desarrollo de aplicaciones móviles.