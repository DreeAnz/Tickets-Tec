import { PrismaClient } from "@prisma/client";

const p = new PrismaClient({ log: ["error"] });
p.role.findMany({ take: 1 })
  .then((r) => {
    console.log("DB OK, filas role:", r.length);
    return p.$disconnect();
  })
  .catch((e) => {
    console.error("DB ERROR:", e.message);
    return p.$disconnect();
  });
