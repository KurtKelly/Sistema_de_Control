from flask import Flask, request, jsonify, session, redirect, url_for, render_template
from functools import wraps
from conexion import getConexion

app = Flask(__name__)
app.secret_key = "llave_ultra_secreta"


# ------------------------- Utilidades -------------------------
def json_error(message, status=400):
    return jsonify({"error": message}), status


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get("user_id"):
            return jsonify({"error": "No autenticado"}), 401
        return f(*args, **kwargs)

    return wrapper


def is_admin():
    return session.get("rol") == "admin"


def require_admin(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get("user_id"):
            return jsonify({"error": "No autenticado"}), 401
        if not is_admin():
            return jsonify({"error": "No autorizado"}), 403
        return f(*args, **kwargs)

    return wrapper


def ensure_admin_user():
    """Garantiza que exista usuario admin/admin"""
    try:
        conn = getConexion();
        cur = conn.cursor(buffered=True, dictionary=True)
        cur.execute("SELECT id FROM usuarios WHERE usuario=%s", ("admin",))
        row = cur.fetchone()
        if not row:
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO usuarios (usuario, contrasena, rol) VALUES (%s,%s,%s)",
                ("admin", "admin", "admin")
            )
            conn.commit()
    except Exception as e:
        try:
            conn.rollback()
        except:
            pass
        print("No se pudo crear admin:", e)
    finally:
        try:
            cur.close(); conn.close()
        except:
            pass


# ------------------------- Salud -------------------------
@app.get("/status")
def status():
    try:
        conn = getConexion();
        cur = conn.cursor()
        cur.execute("SELECT 1");
        cur.fetchone()
        cur.close();
        conn.close()
        return jsonify({"status": "ok", "db": "conectada"}), 200
    except Exception as e:
        return jsonify({"status": "error", "db_error": str(e)}), 500


@app.get("/")
def root_redirect():
    if session.get("user_id"): return redirect(url_for("ui"))
    return redirect(url_for("login_ui"))


# ------------------------- Auth -------------------------
@app.post("/login")
def login():
    datos = request.json or {}
    usuario = datos.get("usuario") or datos.get("username")
    contrasena = datos.get("contrasena") or datos.get("pass")
    if not usuario or not contrasena:
        return json_error("usuario y contrasena son obligatorios", 400)
    conn = getConexion();
    cur = conn.cursor(buffered=True, dictionary=True)
    cur.execute("SELECT id, usuario, contrasena, rol FROM usuarios WHERE usuario=%s", (usuario,))
    row = cur.fetchone();
    cur.close();
    conn.close()
    if not row or row["contrasena"] != contrasena:
        return json_error("Credenciales inválidas", 401)
    session["user_id"] = row["id"];
    session["usuario"] = row["usuario"];
    session["rol"] = row["rol"]
    return jsonify({"mensaje": "Login correcto", "usuario": row}), 200


@app.post("/logout")
@require_auth
def logout():
    session.clear();
    return jsonify({"mensaje": "Logout correcto"}), 200


@app.get("/me")
def me():
    if not session.get("user_id"): return jsonify({"autenticado": False}), 200
    return jsonify({"autenticado": True, "usuario": {"id": session["user_id"], "usuario": session["usuario"],
                                                     "rol": session.get("rol", "solo_vista")}}), 200


# ------------------------- Catálogos -------------------------
@app.get("/laboratorios")
@require_auth
def listar_laboratorios():
    conn = getConexion();
    cur = conn.cursor(buffered=True, dictionary=True)
    cur.execute("SELECT id, nombre, ubicacion FROM laboratorios ORDER BY nombre ASC")
    data = cur.fetchall();
    cur.close();
    conn.close();
    return jsonify(data), 200


# ------------------------- Equipos -------------------------




@app.get("/equipos")
@require_auth
def listar_equipos():
    try:
        laboratorio_id = request.args.get("laboratorio_id", type=int)
        estado         = request.args.get("estado", type=str)
        tipo           = request.args.get("tipo",   type=str)
        marca          = request.args.get("marca",  type=str)

        where, params = [], []
        if laboratorio_id is not None:
            where.append("e.laboratorio_id = %s"); params.append(laboratorio_id)
        if estado:
            where.append("e.estado = %s"); params.append(estado)
        if tipo:
            where.append("e.tipo = %s"); params.append(tipo)
        if marca:
            where.append("e.marca = %s"); params.append(marca)

        where_clause = ("WHERE " + " AND ".join(where)) if where else ""

        conn = getConexion()
        cur  = conn.cursor(buffered=True, dictionary=True)
        sql = f"""
            SELECT e.id, e.etiqueta_activo, e.tipo, e.marca, e.modelo, e.estado,
                   l.id AS laboratorio_id, l.nombre AS laboratorio
            FROM equipos e
            JOIN laboratorios l ON l.id = e.laboratorio_id
            {where_clause}
            ORDER BY e.id DESC
        """
        cur.execute(sql, tuple(params))
        data = cur.fetchall()
        return jsonify(data), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        try:
            cur.close()
        except Exception:
            pass




