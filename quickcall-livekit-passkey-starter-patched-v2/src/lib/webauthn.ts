export function userIdToBytes(userId: string): Uint8Array {
  return Buffer.from(userId, "utf8");
}