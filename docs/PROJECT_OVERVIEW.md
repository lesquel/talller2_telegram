# 🍽️ MesaYA - Documentación Completa del Proyecto

> **Plataforma de Reservas de Restaurantes**  
> Sistema de microservicios para gestión de restaurantes, reservas y experiencia gastronómica

---

## 📋 Tabla de Contenidos

1. [¿Qué es MesaYA?](#-qué-es-mesaya)
2. [El Problema que Resuelve](#-el-problema-que-resuelve)
3. [Arquitectura General](#-arquitectura-general)
4. [Los Microservicios](#-los-microservicios)
5. [Tecnologías Utilizadas](#-tecnologías-utilizadas)
6. [Flujo de Datos](#-flujo-de-datos)
7. [Tipos de Usuarios](#-tipos-de-usuarios)
8. [Funcionalidades Principales](#-funcionalidades-principales)
9. [Cómo Ejecutar el Proyecto](#-cómo-ejecutar-el-proyecto)
10. [Equipo de Desarrollo](#-equipo-de-desarrollo)

---

## 🎯 ¿Qué es MesaYA?

**MesaYA** es una plataforma web completa para restaurantes que permite:

- 📍 Mostrar la **ubicación** del restaurante en un mapa
- 📖 Publicar un **menú digital** con fotos y precios
- ⏰ Definir **horarios de atención**
- 📅 Ver la **disponibilidad de mesas** en tiempo real
- ✅ **Reservar mesas online** con confirmación automática

Piensa en MesaYA como un "Airbnb para reservas de restaurantes" - los restaurantes crean su perfil, configuran sus mesas y secciones, y los clientes pueden buscar, explorar y reservar desde su celular.

---

## 🔍 El Problema que Resuelve

| Problema                                     | Solución MesaYA                                                    |
| -------------------------------------------- | ------------------------------------------------------------------ |
| Restaurantes pequeños sin presencia digital  | Perfil completo con menú, fotos, ubicación y horarios              |
| Turistas no saben qué restaurantes existen   | Buscador con filtros por ubicación, tipo de cocina, disponibilidad |
| Dueños pierden reservas por falta de sistema | Sistema de reservas organizado con calendario visual               |
| Gestión manual de mesas                      | Visualización en tiempo real de mesas disponibles/ocupadas         |
| Comunicación ineficiente con clientes        | Chatbot con IA para atención automatizada                          |

---

## 🏗️ Arquitectura General

MesaYA utiliza una **arquitectura de microservicios** donde cada componente tiene una responsabilidad específica:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              👤 USUARIOS                                     │
│                    (Clientes, Dueños, Administradores)                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        🎨 FRONTEND (Angular)                                 │
│                     Aplicación Web/Móvil (PWA)                               │
│      • Páginas públicas • Panel de dueño • Panel de admin • Chatbot         │
└─────────────────────────────────────────────────────────────────────────────┘
                    │              │              │              │
         HTTP/JSON  │    GraphQL   │   WebSocket  │    HTTP      │
                    ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  🔧 Backend  │ │ 📊 GraphQL   │ │ 🔌 WebSocket │ │ 🤖 Chatbot   │
│   (NestJS)   │ │ (Strawberry) │ │    (Go)      │ │  (FastAPI)   │
│              │ │              │ │              │ │              │
│  REST API    │ │  Consultas   │ │  Tiempo Real │ │    IA con    │
│  Principal   │ │  Optimizadas │ │  Actualizac. │ │    Groq      │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
         │              │              │              │
         └──────────────┼──────────────┼──────────────┘
                        │              │
                        ▼              ▼
              ┌──────────────┐ ┌──────────────┐
              │  🔐 Auth MS  │ │  📨 Kafka    │
              │   (NestJS)   │ │  (Mensajes)  │
              │              │ │              │
              │ Autenticación│ │  Eventos     │
              │ Autorización │ │  Asíncronos  │
              └──────────────┘ └──────────────┘
                        │              │
                        └──────┬───────┘
                               ▼
                      ┌──────────────┐
                      │ 🗄️ PostgreSQL│
                      │   (Base de   │
                      │    Datos)    │
                      └──────────────┘
```

### 🔗 Componente Extra: MCP Server

```
┌──────────────────────────────────────────────────────────────┐
│                    🤖 AGENTES DE IA                           │
│              (Claude, ChatGPT, otros LLMs)                    │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    🔧 MCP Server (FastMCP)                    │
│                                                               │
│  Expone herramientas para que los agentes de IA puedan:       │
│  • Buscar restaurantes     • Gestionar reservas               │
│  • Consultar menús         • Ver información de usuarios      │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
                      Backend REST API
```

---

## 🔧 Los Microservicios

### 1. 🔧 Backend Principal (`mesa-ya-res`) - NestJS/TypeScript

**Puerto:** 3000

El corazón del sistema. Maneja toda la lógica de negocio principal:

| Módulo         | Descripción                                        |
| -------------- | -------------------------------------------------- |
| `auth`         | Integración con microservicio de autenticación     |
| `restaurants`  | CRUD de restaurantes, horarios, estados            |
| `sections`     | Áreas del restaurante (primer piso, terraza, etc.) |
| `tables`       | Mesas dentro de cada sección                       |
| `objects`      | Mobiliario y decoración (sillas, plantas, etc.)    |
| `menus`        | Menús y platos con precios e imágenes              |
| `reservation`  | Sistema completo de reservas                       |
| `reviews`      | Reseñas y calificaciones                           |
| `payment`      | Procesamiento de pagos                             |
| `subscription` | Planes de suscripción para restaurantes            |
| `images`       | Gestión de imágenes (Supabase Storage)             |
| `chatbot`      | Proxy al servicio de chatbot                       |

**Arquitectura interna:** Clean Architecture + Domain-Driven Design

```
features/
├── restaurants/
│   ├── domain/           # Entidades puras (sin dependencias)
│   ├── application/      # Casos de uso, puertos (interfaces)
│   ├── infrastructure/   # Repositorios, adaptadores externos
│   └── interface/        # Controladores REST, DTOs
```

---

### 2. 🔐 Auth Microservice (`mesaYA_auth_ms`) - NestJS/TypeScript

**Puerto:** 3001 (Kafka)

Microservicio dedicado exclusivamente a autenticación y autorización:

| Funcionalidad        | Descripción                                |
| -------------------- | ------------------------------------------ |
| **Sign Up**          | Registro de nuevos usuarios                |
| **Login**            | Inicio de sesión con JWT RS256             |
| **Refresh Token**    | Renovación de tokens                       |
| **Logout**           | Cierre de sesión                           |
| **Roles y Permisos** | USER, OWNER, ADMIN con permisos granulares |

**Comunicación:** Request/Reply a través de Apache Kafka

```
Frontend → Backend REST → Kafka → Auth MS → Kafka → Backend REST → Frontend
```

**Seguridad:**

- Passwords hasheados con BCrypt
- JWT firmados con RS256 (clave pública/privada)
- Refresh tokens almacenados en base de datos

---

### 3. 📊 GraphQL Service (`mesaYA_graphql`) - Python/Strawberry

**Puerto:** 8001

API GraphQL de **solo lectura** para consultas optimizadas:

```graphql
# Ejemplo de consulta
query {
  restaurants(city: "Manta", limit: 10) {
    id
    name
    rating
    sections {
      name
      tables {
        number
        capacity
        isAvailable
      }
    }
  }
}
```

| Ventaja            | Descripción                                        |
| ------------------ | -------------------------------------------------- |
| **Eficiencia**     | El cliente pide exactamente los datos que necesita |
| **Menos requests** | Una sola petición para datos relacionados          |
| **Tipado fuerte**  | Schema GraphQL bien definido                       |

**Queries disponibles:**

- Restaurantes, secciones, mesas
- Menús, platos
- Reservas, pagos
- Analytics y reportes
- Reseñas, suscripciones

---

### 4. 🔌 WebSocket Service (`mesa-ya-ws`) - Go/Echo

**Puerto:** 8080

Actualizaciones en **tiempo real** para dashboards y visualizaciones:

| Endpoint                       | Descripción                           |
| ------------------------------ | ------------------------------------- |
| `/ws/section/:section`         | Cambios en secciones (mesas, objetos) |
| `/ws/analytics/:scope/:entity` | Dashboards de analytics en vivo       |

**Características:**

- Conexiones persistentes WebSocket
- Suscripción a topics específicos
- Caché de snapshots para eficiencia
- Integración con Kafka para eventos

**Ejemplo de uso:**

```javascript
// Conectar al WebSocket de una sección
const ws = new WebSocket("ws://localhost:8080/ws/section/section-123");
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // Actualizar UI en tiempo real
};
```

---

### 5. 🤖 Chatbot Service (`mesaYA_chatbot_service`) - Python/FastAPI

**Puerto:** 8002

Asistente de IA para atención al cliente:

| Capacidad            | Descripción                                   |
| -------------------- | --------------------------------------------- |
| **FAQ**              | Responde preguntas frecuentes                 |
| **Búsqueda**         | Busca restaurantes por criterios              |
| **Información**      | Da detalles de restaurantes específicos       |
| **Contexto por rol** | Respuestas diferentes para clientes vs dueños |

**Tecnología:**

- LangChain para orquestación
- Groq (Llama 3) como LLM
- Diseño stateless (sin memoria de conversación)

```
Usuario: "¿Qué restaurantes de comida italiana hay en Manta?"
    ↓
Chatbot detecta intención: SEARCH_RESTAURANTS
    ↓
Consulta al Backend REST
    ↓
LLM formatea respuesta amigable
    ↓
"Encontré 3 restaurantes italianos en Manta:
 1. La Trattoria - Rating 4.5⭐
 2. Pasta & Vino - Rating 4.2⭐
 ..."
```

---

### 6. 🔧 MCP Server (`mesaYA_mcp`) - Python/FastMCP

**Puerto:** Variable (stdio/SSE)

Servidor MCP (Model Context Protocol) para integración con agentes de IA:

**¿Qué es MCP?**
Es un protocolo estándar para que los LLMs (como Claude) puedan interactuar con sistemas externos de forma segura y estructurada.

**Herramientas disponibles (25+):**

| Categoría        | Herramientas                                                                                 |
| ---------------- | -------------------------------------------------------------------------------------------- |
| **Restaurantes** | `search_restaurants`, `get_restaurant_info`, `get_restaurant_menu`, `get_nearby_restaurants` |
| **Reservas**     | `create_reservation`, `get_reservation`, `cancel_reservation`, `confirm_reservation`         |
| **Menús**        | `get_menu`, `search_dishes`, `get_dish`                                                      |
| **Usuarios**     | `get_user`, `list_users`, `get_user_analytics`                                               |

**Niveles de acceso:**

- `public` - Sin autenticación
- `authenticated` - Usuario logueado
- `owner` - Dueño de restaurante
- `admin` - Administrador del sistema

---

### 7. 🎨 Frontend (`mesaYa_frontend`) - Angular

**Puerto:** 4200

Aplicación web progresiva (PWA) con:

| Feature          | Descripción                           |
| ---------------- | ------------------------------------- |
| **Home**         | Página de inicio con búsqueda         |
| **Restaurantes** | Listado, búsqueda, filtros, detalle   |
| **Reservas**     | Flujo completo de reserva             |
| **Panel Owner**  | Dashboard para dueños de restaurantes |
| **Panel Admin**  | Gestión administrativa del sistema    |
| **Chatbot**      | Interfaz de chat integrada            |
| **i18n**         | Internacionalización (español/inglés) |

**Tecnologías:**

- Angular 17+ con Signals
- Tailwind CSS para estilos
- RxJS para estado reactivo
- Clean Architecture por features

---

### 8. 📨 Apache Kafka

**Puertos:** 9092, 29092

Sistema de mensajería para comunicación entre microservicios:

**Topics de eventos:**

```
mesa-ya.restaurants.events    # Cambios en restaurantes
mesa-ya.sections.events       # Cambios en secciones
mesa-ya.tables.events         # Cambios en mesas
mesa-ya.reservations.events   # Cambios en reservas
mesa-ya.payments.events       # Eventos de pago
mesa-ya.auth.events           # Eventos de autenticación
...
```

**Topics de Auth (Request/Reply):**

```
auth.sign-up          →  auth.sign-up.reply
auth.login            →  auth.login.reply
auth.refresh-token    →  auth.refresh-token.reply
```

---

## 💻 Tecnologías Utilizadas

### Por Servicio

| Servicio     | Lenguaje    | Framework            | Base de Datos    |
| ------------ | ----------- | -------------------- | ---------------- |
| Backend REST | TypeScript  | NestJS               | PostgreSQL       |
| Auth MS      | TypeScript  | NestJS               | PostgreSQL       |
| GraphQL      | Python 3.13 | Strawberry + FastAPI | - (consume REST) |
| WebSocket    | Go          | Echo + Gorilla       | Redis (caché)    |
| Chatbot      | Python 3.12 | FastAPI + LangChain  | -                |
| MCP Server   | Python 3.12 | FastMCP              | - (consume REST) |
| Frontend     | TypeScript  | Angular 17           | -                |

### Infraestructura

| Componente     | Tecnología                |
| -------------- | ------------------------- |
| Mensajería     | Apache Kafka (KRaft mode) |
| Base de datos  | PostgreSQL                |
| Almacenamiento | Supabase Storage          |
| Contenedores   | Docker + Docker Compose   |
| Pagos          | Stripe                    |
| Mapas          | Google Maps API           |

### Patrones Arquitectónicos

- **Clean Architecture** - Separación de capas (domain, application, infrastructure, interface)
- **Domain-Driven Design** - Modelado basado en el dominio del negocio
- **Hexagonal Architecture** - Puertos y adaptadores
- **Event-Driven Architecture** - Comunicación por eventos via Kafka
- **CQRS (parcial)** - Separación de lecturas (GraphQL) y escrituras (REST)

---

## 🔄 Flujo de Datos

### Flujo de una Reserva

```
1. Usuario abre la app
   │
   ▼
2. Frontend carga restaurantes (GraphQL)
   │
   ▼
3. Usuario selecciona restaurante
   │
   ▼
4. WebSocket conecta para ver disponibilidad en tiempo real
   │
   ▼
5. Usuario selecciona mesa, fecha y hora
   │
   ▼
6. Frontend envía reserva (REST API)
   │
   ▼
7. Backend valida disponibilidad
   │
   ▼
8. Backend crea reserva en PostgreSQL
   │
   ▼
9. Kafka publica evento "reservation.created"
   │
   ▼
10. WebSocket notifica cambio a todos los clientes conectados
    │
    ▼
11. Usuario recibe confirmación
```

### Flujo de Autenticación

```
1. Usuario ingresa credenciales en Frontend
   │
   ▼
2. Frontend → POST /auth/login → Backend REST
   │
   ▼
3. Backend → Kafka topic "auth.login"
   │
   ▼
4. Auth MS recibe mensaje, valida credenciales
   │
   ▼
5. Auth MS genera JWT (RS256) + Refresh Token
   │
   ▼
6. Auth MS → Kafka topic "auth.login.reply"
   │
   ▼
7. Backend recibe respuesta
   │
   ▼
8. Backend → JWT al Frontend
   │
   ▼
9. Frontend almacena token, redirige a área autenticada
```

---

## 👤 Tipos de Usuarios

### 1. Cliente (USER)

**¿Quién es?** Persona que busca restaurantes y hace reservas.

**Puede hacer:**

- ✅ Buscar y explorar restaurantes
- ✅ Ver menús, fotos, horarios
- ✅ Hacer reservas
- ✅ Dejar reseñas
- ✅ Ver historial de reservas
- ✅ Chatear con el asistente IA

### 2. Dueño de Restaurante (OWNER)

**¿Quién es?** Propietario o administrador de un restaurante.

**Puede hacer:**

- ✅ Todo lo que puede hacer un USER
- ✅ Crear y editar su restaurante
- ✅ Configurar secciones y mesas
- ✅ Gestionar menú y platos
- ✅ Ver y gestionar reservas
- ✅ Ver dashboard de analytics
- ✅ Responder reseñas

### 3. Administrador (ADMIN)

**¿Quién es?** Administrador del sistema MesaYA.

**Puede hacer:**

- ✅ Todo lo anterior
- ✅ Gestionar todos los restaurantes
- ✅ Gestionar todos los usuarios
- ✅ Aprobar solicitudes de upgrade a OWNER
- ✅ Ver analytics globales
- ✅ Moderar reseñas
- ✅ Gestionar planes de suscripción

---

## ⭐ Funcionalidades Principales

### Para Clientes

| Funcionalidad       | Descripción                                        |
| ------------------- | -------------------------------------------------- |
| 🔍 **Búsqueda**     | Por nombre, ciudad, tipo de cocina, disponibilidad |
| 🗺️ **Mapa**         | Ver restaurantes en el mapa con Google Maps        |
| 📖 **Menú Digital** | Ver platos con fotos, precios y descripciones      |
| 📅 **Reservas**     | Seleccionar mesa, fecha, hora y número de personas |
| ⭐ **Reseñas**      | Leer y escribir opiniones                          |
| 🤖 **Chatbot**      | Asistente IA para dudas y búsquedas                |

### Para Dueños

| Funcionalidad         | Descripción                                       |
| --------------------- | ------------------------------------------------- |
| 🏪 **Perfil**         | Crear y personalizar perfil del restaurante       |
| 🪑 **Secciones**      | Configurar áreas (terraza, interior, VIP)         |
| 🍽️ **Mesas**          | Agregar mesas con capacidad y ubicación visual    |
| 📋 **Menú**           | Gestionar platos, categorías y precios            |
| 📊 **Dashboard**      | Ver estadísticas de reservas, ingresos, ocupación |
| 🔔 **Notificaciones** | Alertas de nuevas reservas en tiempo real         |

### Para Administradores

| Funcionalidad        | Descripción                             |
| -------------------- | --------------------------------------- |
| 👥 **Usuarios**      | Gestionar cuentas y roles               |
| 🏪 **Restaurantes**  | Supervisar y moderar                    |
| 📈 **Analytics**     | Métricas globales de la plataforma      |
| 💼 **Suscripciones** | Gestionar planes y pagos                |
| ✅ **Aprobaciones**  | Aprobar/rechazar solicitudes de upgrade |

---

## 🚀 Cómo Ejecutar el Proyecto

### Requisitos Previos

- **Docker Desktop** - Para Kafka y bases de datos
- **Node.js 20+** - Para servicios NestJS y Angular
- **Python 3.12+** - Para servicios Python
- **Go 1.21+** - Para servicio WebSocket
- **uv** (opcional) - Gestor de paquetes Python moderno

### Opción 1: Ejecutar Todo con VS Code Tasks

El proyecto incluye tareas predefinidas. Presiona `Ctrl+Shift+P` → "Tasks: Run Task":

1. **🐳 Kafka (Docker)** - Inicia Kafka
2. **🔐 Auth Microservice** - Inicia servicio de autenticación
3. **🔧 Backend** - Inicia API REST principal
4. **📊 GraphQL** - Inicia servicio GraphQL
5. **🔌 WebSocket** - Inicia servicio tiempo real
6. **🤖 Chatbot** - Inicia servicio de chatbot
7. **🎨 Frontend** - Inicia aplicación Angular

O ejecuta **🚀 Iniciar TODOS los servicios** para levantar todo en paralelo.

### Opción 2: Ejecutar Manualmente

```bash
# 1. Iniciar infraestructura (Kafka)
cd mesaYa
docker compose up -d

# 2. Iniciar Auth Microservice
cd mesaYA_auth_ms
npm install
npm run start:dev

# 3. Iniciar Backend REST
cd mesa-ya-res
npm install
npm run start:dev

# 4. Iniciar GraphQL
cd mesaYA_graphql
uv run app

# 5. Iniciar WebSocket
cd mesa-ya-ws
go run ./cmd/server/main.go

# 6. Iniciar Chatbot
cd mesaYA_chatbot_service
uv run app

# 7. Iniciar Frontend
cd mesaYa_frontend
npm install
ng serve
```

### URLs de Desarrollo

| Servicio           | URL                           |
| ------------------ | ----------------------------- |
| Frontend           | http://localhost:4200         |
| Backend REST       | http://localhost:3000         |
| Swagger Docs       | http://localhost:3000/api     |
| GraphQL Playground | http://localhost:8001/graphql |
| WebSocket          | ws://localhost:8080           |
| Chatbot            | http://localhost:8002         |

---

## 👥 Equipo de Desarrollo

| Nombre                        | GitHub                                         | LinkedIn                                           |
| ----------------------------- | ---------------------------------------------- | -------------------------------------------------- |
| Menoscal Santana Bryan Steven | [@stevsant](https://github.com/stevsant)       | [LinkedIn](http://linkedin.com/in/bryanmenoscal26) |
| Muñiz Rivas Miquel Leopoldo   | [@lesquel](https://github.com/lesquel)         | -                                                  |
| Perez Chiquito Ginger Geomara | [@GINGERPEREZ](https://github.com/GINGERPEREZ) | -                                                  |

---

## 📚 Documentación Adicional

| Documento              | Ubicación                                                                                     |
| ---------------------- | --------------------------------------------------------------------------------------------- |
| SRS (Requerimientos)   | [docs/srs.md](./srs.md)                                                                       |
| Diagrama C4 Contexto   | [docs/c4/c4_context.md](./c4/c4_context.md)                                                   |
| Diagrama C4 Contenedor | [docs/c4/c4_container.md](./c4/c4_container.md)                                               |
| Diagrama ER            | [docs/er_diagram.md](./er_diagram.md)                                                         |
| API REST Docs          | [mesa-ya-res/docs/API_DOCUMENTATION.md](../mesa-ya-res/docs/API_DOCUMENTATION.md)             |
| Arquitectura Backend   | [mesa-ya-res/docs/ARCHITECTURE.md](../mesa-ya-res/docs/ARCHITECTURE.md)                       |
| Guía WebSocket         | [mesa-ya-ws/docs/REALTIME_WEBSOCKET_GUIDE.md](../mesa-ya-ws/docs/REALTIME_WEBSOCKET_GUIDE.md) |
| MCP Tools Reference    | [mesaYA_mcp/docs/MCP_TOOLS_REFERENCE.md](../mesaYA_mcp/docs/MCP_TOOLS_REFERENCE.md)           |

---

## 📝 Resumen Visual

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          🍽️ MesaYA Platform                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐     ┌──────────────────────────────────────────────┐      │
│   │  👤 User │────▶│              🎨 Angular Frontend              │      │
│   └──────────┘     │         (Web App + PWA + i18n)               │      │
│                    └──────────────────────────────────────────────┘      │
│                           │         │         │         │                │
│                    HTTP   │ GraphQL │   WS    │   HTTP  │                │
│                           ▼         ▼         ▼         ▼                │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                    🔧 Microservices Layer                        │    │
│   │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│   │  │ NestJS  │  │ GraphQL │  │   Go    │  │ FastAPI │  ┌───────┐  │    │
│   │  │  REST   │  │Strawberry│  │   WS   │  │ Chatbot │  │  MCP  │  │    │
│   │  │  API    │  │         │  │        │  │   +AI   │  │Server │  │    │
│   │  └────┬────┘  └─────────┘  └────┬───┘  └─────────┘  └───────┘  │    │
│   │       │                         │                               │    │
│   │       │    ┌───────────────────┐│                               │    │
│   │       └───▶│  🔐 Auth MS       │◀┘                              │    │
│   │            │    (NestJS)       │                                │    │
│   │            └─────────┬─────────┘                                │    │
│   └──────────────────────┼──────────────────────────────────────────┘    │
│                          │                                               │
│                          ▼                                               │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                    📨 Apache Kafka                               │    │
│   │              (Event Bus + Request/Reply)                         │    │
│   └─────────────────────────────────────────────────────────────────┘    │
│                          │                                               │
│                          ▼                                               │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                    🗄️ PostgreSQL                                 │    │
│   │              (Datos de negocio persistentes)                     │    │
│   └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

_Documentación generada el 6 de enero de 2026_