@app.post("/equipos")
@require_admin
def crear_equipo():
    d = request.json or {}
    required = ["etiqueta_activo", "laboratorio_id"]
    if any(k not in d for k in required): return json_error(f"Campos obligatorios: {', '.join(required)}")
    conn = getConexion();
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO equipos (etiqueta_activo,laboratorio_id,tipo,marca,modelo,estado) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            (d["etiqueta_activo"], d["laboratorio_id"], d.get("tipo"), d.get("marca"),
             d.get("modelo"), d.get("estado", "operativo"))
        )
        conn.commit();
        return jsonify({"mensaje": "Equipo creado", "id": cur.lastrowid}), 201
    except Exception as e:
        conn.rollback();
        return json_error(str(e))
    finally:
        cur.close();
        conn.close()


# app.py
@app.put("/equipos/<int:id>")
@require_admin
def editar_equipo(id):
    d = request.json or {}
    allowed = {"etiqueta_activo","laboratorio_id","tipo","marca","modelo","estado"}
    fields = {k: d[k] for k in d.keys() if k in allowed}
    if not fields:
        return json_error("Sin cambios: no se enviaron campos permitidos", 400)

    conn = getConexion()
    cur  = conn.cursor(buffered=True, dictionary=True)
    try:
        # Verificar existencia y etiqueta actual
        cur.execute("SELECT id, etiqueta_activo FROM equipos WHERE id=%s", (id,))
        eq = cur.fetchone()
        if not eq:
            return json_error("Equipo no encontrado", 404)

        # Si se cambia etiqueta, validar uniqueness
        if "etiqueta_activo" in fields and fields["etiqueta_activo"] != eq["etiqueta_activo"]:
            cur_check = conn.cursor()
            cur_check.execute("SELECT COUNT(*) FROM equipos WHERE etiqueta_activo=%s", (fields["etiqueta_activo"],))
            (exists,) = cur_check.fetchone(); cur_check.close()
            if exists:
                return json_error("La etiqueta ya existe", 409)

        # Armar UPDATE dinámico
        set_parts = []
        params = []
        for k, v in fields.items():
            set_parts.append(f"{k}=%s"); params.append(v)
        params.append(id)

        cur2 = conn.cursor()
        cur2.execute(f"UPDATE equipos SET {', '.join(set_parts)} WHERE id=%s", tuple(params))
        conn.commit()
        return jsonify({"mensaje": "Equipo actualizado", "id": id}), 200
    except Exception as e:
        conn.rollback()
        return json_error(str(e))
    finally:
        try: cur.close()
        except: pass
        conn.close()

# app.py
@app.delete("/equipos/<int:id>")
@require_admin
def eliminar_equipo(id):
    conn = getConexion()
    cur  = conn.cursor()
    try:
        # Verificar referencias
        refs = 0
        cur.execute("SELECT COUNT(*) FROM programaciones_mantenimiento WHERE equipo_id=%s", (id,))
        refs += cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM mantenimientos WHERE equipo_id=%s", (id,))
        refs += cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM incidencias WHERE equipo_id=%s", (id,))
        refs += cur.fetchone()[0]

        if refs > 0:
            return json_error(
                "No se puede eliminar: el equipo tiene referencias (programaciones/mantenimientos/incidencias). "
                "Sugerencia: cambiar estado a 'de_baja'.", 409
            )

        cur.execute("DELETE FROM equipos WHERE id=%s", (id,))
        if cur.rowcount == 0:
            conn.rollback(); return json_error("Equipo no encontrado", 404)

        conn.commit()
        return jsonify({"mensaje":"Equipo eliminado"}), 200
    except Exception as e:
        conn.rollback(); return json_error(str(e))
    finally:
        cur.close(); conn.close()


# ------------------------- Programaciones -------------------------


