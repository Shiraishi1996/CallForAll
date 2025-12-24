import { z } from "zod";

export const roomIdSchema = z
  .string()
  .min(3)
  .max(80)
  .regex(/^[a-zA-Z0-9_-]+$/);

export const displayNameSchema = z.string().min(1).max(30);
