# Particol · partitura colaborativa

Editor de partituras en el navegador, con edición simultánea a través de Supabase.

## Qué hay en este repositorio

- `index.html`: la aplicación entera.
- `config.js`: los datos de conexión con Supabase (los rellenas tú).
- `supabase/particol.sql`: las tablas de la base de datos (prefijo `pc_`).

En la base de datos solo se guarda texto: las partituras en JSON, las versiones (máximo 20 por partitura) y los permisos. Las pistas de audio se generan en tu navegador y los sonidos se cargan de un servidor público, así que no ocupan nada en Supabase.

## Instalación paso a paso

### 1. Supabase (proyecto «cousas»)

1. Entra en supabase.com y abre el proyecto **cousas** (el antiguo «impro»).
2. Menú izquierdo → **SQL Editor** → **New query**. Pega todo el contenido de `supabase/particol.sql` y pulsa **Run**. Debe decir «Success». Se puede volver a ejecutar sin problema.
3. Menú izquierdo → **Authentication** → **Sign In / Providers**: comprueba que **Email** está activado.
4. Menú izquierdo → **Project Settings** → **API Keys** (o **Data API**). Copia la **Project URL** y la clave **anon** o **publishable**. La **service_role / secret** no la uses nunca aquí.

### 2. Rellenar `config.js`

Abre `config.js` y pega entre las comillas la URL y la clave del paso anterior. Si lo haces después de subirlo a GitHub, puedes editarlo desde la propia web de GitHub, con el icono del lápiz, y pulsar **Commit changes**.

### 3. GitHub

1. Entra en github.com → botón **New** (repositorio nuevo). Nombre: `particol`. Pulsa **Create repository**.
2. En la página del repositorio vacío, pulsa el enlace **uploading an existing file**.
3. Arrastra `index.html`, `config.js`, `README.md` y la carpeta `supabase`.
4. Pulsa **Commit changes**.

### 4. Vercel

1. Entra en vercel.com → **Add New…** → **Project**.
2. Busca el repositorio `particol` y pulsa **Import**.
3. En **Framework Preset** deja **Other**. No hace falta ningún comando de compilación. Pulsa **Deploy**.
4. Al terminar tendrás una dirección del estilo `https://particol.vercel.app`. Cada vez que cambies algo en GitHub, Vercel la actualiza solo.

### 5. Volver a Supabase: dirección de la web

1. **Authentication** → **URL Configuration**.
2. En **Site URL** pon la dirección de Vercel (por ejemplo `https://particol.vercel.app`).
3. En **Redirect URLs** añade la misma dirección terminada en `/**` (por ejemplo `https://particol.vercel.app/**`).
4. Guarda. Sin esto, el enlace del correo no te devolvería a Particol.

### 6. Probar

1. Abre la dirección de Vercel → botón de la **nube** (arriba) → escribe tu correo → **Enviar enlace**.
2. Abre el enlace del correo: vuelves a Particol con la sesión iniciada.
3. Botón de la nube → **Subir a la nube**. El punto verde del botón indica «guardado».
4. **Compartir…** → copia un enlace para editar y ábrelo en otro navegador u otra cuenta: veréis los cambios del otro al momento y un recuadro de color con el nombre en el compás donde está cada persona.

## Límites y avisos

- El correo de Supabase de serie solo envía unos pocos correos por hora. Para usarlo con un grupo grande de alumnado conviene configurar un servidor de correo propio (**Authentication → Emails → SMTP Settings**, por ejemplo con Brevo o Resend).
- Si dos personas cambian el mismo compás a la vez, se queda el último cambio. Los cambios de estructura (añadir compases, instrumentos, título) se guardan y el resto de personas recarga la partitura.
- Cada partitura puede ocupar hasta ~1 MB de texto (de sobra para obras corales y de cámara) y cada persona puede tener hasta 200 en la nube.