@app.get("/programaciones")
@require_auth
def listar_programaciones():
    equipo_id      = request.args.get("equipo_id", type=int)
    laboratorio_id = request.args.get("laboratorio_id", type=int)
    tipo           = request.args.get("tipo", type=str)
    marca          = request.args.get("marca", type=str)

    where, params = [], []
    if equipo_id is not None:
        where.append("p.equipo_id = %s"); params.append(equipo_id)
    if laboratorio_id is not None:
        where.append("e.laboratorio_id = %s"); params.append(laboratorio_id)
    if tipo:
        where.append("e.tipo = %s"); params.append(tipo)
    if marca:
        where.append("e.marca = %s"); params.append(marca)

    where_clause = ("WHERE " + " AND ".join(where)) if where else ""

    conn = getConexion(); cur = conn.cursor(buffered=True, dictionary=True)
    cur.execute(
        f"""
        SELECT p.id, p.equipo_id, e.etiqueta_activo, e.laboratorio_id, l.nombre AS laboratorio,
               p.periodicidad_dias, p.fecha_proxima, p.fecha_ultima
        FROM programaciones_mantenimiento p
        JOIN equipos e      ON e.id = p.equipo_id
        JOIN laboratorios l ON l.id = e.laboratorio_id
        {where_clause}
        ORDER BY p.fecha_proxima ASC
        """,
        tuple(params)
    )
    data = cur.fetchall()
    cur.close(); conn.close()
    return



@app.post("/programaciones")
@require_admin
def crear_programacion():
    d = request.json or {};
    required = ["equipo_id", "periodicidad_dias", "fecha_proxima"]
    if any(k not in d for k in required): return json_error(f"Campos obligatorios: {', '.join(required)}")
    conn = getConexion();
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO programaciones_mantenimiento (equipo_id,periodicidad_dias,fecha_proxima,fecha_ultima) "
            "VALUES (%s,%s,%s,%s)",
            (d["equipo_id"], d["periodicidad_dias"], d["fecha_proxima"], d.get("fecha_ultima"))
        )
        conn.commit();
        return jsonify({"mensaje": "Programación creada", "id": cur.lastrowid}), 201
    except Exception as e:
        conn.rollback();
        return json_error(str(e))
    finally:
        cur.close();
        conn.close()




@app.put("/programaciones/<int:id>")
@require_admin
def editar_programacion(id):
    d = request.json or {}
    # Campos permitidos
    fields = {}
    if "periodicidad_dias" in d: fields["periodicidad_dias"] = d["periodicidad_dias"]
    if "fecha_proxima" in d:     fields["fecha_proxima"]     = d["fecha_proxima"]
    if "fecha_ultima" in d:      fields["fecha_ultima"]      = d["fecha_ultima"]
    if not fields:
        return json_error("Sin cambios: no se enviaron campos a actualizar", 400)

    conn = getConexion()
    cur  = conn.cursor()
    try:
        # Verificar existencia
        cur.execute("SELECT id FROM programaciones_mantenimiento WHERE id=%s", (id,))
        row = cur.fetchone()
        if not row:
            return json_error("Programación no encontrada", 404)

        # Armar SET dinámico
        set_parts = []
        params = []
        for k, v in fields.items():
            set_parts.append(f"{k}=%s"); params.append(v)
        params.append(id)

        cur.execute(f"UPDATE programaciones_mantenimiento SET {', '.join(set_parts)} WHERE id=%s", tuple(params))
        conn.commit()
        return jsonify({"mensaje": "Programación actualizada", "id": id}), 200
    except Exception as e:
        conn.rollback()
        return json_error(str(e))
    finally:
        cur.close();  conn.close()

@app.delete("/programaciones/&lt;int:id&gt;")
@require_admin
def eliminar_programacion(id):
    conn = getConexion(); cur = conn.cursor()
    try:
        cur.execute("DELETE FROM programaciones_mantenimiento WHERE id=%s", (id,))
        if cur.rowcount == 0:
            conn.rollback(); return json_error("Programación no encontrada", 404)
        conn.commit(); return jsonify({"mensaje":"Programación eliminada"}), 200
    except Exception as e:
        conn.rollback(); return json_error(str(e))
    finally:
        cur.close(); conn.close()


# ------------------------- Programaciones próximas (vista) -------------------------


