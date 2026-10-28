# Descripción General de la Aplicación Móvil Armadillos

La aplicación móvil **Armadillos** es un proyecto desarrollado con **Flutter** cuyo propósito es preservar, difundir y promover la gastronomía regional de los municipios de **Ixmiquilpan** y **Cardonal**, en el estado de Hidalgo, mediante un recetario digital que permite a los usuarios consultar recetas tradicionales, conocer sus ingredientes y seguir los pasos necesarios para su preparación.

La aplicación cuenta con una interfaz intuitiva, moderna y adaptable a dispositivos móviles, diseñada para facilitar la navegación y ofrecer una experiencia de usuario sencilla. Para la gestión de la información utiliza servicios en la nube, principalmente **Firebase** para la autenticación de usuarios y el almacenamiento de datos mediante **Cloud Firestore**. Asimismo, utiliza **Cloudinary** para almacenar y administrar las imágenes asociadas a las recetas.

---

# Estructura y Módulos de la Aplicación

La aplicación está organizada en dos módulos principales:

## Módulo de Usuario

Permite a los usuarios:

- Iniciar sesión.
- Registrarse en la aplicación.
- Explorar las recetas disponibles.
- Consultar ingredientes y procedimientos de preparación.
- Guardar recetas en favoritos.
- Revisar notificaciones.
- Administrar la información de su perfil.

## Módulo de Administrador

Destinado a la gestión del contenido de la aplicación. Permite:

- Crear nuevas recetas.
- Publicar contenido gastronómico.
- Editar recetas existentes.
- Eliminar recetas.
- Administrar la información del recetario digital.

Ambos módulos forman parte de una misma aplicación; sin embargo, cuentan con funcionalidades y permisos diferenciados de acuerdo con el rol asignado a cada cuenta.

---

# Alcance de la Evaluación y Consideraciones de Seguridad

Por motivos de seguridad, protección de datos y prevención de modificaciones no autorizadas, la evaluación se realizará exclusivamente sobre el **módulo de usuario**.

En consecuencia, las pruebas y la revisión funcional se limitarán a las características disponibles para una cuenta de usuario convencional.

Durante la evaluación podrán verificarse funcionalidades como:

- Registro de usuarios.
- Inicio de sesión.
- Navegación entre pantallas.
- Consulta de recetas.
- Gestión de recetas favoritas.
- Recepción y consulta de notificaciones.
- Visualización y administración del perfil de usuario.

---

# Restricciones de la Evaluación

El módulo de administrador queda excluido de la evaluación práctica.

Esta medida tiene como finalidad:

- Proteger las funciones administrativas de la aplicación.
- Evitar modificaciones accidentales o no autorizadas en las recetas.
- Preservar la integridad de la información almacenada.
- Garantizar la disponibilidad y consistencia de los datos del proyecto.

La exclusión del módulo administrativo no implica que este no forme parte de la aplicación, sino que el acceso para fines de evaluación estará limitado únicamente al entorno y funcionalidades correspondientes al rol de usuario.

---

# Conclusión

Armadillos integra tecnologías de desarrollo móvil y servicios en la nube para ofrecer un recetario digital enfocado en la preservación y difusión de la gastronomía regional de Ixmiquilpan y Cardonal, Hidalgo.

La evaluación estará orientada a verificar el correcto funcionamiento de la aplicación desde la perspectiva del usuario final, sin comprometer las funciones administrativas ni la seguridad de la información almacenada en la plataforma.
