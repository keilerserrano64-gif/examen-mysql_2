/*
Contenido:
  1. Vista        VW_EstadoEspacios
  2. Procedimiento sp_GenerarReporteDiario
  3. Consulta     "Ahora mismo hay X personas en el coworking"
  4. (Opcional) Datos de prueba con NOW()
*/

USE coworking_db;

-- 1. Vista: estado de cada espacio en tiempo real
--    Ocupado = tiene una reserva (pendiente o confirmada) en curso ahora.
--    Si el espacio está en Mantenimiento/Inactivo se muestra ese estado.

CREATE OR REPLACE VIEW VW_EstadoEspacios AS
SELECT
    e.nombre AS Espacio,
    CASE
        WHEN e.estado <> 'Disponible' THEN CAST(e.estado AS CHAR)
        WHEN EXISTS (SELECT 1
                       FROM reservas r
                      WHERE r.id_espacio = e.id_espacio
                        AND r.estado IN ('Pendiente de Confirmación', 'Confirmada')
                        AND r.fecha_inicio <= NOW()
                        AND r.fecha_fin    >= NOW())
            THEN 'Ocupado'
        ELSE 'Libre'
    END AS Estado,
    (SELECT MIN(r.fecha_inicio)
       FROM reservas r
      WHERE r.id_espacio = e.id_espacio
        AND r.estado IN ('Pendiente de Confirmación', 'Confirmada')
        AND r.fecha_inicio > NOW()) AS Proxima_Reserva
FROM espacios e;

-- Mostrar el resultado de la vista (Tarea 1)
SELECT * FROM VW_EstadoEspacios;

-- 2. Procedimiento: reporte diario (una sola fila)

DELIMITER //

DROP PROCEDURE IF EXISTS sp_GenerarReporteDiario//
CREATE PROCEDURE sp_GenerarReporteDiario()
BEGIN
    SELECT
        -- Reservas que empiezan hoy (sin contar canceladas)
        (SELECT COUNT(*)
           FROM reservas
          WHERE fecha_inicio >= CURDATE()
            AND fecha_inicio <  CURDATE() + INTERVAL 1 DAY
            AND estado <> 'Cancelada') AS Total_Reservas_Hoy,

        -- Usuarios distintos con ingreso exitoso hoy
        (SELECT COUNT(DISTINCT id_usuario)
           FROM registros_acceso
          WHERE estado_validacion = 'Exitoso'
            AND fecha_hora_entrada >= CURDATE()
            AND fecha_hora_entrada <  CURDATE() + INTERVAL 1 DAY) AS Usuarios_Activos_Hoy,

        -- Pagos con estado 'Pagado' registrados hoy
        (SELECT COALESCE(SUM(monto), 0)
           FROM pagos
          WHERE estado_transaccion = 'Pagado'
            AND fecha_pago >= CURDATE()
            AND fecha_pago <  CURDATE() + INTERVAL 1 DAY) AS Ingresos_Hoy;
END//

DELIMITER ;

-- Mostrar el resultado del procedimiento (Tarea 2)
CALL sp_GenerarReporteDiario();

-- 3. Consulta para la pantalla: personas dentro ahora mismo
--    (entradas exitosas de hoy que aún no tienen salida)

SELECT CONCAT('Ahora mismo ',
              IF(COUNT(DISTINCT id_usuario) = 1,
                 'hay 1 persona',
                 CONCAT('hay ', COUNT(DISTINCT id_usuario), ' personas')),
              ' en el coworking') AS Mensaje
  FROM registros_acceso
 WHERE estado_validacion = 'Exitoso'
   AND fecha_hora_salida IS NULL
   AND fecha_hora_entrada >= CURDATE();

-- 4. (OPCIONAL) Datos de prueba
--    Los datos iniciales están en fechas de septiembre 2026, por lo que hoy
--    todo saldría en 0 / "Libre". Descomenta para probar con NOW().
--    El usuario 1 debe tener membresía Activa; si no, el trigger
--    trg_ins_acceso_validar_membresia rechazará el acceso.
