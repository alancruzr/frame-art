# Frame Studio — revisión del onboarding actual (rama fix/rc-hardening, a99431b)

## Recorrido actual (6 pantallas, `OnboardingStore.step` 0–5)
1. **Bienvenida** – ícono + "Tu obra, en su pared, a tamaño real" + "Empezar".
2. **Objetivo** – 5 opciones (una pintura, varias obras, mostrar al cliente, feria, encargo); avanza solo.
3. **Dolor** – 5 opciones ("no imagina el tamaño", "no ve cómo queda", "no se decide", "tengo que ir", "WhatsApp aplasta la foto").
4. **Solución** – 3 filas (problema / cómo ayuda / qué mejora) según el dolor.
5. **Estudio** – nombre + slug (`framestudio.app/<slug>`).
6. **Permiso de cámara** – una tarjeta; "Entrar al taller" completa.

Al terminar: `RootView` → pestaña Taller (lista vacía, o `StudioNameView` si no hay nombre).

## Puntos de dolor identificados
1. **Sin momento "ajá"**: el usuario nunca ve su obra en una pared antes de entrar; todo es texto. Clarity hace una toma de prueba + replay antes del paywall.
2. **La personalización se pierde**: objetivo y dolor se guardan pero solo alimentan la pantalla 4; no reaparecen después (ni en paywall, ni en estado vacío).
3. **Sin compromiso ni recordatorio**: no hay hábito ("¿qué días compartes obra?") ni permiso de notificaciones; la app no tiene motivo para volver a abrirse.
4. **Permisos pedidos sin contexto de valor**: la cámara se pide al final, sin explicar AR + foto como checklist; no hay notificaciones.
5. **Sin prueba social** ni cierre emocional antes de entrar.
6. **Sin monetización**: no hay paywall ni puerta Pro; publicar es ilimitado y no hay entrada de "Mejorar" en ajustes.
7. **Duplicación**: `StudioNameView` en `RootView` repite el paso de estudio si se dejó vacío.
8. **Sin analítica**: no se mide abandono por pantalla (Clarity registra `onboarding_step` por índice).
9. **Sin reanudar**: si la app se cierra a mitad, vuelve a la pantalla 1 (Clarity persiste la pantalla).
10. **Atrás disponible en todo el flujo**, incluido después de pedir permisos (Clarity solo permite atrás en las primeras pantallas).

## Recorrido propuesto (espejo de Clarity, 10 pantallas)
| # | Clarity | Frame Studio |
|---|---------|--------------|
| 0 | welcome | Bienvenida con ícono animado |
| 1 | goal | ¿Qué vas a mostrar primero? |
| 2 | practical_help (dolor) | ¿Qué se pierde con una foto? |
| 3 | — (se conserva) | Nombre del estudio + slug |
| 4 | creator_commitment | ¿Qué días compartes obra? + hora + recordatorios (notificaciones) |
| 5 | permissions | Checklist: cámara + notificaciones |
| 6 | demo_recording | Prueba: elige una foto (o la de ejemplo) y ajusta el ancho real |
| 7 | demo_replay | Así la verá tu cliente: obra en pared + resultado personalizado por dolor |
| 8 | social_proof | Resultados (lo que acabas de hacer), sin reseñas inventadas |
| 9 | paywall | Paywall suave (X tras unos segundos) |

Sin ATT/IDFA: Clarity tampoco lo usa (FirebaseAnalyticsCore, sin AdSupport).
