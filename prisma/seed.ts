import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Iniciando sembrado de datos base...\n');

  // ============================================
  // 1. ROLES BASE DEL SISTEMA
  // ============================================
  const roles = [
    { nombre: 'Solicitante', descripcion: 'Usuario final que genera tickets de incidencia o petición' },
    { nombre: 'Técnico', descripcion: 'Personal de TI asignado a resolver tickets' },
    { nombre: 'Gestor de Tickets', descripcion: 'SPOC - asignación, seguimiento y control operativo' },
    { nombre: 'Administrador', descripcion: 'Acceso total al sistema y configuración' },
  ];

  for (const rol of roles) {
    await prisma.role.upsert({
      where: { nombre: rol.nombre },
      update: {},
      create: rol,
    });
  }
  console.log('✅ Roles creados:', roles.map((r) => r.nombre).join(', '));

  // ============================================
  // 2. PRIORIDADES SLA (Matriz de Tiempos)
  // ============================================
  const slaPriorities = [
    { nombre: 'Crítica', horasRespuesta: 1, horasResolucion: 4, color: '#DC2626', orden: 1 },
    { nombre: 'Alta', horasRespuesta: 2, horasResolucion: 8, color: '#EA580C', orden: 2 },
    { nombre: 'Media', horasRespuesta: 4, horasResolucion: 24, color: '#CA8A04', orden: 3 },
    { nombre: 'Baja', horasRespuesta: 8, horasResolucion: 72, color: '#16A34A', orden: 4 },
  ];

  for (const sla of slaPriorities) {
    await prisma.slaPriority.upsert({
      where: { nombre: sla.nombre },
      update: sla,
      create: sla,
    });
  }
  console.log('✅ Prioridades SLA creadas:', slaPriorities.map((s) => s.nombre).join(', '));

  // ============================================
  // 3. UBICACIONES (Campus TecNM)
  // ============================================
  const locations = [
    { nombre: 'TecNM Campus México', codigo: 'TNM-MEX', direccion: 'Av. Universidad 1650, CDMX' },
    { nombre: 'TecNM Campus Guadalajara', codigo: 'TNM-GDL', direccion: 'Av. Vallarta 1125, Jalisco' },
    { nombre: 'TecNM Campus Monterrey', codigo: 'TNM-MTY', direccion: 'Av. Constitución s/n, NL' },
    { nombre: 'TecNM Campus Puebla', codigo: 'TNM-PUE', direccion: 'Blvd. Forjadores, Puebla' },
    { nombre: 'TecNM Campus Tijuana', codigo: 'TNM-TIJ', direccion: 'Av. Tecnológico s/n, BC' },
    { nombre: 'Rectoría General', codigo: 'TNM-RG', direccion: 'Av. Universidad 1650, CDMX' },
  ];

  for (const loc of locations) {
    await prisma.location.upsert({
      where: { codigo: loc.codigo },
      update: {},
      create: loc,
    });
  }
  console.log('✅ Ubicaciones creadas:', locations.map((l) => l.codigo).join(', '));

  // ============================================
  // 4. CATEGORÍAS DE SERVICIO (Jerarquía)
  // ============================================
  const categoriasPadre = [
    { nombre: 'Hardware', descripcion: 'Equipos de cómputo y periféricos' },
    { nombre: 'Software', descripcion: 'Aplicaciones y licencias' },
    { nombre: 'Redes', descripcion: 'Conectividad e infraestructura de red' },
    { nombre: 'Infraestructura', descripcion: 'Servidores, energía, climatización' },
    { nombre: 'Soporte Usuario', descripcion: 'Cuentas, accesos y capacitación' },
  ];

  const padresCreados: Record<string, string> = {};
  for (const cat of categoriasPadre) {
    const creada = await prisma.serviceCategory.upsert({
      where: { nombre: cat.nombre },
      update: {},
      create: cat,
    });
    padresCreados[cat.nombre] = creada.id;
  }

  const subcategorias = [
    { nombre: 'Computadora de escritorio', padre: 'Hardware' },
    { nombre: 'Laptop', padre: 'Hardware' },
    { nombre: 'Impresora', padre: 'Hardware' },
    { nombre: 'Proyector', padre: 'Hardware' },
    { nombre: 'Licencias Office', padre: 'Software' },
    { nombre: 'Antivirus', padre: 'Software' },
    { nombre: 'Software académico', padre: 'Software' },
    { nombre: 'Conectividad WiFi', padre: 'Redes' },
    { nombre: 'Cableado estructurado', padre: 'Redes' },
    { nombre: 'Correo institucional', padre: 'Soporte Usuario' },
    { nombre: 'Plataforma Moodle', padre: 'Soporte Usuario' },
    { nombre: 'Sistema integral (SAEI)', padre: 'Soporte Usuario' },
  ];

  for (const sub of subcategorias) {
    await prisma.serviceCategory.upsert({
      where: { nombre: sub.nombre },
      update: { parentId: padresCreados[sub.padre] },
      create: { nombre: sub.nombre, parentId: padresCreados[sub.padre] },
    });
  }
  console.log(
    '✅ Categorías creadas:',
    categoriasPadre.length,
    'padres y',
    subcategorias.length,
    'subcategorías',
  );

  // ============================================
  // RESUMEN FINAL
  // ============================================
  console.log('\n🎉 Sembrado completado exitosamente.\n📊 Resumen:');
  console.log('   - Roles:', await prisma.role.count());
  console.log('   - Prioridades SLA:', await prisma.slaPriority.count());
  console.log('   - Ubicaciones:', await prisma.location.count());
  console.log('   - Categorías:', await prisma.serviceCategory.count());
}

main()
  .catch((e) => {
    console.error('❌ Error durante el sembrado:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
