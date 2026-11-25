# Instrucciones para Claude

Repositorio de la organización **Lodiser** en GitHub. Lo usan varias personas.

## Al empezar cada sesión

1. Ejecutar `git pull` antes de leer o cambiar cualquier archivo.
2. Avisar en una línea si bajaron cambios nuevos (y de quién), o si ya estaba al día.
3. Si `git pull` falla por cambios locales sin guardar o por conflictos, **no seguir**: explicar qué pasa y preguntar cómo resolverlo.

## Al subir cambios

- Commits chicos, con una descripción clara en español de qué cambió y por qué.
- Antes de `git push`, hacer `git pull` otra vez.
- **Nunca** usar `git push --force` ni `git reset --hard` sobre commits ya subidos. Para deshacer un cambio ya subido, usar `git revert`.
- Cambios grandes o que otra persona tiene que revisar: rama nueva + pull request, no directo a `main`.

## Secretos

- Las credenciales de la base están en el DSN de Windows `LodiserIA`, no en el repositorio.
- No escribir contraseñas, tokens ni claves en el código: van en esos archivos locales.
- Antes de cada commit, revisar que no se esté subiendo ningún dato sensible (datos de clientes, Excels, logs).