@app.get("/programaciones/proximas")
@require_auth
def programaciones_proximas():
    try:
        laboratorio_id = request.args.get("laboratorio_id", type=int)
        equipo_id = request.args.get("equipo_id", type=int)
        hasta_dias = request.args.get("hasta_dias", default=60, type=int)
        tipo = request.args.get("tipo", type=str)
        marca = request.args.get("marca", type=str)

        where, params = [], []
        if hasta_dias is not None:
            where.append("vp.dias_restantes <= %s");
            params.append(hasta_dias)  # <-- <=
        if laboratorio_id is not None:
            where.append("vp.laboratorio_id = %s");
            params.append(laboratorio_id)
        if equipo_id is not None:
            where.append("vp.equipo_id = %s");
            params.append(equipo_id)
        if tipo:
            where.append("e.tipo = %s");
            params.append(tipo)
        if marca:
            where.append("e.marca = %s");
            params.append(marca)

        where_clause = ("WHERE " + " AND ".join(where)) if where else ""

        conn = getConexion();
        cur = conn.cursor(buffered=True, dictionary=True)
        cur.execute(
            f"""
            SELECT 
                vp.id, 
                vp.equipo_id, 
                vp.etiqueta_activo, 
                vp.laboratorio_id, 
                vp.laboratorio,
                vp.periodicidad_dias, 
                DATE_FORMAT(vp.fecha_proxima, '%Y-%m-%d') AS fecha_proxima,
                CAST(vp.dias_restantes AS SIGNED) AS dias_restantes
            FROM vista_programaciones_proximas vp
            JOIN equipos e ON e.id = vp.equipo_id
            {where_clause}
            ORDER BY vp.fecha_proxima ASC
            LIMIT 200
            """,
            tuple(params)
        )
        data = cur.fetchall()
        return jsonify(data), 200  # <-- ¡IMPORTANTE!
    except Exception as e:
        # Devuelve el error para verlo en la UI
        return jsonify({"error": str(e)}), 500
    finally:
        try:
            cur.close();
            conn.close()
        except:
            pass

# ------------------------- Mantenimientos (demo) -------------------------
@app.get("/mantenimientos")
@require_auth
def listar_mantenimientos():
    conn = getConexion();
    cur = conn.cursor(buffered=True, dictionary=True)
    cur.execute(
        "SELECT id, equipo_id, tipo, fecha_apertura, fecha_cierre, estado, descripcion FROM mantenimientos ORDER BY fecha_apertura DESC")
    data = cur.fetchall();
    cur.close();
    conn.close();
    return jsonify(data), 200


@app.post("/mantenimientos")
@require_admin
def crear_mantenimiento():
    d = request.json or {};
    required = ["equipo_id", "tipo", "fecha_apertura"]
    if any(k not in d for k in required): return json_error(f"Campos obligatorios: {', '.join(required)}")
    conn = getConexion();
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO mantenimientos (equipo_id,tipo,fecha_apertura,fecha_cierre,estado,descripcion) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            (d["equipo_id"], d["tipo"], d["fecha_apertura"], d.get("fecha_cierre"), d.get("estado", "abierto"),
             d.get("descripcion"))
        )
        conn.commit();
        return jsonify({"mensaje": "Mantenimiento creado", "id": cur.lastrowid}), 201
    except Exception as e:
        conn.rollback();
        return json_error(str(e))
    finally:
        cur.close();
        conn.close()


# ------------------------- Incidencias (demo) -------------------------
@app.get("/incidencias")
@require_auth
def listar_incidencias():
    conn = getConexion();
    cur = conn.cursor(buffered=True, dictionary=True)
    cur.execute(
        "SELECT id, equipo_id, fecha_reporte, severidad, descripcion, mantenimiento_id FROM incidencias ORDER BY fecha_reporte DESC")
    data = cur.fetchall();
    cur.close();
    conn.close();
    return jsonify(data), 200


@app.post("/incidencias")
@require_admin
def crear_incidencia():
    d = request.json or {};
    required = ["equipo_id", "fecha_reporte", "severidad"]
    if any(k not in d for k in required): return json_error(f"Campos obligatorios: {', '.join(required)}")
    conn = getConexion();
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO incidencias (equipo_id,reportada_por,fecha_reporte,severidad,descripcion,mantenimiento_id) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            (d["equipo_id"], d.get("reportada_por"), d["fecha_reporte"], d["severidad"], d.get("descripcion"),
             d.get("mantenimiento_id"))
        )
        conn.commit();
        return jsonify({"mensaje": "Incidencia creada", "id": cur.lastrowid}), 201
    except Exception as e:
        conn.rollback();
        return json_error(str(e))
    finally:
        cur.close();
        conn.close()


# ------------------------- UI -------------------------
@app.get("/login-ui")
def login_ui():
    return render_template("index.html")


@app.get("/ui")
@require_auth
def ui():
    return render_template("ui.html")



if __name__ == "__main__":
    # Crea el usuario admin si no existe
    ensure_admin_user()

    # Ejecuta la app en un único proceso (sin reloader para evitar "exit code 0")
    app.run(
        host="0.0.0.0",
               port=5000,
        debug=True,
        use_reloader=False

    )

